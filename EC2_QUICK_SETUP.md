# EC2 Quick Setup Guide

## Step-by-Step Setup

### Step 1: Launch EC2 Instance

**Option A: Use the automated script (Recommended)**
```bash
./setup_ec2.sh
```

This will:
- Launch EC2 instance (t3.small)
- Use VPC: vpc-bf02f8da
- Use AMI: ami-02b297871a94f4b42
- Create security group
- Provide SSH connection details

**Option B: Manual launch via AWS Console**
1. Go to EC2 → Launch Instance
2. Choose AMI: `ami-02b297871a94f4b42`
3. Instance type: `t3.small`
4. VPC: `vpc-bf02f8da`
5. Security group: Allow SSH (port 22)
6. Key pair: Select your key pair
7. Launch

---

### Step 2: SSH into Instance

```bash
# Get instance IP from setup script output or AWS Console
ssh -i your-key.pem ec2-user@INSTANCE_IP
```

---

### Step 3: Install Dependencies

Once connected via SSH, run:

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
```

---

### Step 4: Configure AWS Credentials

**Option A: Use IAM Role (Recommended - No credentials needed)**

If you attached an IAM role to the instance, you're done! No credentials needed.

**Option B: Use Access Keys**

```bash
aws configure
```

Enter:
- AWS Access Key ID: `[your access key]`
- AWS Secret Access Key: `[your secret key]`
- Default region: `us-west-2`
- Default output format: `json`

**Test credentials:**
```bash
aws sts get-caller-identity
```

---

### Step 5: Download Scripts from S3

```bash
# Create emailer directory
mkdir -p ~/emailer
cd ~/emailer

# Download all scripts from S3
aws s3 sync s3://amaze-aws-emailer/scripts/ . --region us-west-2

# Make scripts executable
chmod +x *.sh *.py

# Verify
ls -la
```

You should see:
- `ses_emailer.py`
- `ec2_send_campaign.sh`
- `ec2_send_custom.sh`
- `ec2_send_all_batches.sh`

---

### Step 6: Test Setup

**Test AWS CLI:**
```bash
# Test S3 access
aws s3 ls s3://amaze-aws-emailer/ --region us-west-2

# Test SES access
aws ses get-account-sending-enabled --region us-west-2
```

**Test script:**
```bash
# Verify script works
python3 ses_emailer.py --help
```

---

## Sending Your First Email

### Option 1: Send to a Batch

```bash
./ec2_send_campaign.sh 01
```

This will:
- Download `recipients_batch_01.csv` from S3
- Download `email_template.txt` and `email_template.html` from S3
- Send emails to all recipients in the batch

### Option 2: Send with Custom Template/Recipients

```bash
./ec2_send_custom.sh recipients_batch_01.csv email_template "Custom Subject"
```

### Option 3: Send to All Batches

```bash
./ec2_send_all_batches.sh
```

---

## Quick Reference

### Common Commands

```bash
# Download updated scripts
aws s3 sync s3://amaze-aws-emailer/scripts/ . --region us-west-2
chmod +x *.sh *.py

# Send to batch 1
./ec2_send_campaign.sh 01

# Send with custom template
./ec2_send_custom.sh recipients_batch_01.csv newsletter_template

# View available files in S3
aws s3 ls s3://amaze-aws-emailer/templates/ --region us-west-2
aws s3 ls s3://amaze-aws-emailer/recipients/ --region us-west-2
```

### Stop/Start Instance

```bash
# From your local machine
aws ec2 stop-instances --instance-ids i-xxxxxxxxx --region us-west-2
aws ec2 start-instances --instance-ids i-xxxxxxxxx --region us-west-2
```

---

## Troubleshooting

### Can't SSH into instance
- Check security group allows SSH (port 22) from your IP
- Verify key pair is correct
- Check instance is running

### AWS CLI not working
- Verify credentials: `aws sts get-caller-identity`
- Check IAM role is attached (if using roles)
- Verify region is correct

### Script not found
- Run: `aws s3 sync s3://amaze-aws-emailer/scripts/ . --region us-west-2`
- Check you're in `~/emailer` directory
- Verify files: `ls -la`

### Permission denied
- Run: `chmod +x *.sh *.py`
- Check file permissions: `ls -la`

---

## Complete Setup Checklist

- [ ] EC2 instance launched
- [ ] SSH access working
- [ ] Python 3 installed
- [ ] AWS CLI installed
- [ ] AWS credentials configured (or IAM role attached)
- [ ] Scripts downloaded from S3
- [ ] Scripts are executable
- [ ] Tested S3 access
- [ ] Tested SES access
- [ ] Ready to send emails!

---

## Next Steps

1. **Upload recipient lists to S3** (if not already done):
   ```bash
   # From local machine
   aws s3 cp recipients_batch_01.csv s3://amaze-aws-emailer/recipients/ --region us-west-2
   ```

2. **Upload email templates** (if not already done):
   ```bash
   # From local machine
   aws s3 cp email_template.txt s3://amaze-aws-emailer/templates/ --region us-west-2
   aws s3 cp email_template.html s3://amaze-aws-emailer/templates/ --region us-west-2
   ```

3. **Send your first campaign!**

---

## Full Documentation

- **Complete guide:** `EC2_SETUP_GUIDE.md`
- **Usage examples:** `EC2_USAGE_EXAMPLES.md`
- **Script explanation:** `SES_EMAILER_SCRIPT_EXPLAINED.md`

