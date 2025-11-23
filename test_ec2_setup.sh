#!/bin/bash
# EC2 Setup Test Script

echo "🧪 Testing EC2 Setup"
echo "==================="
echo ""

# Test 1: AWS CLI
echo "1. Testing AWS CLI..."
if aws --version &> /dev/null; then
    echo "   ✅ AWS CLI installed"
else
    echo "   ❌ AWS CLI not found"
    exit 1
fi

# Test 2: Credentials
echo "2. Testing AWS credentials..."
if aws sts get-caller-identity &> /dev/null; then
    echo "   ✅ Credentials configured"
else
    echo "   ❌ Credentials not configured"
    exit 1
fi

# Test 3: S3 Access
echo "3. Testing S3 access..."
if aws s3 ls s3://amaze-aws-emailer/ --region us-west-2 &> /dev/null; then
    echo "   ✅ S3 access working"
else
    echo "   ❌ S3 access failed"
    exit 1
fi

# Test 4: SES Access
echo "4. Testing SES access..."
if aws ses get-account-sending-enabled --region us-west-2 &> /dev/null; then
    echo "   ✅ SES access working"
else
    echo "   ❌ SES access failed"
    exit 1
fi

# Test 5: Python
echo "5. Testing Python..."
if python3 --version &> /dev/null; then
    echo "   ✅ Python installed"
else
    echo "   ❌ Python not found"
    exit 1
fi

# Test 6: Dependencies
echo "6. Testing Python dependencies..."
if python3 -c "import boto3; import botocore" &> /dev/null; then
    echo "   ✅ Dependencies installed"
else
    echo "   ❌ Dependencies missing"
    exit 1
fi

# Test 7: Scripts
echo "7. Testing scripts..."
cd ~/emailer 2>/dev/null || mkdir -p ~/emailer && cd ~/emailer
if [ -f "ses_emailer.py" ] && [ -f "ec2_send_campaign.sh" ]; then
    echo "   ✅ Scripts found"
else
    echo "   ⚠️  Scripts not found - downloading..."
    aws s3 sync s3://amaze-aws-emailer/scripts/ . --region us-west-2
    chmod +x *.sh *.py
    if [ -f "ses_emailer.py" ]; then
        echo "   ✅ Scripts downloaded"
    else
        echo "   ❌ Failed to download scripts"
        exit 1
    fi
fi

# Test 8: Script functionality
echo "8. Testing script functionality..."
if python3 ses_emailer.py --help &> /dev/null; then
    echo "   ✅ Script works"
else
    echo "   ❌ Script error"
    exit 1
fi

echo ""
echo "✅ All tests passed! EC2 setup is ready."
