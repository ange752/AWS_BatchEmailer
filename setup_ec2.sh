#!/bin/bash
# Interactive EC2 Setup Script

set -e

echo "🚀 EC2 Email Sender Setup"
echo "========================="
echo ""

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI not found. Please install it first."
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ AWS credentials not configured. Run: aws configure"
    exit 1
fi

echo "✅ AWS CLI configured"
echo ""

# Get AWS account info
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION="us-west-2"
echo "Account ID: $ACCOUNT_ID"
echo "Region: $REGION"
echo ""

# Step 1: Get or create key pair
echo "🔑 Step 1: EC2 Key Pair"
echo "-----------------------"
read -p "Enter your EC2 key pair name (or press Enter to skip): " KEY_NAME

if [ -z "$KEY_NAME" ]; then
    echo "⚠️  No key pair specified. You'll need to configure SSH access manually."
    KEY_NAME_OPTION=""
else
    KEY_NAME_OPTION="--key-name $KEY_NAME"
    echo "✅ Using key pair: $KEY_NAME"
fi
echo ""

# Step 2: Get or create security group
echo "🔒 Step 2: Security Group and VPC"
echo "----------------------------------"
read -p "Enter VPC ID (or press Enter to use vpc-bf02f8da): " USER_VPC_ID
USER_VPC_ID=${USER_VPC_ID:-vpc-bf02f8da}

read -p "Enter security group ID (or press Enter to create new): " SECURITY_GROUP

if [ -z "$SECURITY_GROUP" ]; then
    echo "Creating new security group..."
    
    # Use specified VPC or find available VPC
    if [ -n "$USER_VPC_ID" ]; then
        VPC_ID="$USER_VPC_ID"
        echo "✅ Using specified VPC: $VPC_ID"
        
        # Verify VPC exists
        VPC_CHECK=$(aws ec2 describe-vpcs \
            --vpc-ids $VPC_ID \
            --region $REGION \
            --query 'Vpcs[0].VpcId' \
            --output text 2>/dev/null)
        
        if [ -z "$VPC_CHECK" ] || [ "$VPC_CHECK" = "None" ]; then
            echo "❌ VPC $VPC_ID not found. Please verify the VPC ID."
            exit 1
        fi
    else
        # Find available VPC
        echo "Finding available VPC..."
        VPC_ID=$(aws ec2 describe-vpcs \
            --region $REGION \
            --filters "Name=isDefault,Values=true" \
            --query 'Vpcs[0].VpcId' \
            --output text 2>/dev/null)
        
        # If no default VPC, get first available VPC
        if [ -z "$VPC_ID" ] || [ "$VPC_ID" = "None" ]; then
            echo "No default VPC found. Looking for available VPC..."
            VPC_ID=$(aws ec2 describe-vpcs \
                --region $REGION \
                --query 'Vpcs[0].VpcId' \
                --output text 2>/dev/null)
        fi
        
        # If still no VPC, create one
        if [ -z "$VPC_ID" ] || [ "$VPC_ID" = "None" ]; then
        echo "No VPC found. Creating new VPC..."
        VPC_ID=$(aws ec2 create-vpc \
            --cidr-block 10.0.0.0/16 \
            --region $REGION \
            --query 'Vpc.VpcId' \
            --output text)
        
        # Create internet gateway
        IGW_ID=$(aws ec2 create-internet-gateway \
            --region $REGION \
            --query 'InternetGateway.InternetGatewayId' \
            --output text)
        
        # Attach internet gateway to VPC
        aws ec2 attach-internet-gateway \
            --internet-gateway-id $IGW_ID \
            --vpc-id $VPC_ID \
            --region $REGION \
            > /dev/null
        
        # Create subnet
        SUBNET_ID=$(aws ec2 create-subnet \
            --vpc-id $VPC_ID \
            --cidr-block 10.0.1.0/24 \
            --availability-zone ${REGION}a \
            --region $REGION \
            --query 'Subnet.SubnetId' \
            --output text)
        
        # Create route table
        ROUTE_TABLE_ID=$(aws ec2 create-route-table \
            --vpc-id $VPC_ID \
            --region $REGION \
            --query 'RouteTable.RouteTableId' \
            --output text)
        
        # Add route to internet gateway
        aws ec2 create-route \
            --route-table-id $ROUTE_TABLE_ID \
            --destination-cidr-block 0.0.0.0/0 \
            --gateway-id $IGW_ID \
            --region $REGION \
            > /dev/null
        
        # Associate route table with subnet
        aws ec2 associate-route-table \
            --subnet-id $SUBNET_ID \
            --route-table-id $ROUTE_TABLE_ID \
            --region $REGION \
            > /dev/null
        
        # Enable auto-assign public IP
        aws ec2 modify-subnet-attribute \
            --subnet-id $SUBNET_ID \
            --map-public-ip-on-launch \
            --region $REGION \
            > /dev/null
        
            echo "✅ Created VPC: $VPC_ID"
            echo "   Created subnet: $SUBNET_ID"
            echo "   Configured internet access"
        else
            echo "✅ Using VPC: $VPC_ID"
        fi
    fi
    
    # Get subnet for the VPC (use first available public subnet)
    echo "Finding subnet in VPC..."
    SUBNET_ID=$(aws ec2 describe-subnets \
        --filters "Name=vpc-id,Values=$VPC_ID" "Name=map-public-ip-on-launch,Values=true" \
        --region $REGION \
        --query 'Subnets[0].SubnetId' \
        --output text 2>/dev/null)
    
    # If no public subnet, get first subnet
    if [ -z "$SUBNET_ID" ] || [ "$SUBNET_ID" = "None" ]; then
        SUBNET_ID=$(aws ec2 describe-subnets \
            --filters "Name=vpc-id,Values=$VPC_ID" \
            --region $REGION \
            --query 'Subnets[0].SubnetId' \
            --output text 2>/dev/null)
    fi
    
    if [ -n "$SUBNET_ID" ] && [ "$SUBNET_ID" != "None" ]; then
        echo "✅ Using subnet: $SUBNET_ID"
    else
        echo "⚠️  No subnet found in VPC. Instance may not have internet access."
    fi
    
    SECURITY_GROUP_NAME="email-sender-sg-$(date +%s)"
    SECURITY_GROUP=$(aws ec2 create-security-group \
        --group-name $SECURITY_GROUP_NAME \
        --description "Security group for email sender EC2 instance" \
        --vpc-id $VPC_ID \
        --region $REGION \
        --query 'GroupId' \
        --output text)
    
    # Add SSH rule
    MY_IP=$(curl -s https://checkip.amazonaws.com 2>/dev/null || echo "0.0.0.0/0")
    if [ "$MY_IP" != "0.0.0.0/0" ]; then
        CIDR="$MY_IP/32"
    else
        CIDR="0.0.0.0/0"
        echo "⚠️  Could not detect your IP. Allowing SSH from anywhere (0.0.0.0/0)"
    fi
    
    aws ec2 authorize-security-group-ingress \
        --group-id $SECURITY_GROUP \
        --protocol tcp \
        --port 22 \
        --cidr $CIDR \
        --region $REGION \
        > /dev/null
    
    echo "✅ Created security group: $SECURITY_GROUP"
    echo "   VPC: $VPC_ID"
    echo "   Allowed SSH from: $CIDR"
else
    echo "✅ Using security group: $SECURITY_GROUP"
fi
echo ""

# Step 3: Choose instance type
echo "💻 Step 3: Instance Type"
echo "------------------------"
echo "1) t3.small (2 vCPU, 2GB RAM) - Recommended for most campaigns"
echo "2) t3.medium (2 vCPU, 4GB RAM) - For larger campaigns"
echo "3) t3.large (2 vCPU, 8GB RAM) - For very large campaigns"
read -p "Choose instance type (1-3, default 1): " INSTANCE_CHOICE
INSTANCE_CHOICE=${INSTANCE_CHOICE:-1}

case $INSTANCE_CHOICE in
    1) INSTANCE_TYPE="t3.small" ;;
    2) INSTANCE_TYPE="t3.medium" ;;
    3) INSTANCE_TYPE="t3.large" ;;
    *) INSTANCE_TYPE="t3.small" ;;
esac

echo "✅ Selected: $INSTANCE_TYPE"
echo ""

# Step 4: Get AMI ID
echo "🖼️  Step 4: Amazon Machine Image"
echo "---------------------------------"
AMI_ID="ami-02b297871a94f4b42"  # User specified AMI (us-west-2)
echo "Using AMI: $AMI_ID"
echo ""

# Step 5: Launch instance
echo "🚀 Step 5: Launching EC2 Instance"
echo "-----------------------------------"
read -p "Launch instance now? (y/n) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Cancelled"
    exit 1
fi

echo "Launching instance..."
LAUNCH_CMD="aws ec2 run-instances \
    --image-id $AMI_ID \
    --instance-type $INSTANCE_TYPE \
    --security-group-ids $SECURITY_GROUP \
    --region $REGION \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=EmailSender}]'"

# If we created a new VPC, use the subnet
if [ -n "$SUBNET_ID" ]; then
    LAUNCH_CMD="$LAUNCH_CMD --subnet-id $SUBNET_ID"
fi

if [ -n "$KEY_NAME_OPTION" ]; then
    LAUNCH_CMD="$LAUNCH_CMD $KEY_NAME_OPTION"
fi

INSTANCE_ID=$(eval $LAUNCH_CMD | python3 -c "import sys, json; data = json.load(sys.stdin); print(data['Instances'][0]['InstanceId'])" 2>/dev/null || eval $LAUNCH_CMD | grep -o '"InstanceId"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"InstanceId"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')

if [ -z "$INSTANCE_ID" ]; then
    echo "❌ Failed to launch instance"
    exit 1
fi

echo "✅ Instance launched: $INSTANCE_ID"
echo "⏳ Waiting for instance to be running..."
aws ec2 wait instance-running --instance-ids $INSTANCE_ID --region $REGION

# Get public IP
PUBLIC_IP=$(aws ec2 describe-instances \
    --instance-ids $INSTANCE_ID \
    --region $REGION \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text)

echo "✅ Instance is running!"
echo "  Instance ID: $INSTANCE_ID"
echo "  Public IP: $PUBLIC_IP"
echo ""

# Step 6: Create setup script
echo "📝 Step 6: Creating Setup Instructions"
echo "--------------------------------------"
cat > ec2_setup_instructions.txt << EOF
EC2 Instance Setup Instructions
================================

Instance Details:
  Instance ID: $INSTANCE_ID
  Public IP: $PUBLIC_IP
  Instance Type: $INSTANCE_TYPE
  Region: $REGION

Next Steps:
1. Wait 1-2 minutes for instance to fully initialize
2. SSH into the instance:
   ssh -i $KEY_NAME.pem ec2-user@$PUBLIC_IP

3. Once connected, run these commands:

   # Update system
   sudo yum update -y

   # Install Python and dependencies
   sudo yum install -y python3 python3-pip
   pip3 install boto3 botocore

   # Install AWS CLI
   curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
   unzip awscliv2.zip
   sudo ./aws/install

   # Create emailer directory
   mkdir -p ~/emailer
   cd ~/emailer

   # Download script from S3
   aws s3 cp s3://amaze-aws-emailer/scripts/ses_emailer.py .

   # Make executable
   chmod +x ses_emailer.py

4. Upload your script to S3 first (from local machine):
   aws s3 cp ses_emailer.py s3://amaze-aws-emailer/scripts/ses_emailer.py

5. Create send script (see EC2_SETUP_GUIDE.md for details)

To stop instance:
  aws ec2 stop-instances --instance-ids $INSTANCE_ID --region $REGION

To start instance:
  aws ec2 start-instances --instance-ids $INSTANCE_ID --region $REGION

To terminate instance:
  aws ec2 terminate-instances --instance-ids $INSTANCE_ID --region $REGION
EOF

echo "✅ Instructions saved to: ec2_setup_instructions.txt"
echo ""

# Step 7: Upload script to S3
echo "📤 Step 7: Upload Script to S3"
echo "------------------------------"
read -p "Upload ses_emailer.py to S3 now? (y/n) " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    if [ -f "ses_emailer.py" ]; then
        aws s3 cp ses_emailer.py s3://amaze-aws-emailer/scripts/ses_emailer.py --region $REGION
        echo "✅ Script uploaded to S3"
    else
        echo "⚠️  ses_emailer.py not found. Upload it manually later."
    fi
fi
echo ""

# Summary
echo "✅ EC2 Setup Complete!"
echo "======================"
echo ""
echo "Instance Details:"
echo "  Instance ID: $INSTANCE_ID"
echo "  Public IP: $PUBLIC_IP"
echo "  Instance Type: $INSTANCE_TYPE"
echo "  Region: $REGION"
echo ""
echo "Next Steps:"
echo "1. Wait 1-2 minutes for instance to initialize"
echo "2. SSH into instance:"
echo "   ssh -i $KEY_NAME.pem ec2-user@$PUBLIC_IP"
echo ""
echo "3. Follow instructions in: ec2_setup_instructions.txt"
echo ""
echo "📄 Full guide: EC2_SETUP_GUIDE.md"

