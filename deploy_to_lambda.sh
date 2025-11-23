#!/bin/bash
# Script to package and deploy to AWS Lambda

echo "📦 Packaging Lambda deployment..."

# Create deployment directory
mkdir -p lambda_package
cd lambda_package

# Copy Python files
cp ../ses_emailer.py .
cp ../lambda_handler.py .

# Install dependencies
pip3 install boto3 botocore -t .

# Create zip file
zip -r ../lambda-deployment.zip . -x "*.pyc" "__pycache__/*" "*.dist-info/*"

cd ..
echo "✅ Package created: lambda-deployment.zip"
echo ""
echo "Next steps:"
echo "1. Upload lambda-deployment.zip to AWS Lambda"
echo "2. Set handler to: lambda_handler.lambda_handler"
echo "3. Set timeout to 15 minutes (900 seconds)"
echo "4. Set memory to 512 MB or higher"
echo "5. Configure IAM role with SES and S3 permissions"

