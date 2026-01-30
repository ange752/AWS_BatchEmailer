# How to Test EC2 Setup

## Step-by-Step Testing Guide

### Step 1: Test AWS CLI Installation

```bash
# Check AWS CLI version
aws --version

# Should show: aws-cli/2.x.x
```

### Step 2: Test AWS Credentials

```bash
# Test credentials
aws sts get-caller-identity

# Should return:
# {
#     "UserId": "...",
#     "Account": "730857767296",
#     "Arn": "arn:aws:iam::..."
# }
```

**If error:** Run `aws configure` or attach IAM role to instance.

---

### Step 3: Test S3 Access

```bash
# List S3 bucket contents
aws s3 ls s3://amaze-aws-emailer/ --region us-west-2

# Should show:
# PRE logs/
# PRE recipients/
# PRE scripts/
# PRE templates/

# List templates
aws s3 ls s3://amaze-aws-emailer/templates/ --region us-west-2

# Should show:
# email_template.html
# email_template.txt

# List recipients
aws s3 ls s3://amaze-aws-emailer/recipients/ --region us-west-2

# Should show recipient CSV files

# List scripts
aws s3 ls s3://amaze-aws-emailer/scripts/ --region us-west-2

# Should show:
# ec2_send_all_batches.sh
# ec2_send_campaign.sh
# ec2_send_custom.sh
# ses_emailer.py
```

**If error:** Check IAM permissions or credentials.

---

### Step 4: Test SES Access

```bash
# Check SES account status
aws ses get-account-sending-enabled --region us-west-2

# Check sending quota
aws ses get-send-quota --region us-west-2

# Verify sender email (if needed)
aws ses get-identity-verification-attributes \
  --identities studio_support@amaze.co \
  --region us-west-2
```

**If error:** Check SES permissions in IAM role/policy.

---

### Step 5: Test Script Downloads

```bash
# Navigate to emailer directory
cd ~/emailer

# Download scripts
aws s3 sync s3://amaze-aws-emailer/scripts/ . --region us-west-2

# Verify files downloaded
ls -la

# Should show:
# ses_emailer.py
# ec2_send_campaign.sh
# ec2_send_custom.sh
# ec2_send_all_batches.sh

# Make executable
chmod +x *.sh *.py
```

---

### Step 6: Test Python and Dependencies

```bash
# Check Python version
python3 --version

# Should show: Python 3.x.x

# Test imports
python3 -c "import boto3; print('boto3 OK')"
python3 -c "import botocore; print('botocore OK')"

# Test ses_emailer.py
python3 ses_emailer.py --help

# Should show usage information
```

---

### Step 7: Test Script Help

```bash
# Test main script
python3 ses_emailer.py --help

# Test send campaign script
./ec2_send_campaign.sh

# Should show usage or error (if no arguments)

# Test custom send script
./ec2_send_custom.sh

# Should show usage and list available templates/recipients
```

---

### Step 8: Test with Preview (No Email Sent)

```bash
# Download a test template
aws s3 cp s3://amaze-aws-emailer/templates/email_template.txt /tmp/test_template.txt --region us-west-2
aws s3 cp s3://amaze-aws-emailer/templates/email_template.html /tmp/test_template.html --region us-west-2

# Preview email (doesn't send)
python3 ses_emailer.py \
  --sender studio_support@amaze.co \
  --recipients test@example.com \
  --subject "Test Preview" \
  --body-file /tmp/test_template.txt \
  --body-html-file /tmp/test_template.html \
  --preview

# Should open browser with email preview
```

---

### Step 9: Test with Small Recipient List

**Create a test recipient file:**
```bash
# Create test file
cat > /tmp/test_recipients.csv << 'EOF'
email
test@example.com
EOF

# Upload to S3
aws s3 cp /tmp/test_recipients.csv s3://amaze-aws-emailer/recipients/test_recipients.csv --region us-west-2
```

**Test sending (use your verified test email):**
```bash
# Test with custom script
./ec2_send_custom.sh test_recipients.csv email_template "Test Email"

# OR test directly with ses_emailer.py
python3 ses_emailer.py \
  --sender studio_support@amaze.co \
  --sender-name "Amaze Software" \
  --recipients-file /tmp/test_recipients.csv \
  --subject "EC2 Test Email" \
  --body-file /tmp/test_template.txt \
  --body-html-file /tmp/test_template.html \
  --region us-west-2 \
  --use-bcc
```

**Check email was received!**

---

### Step 10: Test Full Campaign Script

```bash
# Test with batch 01 (if it exists)
./ec2_send_campaign.sh 01

# OR test with custom parameters
./ec2_send_campaign.sh 01 email_template recipients_batch_01.csv
```

---

## Quick Test Checklist

Run these commands in order:

```bash
# 1. AWS CLI
aws --version && echo "✅ AWS CLI OK"

# 2. Credentials
aws sts get-caller-identity && echo "✅ Credentials OK"

# 3. S3 Access
aws s3 ls s3://amaze-aws-emailer/ --region us-west-2 && echo "✅ S3 Access OK"

# 4. SES Access
aws ses get-account-sending-enabled --region us-west-2 && echo "✅ SES Access OK"

# 5. Python
python3 --version && echo "✅ Python OK"

# 6. Dependencies
python3 -c "import boto3; import botocore; print('✅ Dependencies OK')"

# 7. Scripts
cd ~/emailer && ls -la *.py *.sh && echo "✅ Scripts OK"

# 8. Script help
python3 ses_emailer.py --help | head -5 && echo "✅ Script OK"
```

---

## Troubleshooting Tests

### Test 1 Failed: AWS CLI not installed
```bash
# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

### Test 2 Failed: No credentials
```bash
# Configure credentials
aws configure

# OR attach IAM role to instance
```

### Test 3 Failed: S3 access denied
- Check IAM role has `AmazonS3ReadOnlyAccess` policy
- Verify bucket name is correct
- Check region is `us-west-2`

### Test 4 Failed: SES access denied
- Check IAM role has `AmazonSESFullAccess` policy
- Verify sender email is verified in SES

### Test 5 Failed: Python not found
```bash
# Install Python
sudo yum install -y python3 python3-pip
```

### Test 6 Failed: Missing dependencies
```bash
# Install dependencies
pip3 install boto3 botocore
```

### Test 7 Failed: Scripts not found
```bash
# Download scripts
cd ~/emailer
aws s3 sync s3://amaze-aws-emailer/scripts/ . --region us-west-2
chmod +x *.sh *.py
```

---

## Full Test Script

Save this as `test_ec2_setup.sh`:

```bash
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
echo ""
echo "Next steps:"
echo "  - Test with preview: python3 ses_emailer.py --preview ..."
echo "  - Send test email: ./ec2_send_custom.sh test_recipients.csv"
```

---

## Summary

**Quick test:**
```bash
# Run all basic tests
aws --version && \
aws sts get-caller-identity && \
aws s3 ls s3://amaze-aws-emailer/ --region us-west-2 && \
python3 --version && \
python3 -c "import boto3" && \
cd ~/emailer && ls -la ses_emailer.py
```

**Full test:**
- Use the test script above
- Or follow steps 1-10 manually

**Test with real email:**
- Use `test_recipients.csv` with your verified email
- Send a test email
- Verify it was received

