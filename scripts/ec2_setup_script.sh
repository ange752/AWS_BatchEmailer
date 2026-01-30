#!/bin/bash
# EC2 Setup Script for Large Email Campaigns
# This script sets up an EC2 instance to send 4,000+ emails

set -e  # Exit on error

echo "🚀 EC2 Email Sender Setup Script"
echo "=================================="
echo ""

# Configuration
INSTANCE_TYPE="t3.small"
AMI_ID="ami-0c55b159cbfafe1f0"  # Amazon Linux 2023 (us-west-2) - Update for your region
KEY_NAME="your-key-name"  # Update with your EC2 key pair name
SECURITY_GROUP="your-security-group"  # Update with your security group ID
REGION="us-west-2"
S3_BUCKET="your-bucket-name"  # Update with your S3 bucket

echo "Configuration:"
echo "  Instance Type: $INSTANCE_TYPE"
echo "  Region: $REGION"
echo "  S3 Bucket: $S3_BUCKET"
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
fi

# Launch EC2 instance
echo "📦 Launching EC2 instance..."
INSTANCE_ID=$(aws ec2 run-instances \
    --image-id $AMI_ID \
    --instance-type $INSTANCE_TYPE \
    --key-name $KEY_NAME \
    --security-group-ids $SECURITY_GROUP \
    --region $REGION \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=EmailSender}]" \
    --user-data file://ec2_user_data.sh \
    --query 'Instances[0].InstanceId' \
    --output text)

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
echo "📝 Next steps:"
echo "1. Wait 2-3 minutes for instance to finish setup"
echo "2. SSH into instance:"
echo "   ssh -i your-key.pem ec2-user@$PUBLIC_IP"
echo "3. Run the email send script:"
echo "   cd ~/emailer && ./send_campaign.sh"
echo ""
echo "To stop instance when done:"
echo "  aws ec2 stop-instances --instance-ids $INSTANCE_ID --region $REGION"
echo ""
echo "To terminate instance:"
echo "  aws ec2 terminate-instances --instance-ids $INSTANCE_ID --region $REGION"

