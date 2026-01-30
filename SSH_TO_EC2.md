# How to SSH into EC2 Instance

Quick guide to connect to your EC2 instance and run scripts.

## Quick Connect

```bash
ssh -i ~/.ssh/oasis-dev-20200312.pem ec2-user@54.189.152.124
```

## Step-by-Step

### 1. Find Your SSH Key

The SSH keys are in `~/.ssh`. Find the most recent oasis-dev key:

```bash
ls -lt ~/.ssh/oasis-dev*.pem | head -1
```

Available keys:
- `oasis-dev-20200312.pem`
- `oasis-dev-01192021.pem`
- `oasis-dev-20190401.pem`

### 2. Set Correct Permissions (if needed)

```bash
chmod 400 ~/.ssh/oasis-dev-20200312.pem
```

### 3. SSH into Instance

```bash
ssh -i ~/.ssh/oasis-dev-20200312.pem ec2-user@54.189.152.124
```

If you get "Permission denied", try other keys:
```bash
ssh -i ~/.ssh/oasis-dev-01192021.pem ec2-user@54.189.152.124
```

### 4. Navigate to Script Directory

Once connected:

```bash
cd ~/emailer
ls -la
```

You should see scripts like:
- `ses_emailer.py`
- `ec2_send_campaign.sh`
- `ec2_send_custom.sh`
- `ec2_send_all_batches.sh`

## Running Scripts on EC2

### Send a Campaign

```bash
cd ~/emailer

# Send to batch 01
./ec2_send_campaign.sh 01

# Send with custom template
./ec2_send_custom.sh recipients_batch_01.csv email_template

# Send to all batches
./ec2_send_all_batches.sh
```

### Check Available Templates/Recipients

```bash
cd ~/emailer
./ec2_send_custom.sh
# (This will show usage and list available templates/recipients)
```

### List Files in S3

```bash
# List templates
aws s3 ls s3://amaze-aws-emailer/templates/ --region us-west-2

# List recipients
aws s3 ls s3://amaze-aws-emailer/recipients/ --region us-west-2
```

## Troubleshooting

### Connection Refused or Timeout

If you can't connect, the security group might not allow SSH from your IP:

1. **Check your current IP:**
   ```bash
   curl https://checkip.amazonaws.com
   ```

2. **Check instance status:**
   ```bash
   aws ec2 describe-instances --instance-ids i-0462951dc6f221468 --region us-west-2 --query 'Reservations[0].Instances[0].State.Name' --output text
   ```

3. **Add your IP to security group** (if needed)

### Permission Denied (publickey)

1. **Check key permissions:**
   ```bash
   chmod 400 ~/.ssh/oasis-dev-*.pem
   ```

2. **Try different key:**
   ```bash
   ssh -i ~/.ssh/oasis-dev-01192021.pem ec2-user@54.189.152.124
   ```

3. **Check if key is correct for this instance**

### Scripts Not Found

If scripts don't exist in `~/emailer`:

```bash
mkdir -p ~/emailer
cd ~/emailer
aws s3 sync s3://amaze-aws-emailer/scripts/ . --region us-west-2
chmod +x *.sh *.py
```

## Quick Reference

```bash
# Connect
ssh -i ~/.ssh/oasis-dev-20200312.pem ec2-user@54.189.152.124

# Once connected
cd ~/emailer
./ec2_send_campaign.sh 01

# Disconnect
exit
```

## Useful Commands Once Connected

```bash
# Check AWS CLI is configured
aws sts get-caller-identity

# Check disk space
df -h

# Check Python version
python3 --version

# Check running processes
ps aux | grep python

# View script help
./ec2_send_custom.sh

# Edit a script (if needed)
nano ec2_send_campaign.sh
```

## Disconnect from EC2

Type `exit` or press `Ctrl+D` to disconnect:

```bash
exit
```
