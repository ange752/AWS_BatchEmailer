# How to Run Everything - Complete Guide

## Quick Start: Run Email Campaign

### Option 1: Lambda (Recommended for small/medium campaigns)

```bash
# Test first
./test_lambda.sh

# Send to batch 1
./send_lambda_batch.sh recipients_batch_01.csv

# Send to all batches
./send_lambda_batch.sh recipients_batch_01.csv
./send_lambda_batch.sh recipients_batch_02.csv
./send_lambda_batch.sh recipients_batch_03.csv
./send_lambda_batch.sh recipients_batch_04.csv
```

### Option 2: EC2 (Recommended for large campaigns 4000+)

**Step 1: Launch EC2 Instance**
```bash
./setup_ec2.sh
```

**Step 2: SSH into Instance**
```bash
ssh -i your-key.pem ec2-user@INSTANCE_IP
```

**Step 3: Setup on EC2**
```bash
# Install dependencies
sudo yum update -y
sudo yum install -y python3 python3-pip
pip3 install boto3 botocore

# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Configure AWS (or use IAM role)
aws configure

# Download scripts
mkdir -p ~/emailer
cd ~/emailer
aws s3 sync s3://amaze-aws-emailer/scripts/ . --region us-west-2
chmod +x *.sh *.py
```

**Step 4: Send Emails**
```bash
# Send to batch 1
./ec2_send_campaign.sh 01

# Send with custom template
./ec2_send_custom.sh recipients_batch_01.csv email_template

# Send to all batches
./ec2_send_all_batches.sh
```

---

## Complete Step-by-Step: First Time Setup

### Part 1: Local Setup (One Time)

**1. Verify AWS CLI is configured:**
```bash
aws sts get-caller-identity
```

**2. Upload files to S3 (if not already done):**
```bash
# Upload templates
aws s3 cp email_template.txt s3://amaze-aws-emailer/templates/ --region us-west-2
aws s3 cp email_template.html s3://amaze-aws-emailer/templates/ --region us-west-2

# Upload recipient lists
aws s3 cp recipients_batch_01.csv s3://amaze-aws-emailer/recipients/ --region us-west-2
```

---

### Part 2: Choose Your Method

#### Method A: Lambda (Easiest)

**Run:**
```bash
./test_lambda.sh          # Test first
./send_lambda_batch.sh recipients_batch_01.csv  # Send
```

**That's it!** Lambda handles everything.

#### Method B: EC2 (For Large Lists)

**Follow the EC2 setup steps above.**

---

## Running a Campaign: Detailed Steps

### Using Lambda

**1. Test with small list:**
```bash
./test_lambda.sh
```

**2. Send to production:**
```bash
# Send to batch 1
./send_lambda_batch.sh recipients_batch_01.csv

# Check response
cat /tmp/lambda-response-*.json | python3 -m json.tool

# View logs
aws logs tail /aws/lambda/email-sender --follow --region us-west-2
```

**3. Send to remaining batches:**
```bash
./send_lambda_batch.sh recipients_batch_02.csv
./send_lambda_batch.sh recipients_batch_03.csv
./send_lambda_batch.sh recipients_batch_04.csv
```

---

### Using EC2

**1. SSH into instance:**
```bash
ssh -i your-key.pem ec2-user@INSTANCE_IP
```

**2. Navigate to emailer directory:**
```bash
cd ~/emailer
```

**3. Test setup:**
```bash
# Quick test
aws sts get-caller-identity
aws s3 ls s3://amaze-aws-emailer/ --region us-west-2
python3 ses_emailer.py --help
```

**4. Send emails:**
```bash
# Option A: Send to batch
./ec2_send_campaign.sh 01

# Option B: Send with custom template
./ec2_send_custom.sh recipients_batch_01.csv email_template "Custom Subject"

# Option C: Send to all batches
./ec2_send_all_batches.sh
```

**5. Monitor progress:**
- Script shows progress in real-time
- Watch for success/failure messages
- Check email delivery

---

## Common Commands Reference

### Lambda Commands

```bash
# Test
./test_lambda.sh

# Send to batch
./send_lambda_batch.sh recipients_batch_01.csv

# View logs
aws logs tail /aws/lambda/email-sender --follow --region us-west-2
```

### EC2 Commands

```bash
# SSH into instance
ssh -i key.pem ec2-user@INSTANCE_IP

# Download updated scripts
cd ~/emailer
aws s3 sync s3://amaze-aws-emailer/scripts/ . --region us-west-2
chmod +x *.sh *.py

# Send campaign
./ec2_send_campaign.sh 01

# Send custom
./ec2_send_custom.sh recipients_batch_01.csv email_template
```

### Local Commands

```bash
# Upload files to S3
aws s3 cp file.csv s3://amaze-aws-emailer/recipients/ --region us-west-2

# List files in S3
aws s3 ls s3://amaze-aws-emailer/recipients/ --region us-west-2

# Test Lambda
./test_lambda.sh
```

---

## Example: Complete Campaign Run

### Scenario: Send to 4 batches (462 emails total)

**Using Lambda:**

```bash
# From your local machine
./send_lambda_batch.sh recipients_batch_01.csv
# Wait for completion (check response)

./send_lambda_batch.sh recipients_batch_02.csv
# Wait for completion

./send_lambda_batch.sh recipients_batch_03.csv
# Wait for completion

./send_lambda_batch.sh recipients_batch_04.csv
# Done!
```

**Using EC2:**

```bash
# SSH into EC2
ssh -i key.pem ec2-user@INSTANCE_IP

# Navigate to emailer
cd ~/emailer

# Send all batches automatically
./ec2_send_all_batches.sh

# OR send individually
./ec2_send_campaign.sh 01
./ec2_send_campaign.sh 02
./ec2_send_campaign.sh 03
./ec2_send_campaign.sh 04
```

---

## Troubleshooting

### "Script not found"
```bash
# Lambda: Scripts are in S3, Lambda downloads them
# EC2: Download from S3
cd ~/emailer
aws s3 sync s3://amaze-aws-emailer/scripts/ . --region us-west-2
chmod +x *.sh *.py
```

### "Access denied"
- Check AWS credentials: `aws sts get-caller-identity`
- Verify IAM role has permissions
- Check sender email is verified in SES

### "No recipients found"
- Verify recipient file is in S3
- Check file name matches exactly
- Verify file has correct format (CSV with email column)

### "Template not found"
- Verify template files are in S3
- Check template name matches
- Files should be: `{template_name}.txt` and `{template_name}.html`

---

## Quick Reference Card

```
┌─────────────────────────────────────────┐
│  LAMBDA (Small/Medium Campaigns)       │
├─────────────────────────────────────────┤
│  1. ./test_lambda.sh                    │
│  2. ./send_lambda_batch.sh batch.csv    │
│  3. Check logs                          │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│  EC2 (Large Campaigns 4000+)             │
├─────────────────────────────────────────┤
│  1. ./setup_ec2.sh                      │
│  2. SSH into instance                   │
│  3. Setup dependencies                   │
│  4. Download scripts                    │
│  5. ./ec2_send_campaign.sh 01           │
└─────────────────────────────────────────┘
```

---

## Next Steps After Running

1. **Check email delivery** - Verify emails were received
2. **Monitor SES metrics** - Check bounce/complaint rates
3. **Review logs** - Check for any errors
4. **Stop EC2 instance** (if using EC2) - Save costs
5. **Clean up** - Remove test files if needed

---

## Summary

**Easiest way to run:**
```bash
# Lambda
./send_lambda_batch.sh recipients_batch_01.csv

# EC2 (after setup)
./ec2_send_campaign.sh 01
```

**Full documentation:**
- Lambda: `HOW_TO_RUN_LAMBDA.md`
- EC2: `EC2_QUICK_SETUP.md`
- Testing: `HOW_TO_TEST_EC2.md`

