# EC2 Setup Guide - Step by Step

This guide will walk you through setting up your email sender on AWS EC2.

## Prerequisites

- AWS CLI installed and configured
- AWS account with SES access
- Sender email verified in SES
- EC2 key pair created

---

## Quick Setup (Automated)

Run the automated setup script:

```bash
./setup_ec2.sh
```

This will guide you through:
1. Launching an EC2 instance
2. Installing dependencies
3. Uploading your script
4. Configuring the environment

---

## Manual Setup

### Step 1: Launch EC2 Instance

**Recommended Instance Type:** `t3.small` (sufficient for most campaigns)

```bash
# Launch instance
aws ec2 run-instances \
  --image-id ami-0c55b159cbfafe1f0 \
  --instance-type t3.small \
  --key-name your-key-name \
  --security-group-ids sg-xxxxxxxxx \
  --region us-west-2 \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=EmailSender}]"
```

**Or use AWS Console:**
1. Go to EC2 → Launch Instance
2. Choose Amazon Linux 2023 AMI
3. Instance type: t3.small
4. Configure security group (allow SSH on port 22)
5. Select your key pair
6. Launch

---

### Step 2: Connect to Instance

```bash
# Get public IP
INSTANCE_IP=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=EmailSender" "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text \
  --region us-west-2)

# SSH into instance
ssh -i your-key.pem ec2-user@$INSTANCE_IP
```

---

### Step 3: Install Dependencies

Once connected via SSH:

```bash
# Update system
sudo yum update -y

# Install Python and pip
sudo yum install -y python3 python3-pip

# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Install Python dependencies
pip3 install boto3 botocore

# Configure AWS credentials (or use IAM role)
aws configure
```

---

### Step 4: Upload Script

**Option A: From S3 (Recommended)**

```bash
# On your local machine, upload script to S3
aws s3 cp ses_emailer.py s3://amaze-aws-emailer/scripts/ses_emailer.py

# On EC2, download from S3
mkdir -p ~/emailer
cd ~/emailer
aws s3 cp s3://amaze-aws-emailer/scripts/ses_emailer.py .
chmod +x ses_emailer.py
```

**Option B: Via SCP**

```bash
# From your local machine
scp -i your-key.pem ses_emailer.py ec2-user@$INSTANCE_IP:~/emailer/
```

---

### Step 5: Create Send Script

Create `~/emailer/send_campaign.sh`:

```bash
#!/bin/bash
# Email campaign sender script

BUCKET="amaze-aws-emailer"
REGION="us-west-2"
SENDER="studio_support@amaze.co"
SENDER_NAME="Amaze Software"
SUBJECT="Important update: Amaze Studio will shut down December 15th, 2025"

# Download files from S3
echo "📥 Downloading files from S3..."
aws s3 cp s3://$BUCKET/recipients/recipients_batch_01.csv /tmp/recipients.csv
aws s3 cp s3://$BUCKET/templates/email_template.txt /tmp/email_template.txt
aws s3 cp s3://$BUCKET/templates/email_template.html /tmp/email_template.html

# Verify files
if [ ! -f /tmp/recipients.csv ]; then
    echo "❌ Error: Could not download recipients.csv"
    exit 1
fi

# Count recipients
RECIPIENT_COUNT=$(tail -n +2 /tmp/recipients.csv | wc -l)
echo "✅ Found $RECIPIENT_COUNT recipients"
echo ""

# Send emails
echo "🚀 Sending emails..."
python3 ses_emailer.py \
  --sender "$SENDER" \
  --sender-name "$SENDER_NAME" \
  --recipients-file /tmp/recipients.csv \
  --subject "$SUBJECT" \
  --body-file /tmp/email_template.txt \
  --body-html-file /tmp/email_template.html \
  --region $REGION \
  --batch-size 50 \
  --use-bcc \
  --rate-limit 0.1

echo ""
echo "✅ Campaign complete!"
```

Make it executable:
```bash
chmod +x ~/emailer/send_campaign.sh
```

---

### Step 6: Configure IAM Role (Recommended)

Instead of using access keys, attach an IAM role to the EC2 instance:

1. **Create IAM Role:**
```bash
# Create trust policy
cat > ec2-trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Create role
aws iam create-role \
  --role-name EmailSenderEC2Role \
  --assume-role-policy-document file://ec2-trust-policy.json

# Attach policies
aws iam attach-role-policy \
  --role-name EmailSenderEC2Role \
  --policy-arn arn:aws:iam::aws:policy/AmazonSESFullAccess

aws iam attach-role-policy \
  --role-name EmailSenderEC2Role \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess

# Create instance profile
aws iam create-instance-profile --instance-profile-name EmailSenderEC2Profile
aws iam add-role-to-instance-profile \
  --instance-profile-name EmailSenderEC2Profile \
  --role-name EmailSenderEC2Role
```

2. **Attach to Instance:**
```bash
# Get instance ID
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=EmailSender" "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].InstanceId' \
  --output text \
  --region us-west-2)

# Attach role
aws ec2 associate-iam-instance-profile \
  --instance-id $INSTANCE_ID \
  --iam-instance-profile Name=EmailSenderEC2Profile \
  --region us-west-2
```

---

## Running Campaigns

### Send to a Batch

```bash
cd ~/emailer
./send_campaign.sh
```

### Send to Multiple Batches

Create a script to send to all batches:

```bash
#!/bin/bash
# Send to all batches

BUCKET="amaze-aws-emailer"
REGION="us-west-2"

for batch in 01 02 03 04; do
    echo "📧 Sending batch $batch..."
    aws s3 cp s3://$BUCKET/recipients/recipients_batch_$batch.csv /tmp/recipients.csv
    python3 ses_emailer.py \
      --sender studio_support@amaze.co \
      --sender-name "Amaze Software" \
      --recipients-file /tmp/recipients.csv \
      --subject "Important update: Amaze Studio will shut down December 15th, 2025" \
      --body-file /tmp/email_template.txt \
      --body-html-file /tmp/email_template.html \
      --region $REGION \
      --batch-size 50 \
      --use-bcc
    echo "✅ Batch $batch complete"
    echo ""
done
```

---

## Monitoring

### View Progress

The script shows progress in real-time. You can also monitor via:

```bash
# View system resources
htop

# View recent commands/output
tail -f ~/emailer/send_log.txt
```

### Check Email Status

```bash
# View SES sending statistics
aws ses get-send-statistics --region us-west-2
```

---

## Cost Management

### Stop Instance When Not in Use

```bash
# Stop instance (saves money, keeps data)
aws ec2 stop-instances --instance-ids $INSTANCE_ID --region us-west-2

# Start instance when needed
aws ec2 start-instances --instance-ids $INSTANCE_ID --region us-west-2
```

### Terminate Instance (Deletes Everything)

```bash
aws ec2 terminate-instances --instance-ids $INSTANCE_ID --region us-west-2
```

---

## Best Practices

1. **Use IAM Roles:** Don't store access keys on EC2
2. **Stop When Idle:** Stop instance when not sending to save costs
3. **Monitor Resources:** Use CloudWatch to monitor instance health
4. **Backup Scripts:** Store scripts in S3 or Git
5. **Test First:** Always test with small batches before large campaigns

---

## Troubleshooting

### Can't Connect via SSH
- Check security group allows SSH (port 22)
- Verify key pair is correct
- Check instance is running

### Permission Denied
- Check IAM role is attached
- Verify policies are correct
- Check S3 bucket permissions

### Script Not Found
- Verify file path
- Check file permissions (`chmod +x`)
- Ensure you're in correct directory

### SES Errors
- Verify sender email is verified
- Check if in sandbox mode
- Verify IAM permissions

---

## Cost Estimate

**t3.small instance:**
- Running: ~$15/month
- Stopped: ~$0.10/month (EBS storage)
- One-time use (1 hour): ~$0.10

**For 4,000 emails:**
- Instance: ~$0.10 (1 hour)
- SES: ~$0.40 (4,000 emails)
- **Total: ~$0.50**

---

## Quick Reference

```bash
# Connect
ssh -i key.pem ec2-user@$INSTANCE_IP

# Send campaign
cd ~/emailer && ./send_campaign.sh

# Stop instance
aws ec2 stop-instances --instance-ids $INSTANCE_ID

# Start instance
aws ec2 start-instances --instance-ids $INSTANCE_ID
```

