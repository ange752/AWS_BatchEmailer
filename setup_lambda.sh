#!/bin/bash
# Interactive Lambda Setup Script
# This script guides you through setting up Lambda for email sending

set -e

echo "🚀 Lambda Email Sender Setup"
echo "============================="
echo ""

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI not found. Please install it first:"
    echo "   https://aws.amazon.com/cli/"
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

# Step 1: Create S3 bucket
echo "📦 Step 1: Creating S3 Bucket"
echo "-------------------------------"
TIMESTAMP=$(date +%s)
MAIN_BUCKET="aws-emailer-${TIMESTAMP}"

echo "Creating main bucket..."
aws s3 mb s3://$MAIN_BUCKET --region $REGION 2>/dev/null || echo "Bucket may already exist"

echo "✅ Bucket created: $MAIN_BUCKET"
echo "   Structure:"
echo "     - templates/ (email templates)"
echo "     - recipients/ (recipient lists)"
echo "     - logs/ (execution logs)"
echo ""

# Step 2: Upload files
echo "📤 Step 2: Uploading Files to S3"
echo "---------------------------------"
read -p "Upload email templates? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if [ -f "email_template.txt" ] && [ -f "email_template.html" ]; then
        aws s3 cp email_template.txt s3://$MAIN_BUCKET/templates/email_template.txt
        aws s3 cp email_template.html s3://$MAIN_BUCKET/templates/email_template.html
        echo "✅ Templates uploaded"
    else
        echo "⚠️  Template files not found. Skipping..."
    fi
fi

read -p "Upload recipient lists? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    for file in recipients_batch_*.csv recipients.valids.csv recipients.csv; do
        if [ -f "$file" ]; then
            aws s3 cp "$file" s3://$MAIN_BUCKET/recipients/$(basename "$file")
            echo "✅ Uploaded: $file"
        fi
    done
    if [ ! -f "recipients_batch_01.csv" ] && [ ! -f "recipients.valids.csv" ]; then
        echo "⚠️  No recipient files found. You can upload them later."
    fi
fi
echo ""

# Step 3: Create IAM Role
echo "🔐 Step 3: Creating IAM Role"
echo "-----------------------------"
ROLE_NAME="EmailSenderLambdaRole"

# Check if role exists
if aws iam get-role --role-name $ROLE_NAME &> /dev/null; then
    echo "⚠️  Role $ROLE_NAME already exists. Skipping creation..."
else
    echo "Creating IAM role..."
    
    # Create trust policy
    cat > /tmp/lambda-trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
    
    aws iam create-role \
        --role-name $ROLE_NAME \
        --assume-role-policy-document file:///tmp/lambda-trust-policy.json \
        --description "IAM role for Lambda email sender"
    
    echo "✅ Role created"
    
    # Attach policies
    echo "Attaching policies..."
    aws iam attach-role-policy \
        --role-name $ROLE_NAME \
        --policy-arn arn:aws:iam::aws:policy/AmazonSESFullAccess
    
    aws iam attach-role-policy \
        --role-name $ROLE_NAME \
        --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess
    
    aws iam attach-role-policy \
        --role-name $ROLE_NAME \
        --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
    
    echo "✅ Policies attached"
fi

ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"
echo "Role ARN: $ROLE_ARN"
echo ""

# Step 4: Package Lambda
echo "📦 Step 4: Packaging Lambda Function"
echo "--------------------------------------"
if [ ! -f "lambda_handler.py" ]; then
    echo "❌ lambda_handler.py not found!"
    exit 1
fi

echo "Creating deployment package..."
./deploy_to_lambda.sh

if [ ! -f "lambda-deployment.zip" ]; then
    echo "❌ Failed to create deployment package"
    exit 1
fi

PACKAGE_SIZE=$(du -h lambda-deployment.zip | cut -f1)
echo "✅ Package created: lambda-deployment.zip ($PACKAGE_SIZE)"
echo ""

# Step 5: Create Lambda Function
echo "⚡ Step 5: Creating Lambda Function"
echo "-----------------------------------"
FUNCTION_NAME="email-sender"

# Check if function exists
if aws lambda get-function --function-name $FUNCTION_NAME --region $REGION &> /dev/null; then
    echo "⚠️  Function $FUNCTION_NAME already exists."
    read -p "Update existing function? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Updating function code..."
        aws lambda update-function-code \
            --function-name $FUNCTION_NAME \
            --zip-file fileb://lambda-deployment.zip \
            --region $REGION \
            > /dev/null
        echo "✅ Function updated"
    else
        echo "Skipping function creation..."
    fi
else
    echo "Creating Lambda function..."
    aws lambda create-function \
        --function-name $FUNCTION_NAME \
        --runtime python3.11 \
        --role $ROLE_ARN \
        --handler lambda_handler.lambda_handler \
        --zip-file fileb://lambda-deployment.zip \
        --timeout 900 \
        --memory-size 512 \
        --region $REGION \
        --description "Send mass emails via SES" \
        > /dev/null
    
    echo "✅ Function created: $FUNCTION_NAME"
fi
echo ""

# Step 6: Create test payload
echo "📝 Step 6: Creating Test Configuration"
echo "---------------------------------------"
cat > lambda_config.json << EOF
{
  "function_name": "$FUNCTION_NAME",
  "region": "$REGION",
  "s3_bucket": "$MAIN_BUCKET",
  "sender": "studio_support@amaze.co",
  "sender_name": "Amaze Software",
  "subject": "Important update: Amaze Studio will shut down December 15th, 2025"
}
EOF

echo "✅ Configuration saved to lambda_config.json"
echo ""

# Step 7: Create test script
echo "🧪 Step 7: Creating Test Script"
echo "---------------------------------"
cat > test_lambda.sh << 'TESTEOF'
#!/bin/bash
# Test Lambda function with a small batch

CONFIG_FILE="lambda_config.json"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ lambda_config.json not found. Run setup_lambda.sh first."
    exit 1
fi

FUNCTION_NAME=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['function_name'])")
REGION=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['region'])")
TEMPLATES_BUCKET=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['s3_buckets']['templates'])")
RECIPIENTS_BUCKET=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['s3_buckets']['recipients'])")
SENDER=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['sender'])")
SENDER_NAME=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['sender_name'])")
SUBJECT=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['subject'])")

# Use test_recipients.csv if available, otherwise batch_01
RECIPIENT_FILE="test_recipients.csv"
if [ ! -f "$RECIPIENT_FILE" ]; then
    RECIPIENT_FILE="recipients_batch_01.csv"
fi

echo "🧪 Testing Lambda Function"
echo "Function: $FUNCTION_NAME"
echo "Recipients: $RECIPIENT_FILE"
echo ""

# Create payload
cat > /tmp/test-payload.json << EOF
{
  "sender": "$SENDER",
  "sender_name": "$SENDER_NAME",
  "s3_bucket": "$TEMPLATES_BUCKET",
  "recipients_key": "recipients/$(basename $RECIPIENT_FILE)",
  "template_text_key": "templates/email_template.txt",
  "template_html_key": "templates/email_template.html",
  "subject": "$SUBJECT (TEST)",
  "region": "$REGION",
  "batch_size": 50,
  "use_bcc": true
}
EOF

echo "Invoking Lambda..."
aws lambda invoke \
    --function-name $FUNCTION_NAME \
    --payload file:///tmp/test-payload.json \
    --region $REGION \
    /tmp/lambda-response.json

echo ""
echo "Response:"
cat /tmp/lambda-response.json | python3 -m json.tool

echo ""
echo "📊 View logs:"
echo "aws logs tail /aws/lambda/$FUNCTION_NAME --follow --region $REGION"
TESTEOF

chmod +x test_lambda.sh
echo "✅ Test script created: test_lambda.sh"
echo ""

# Summary
echo "✅ Lambda Setup Complete!"
echo "=========================="
echo ""
echo "📋 Summary:"
echo "  Function: $FUNCTION_NAME"
echo "  Region: $REGION"
echo "  S3 Bucket: $MAIN_BUCKET"
echo "    - templates/ (email templates)"
echo "    - recipients/ (recipient lists)"
echo "    - logs/ (execution logs)"
echo ""
echo "📝 Next Steps:"
echo "1. Test the function:"
echo "   ./test_lambda.sh"
echo ""
echo "2. View logs:"
echo "   aws logs tail /aws/lambda/$FUNCTION_NAME --follow --region $REGION"
echo ""
echo "3. Send to a batch:"
echo "   See LAMBDA_SETUP_GUIDE.md for examples"
echo ""
echo "📄 Configuration saved to: lambda_config.json"

