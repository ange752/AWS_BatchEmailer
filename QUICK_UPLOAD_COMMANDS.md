# Quick Upload Commands

## Upload test_recipients.csv to S3 (Recommended)

```bash
aws s3 cp test_recipients.csv s3://amaze-aws-emailer/recipients/test_recipients.csv --region us-west-2
```

## Upload test_recipients.csv directly to EC2

```bash
scp -i ~/.ssh/oasis-dev-20200312.pem test_recipients.csv ec2-user@54.189.152.124:~/emailer/
```

## Use the upload script

```bash
./upload_to_ec2.sh test_recipients.csv
```

This will:
1. Upload to S3 (recommended - EC2 scripts use S3)
2. Optionally upload directly to EC2 via SCP

## After Upload

On EC2, you can use the file:

```bash
# SSH into EC2
ssh -i ~/.ssh/oasis-dev-*.pem ec2-user@54.189.152.124

cd ~/emailer

# Use from S3 (recommended)
./ec2_send_custom.sh test_recipients.csv email_template

# Or download from S3 first
aws s3 cp s3://amaze-aws-emailer/recipients/test_recipients.csv /tmp/recipients.csv --region us-west-2
```
