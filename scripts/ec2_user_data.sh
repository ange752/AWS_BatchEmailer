#!/bin/bash
# User data script to run on EC2 instance startup
# This installs dependencies and sets up the email sender

# Update system
yum update -y

# Install Python and pip
yum install -y python3 python3-pip

# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
./aws/install

# Install Python dependencies
pip3 install boto3 botocore --quiet

# Create emailer directory
mkdir -p /home/ec2-user/emailer
cd /home/ec2-user/emailer

# Download script from S3 (you'll need to upload ses_emailer.py to S3 first)
# aws s3 cp s3://your-bucket/scripts/ses_emailer.py .

# Or create a simple download script
cat > download_and_send.sh << 'EOF'
#!/bin/bash
BUCKET="your-bucket-name"  # Update this
REGION="us-west-2"

echo "Downloading files from S3..."
aws s3 cp s3://$BUCKET/recipients/recipients_4000.csv /tmp/recipients.csv
aws s3 cp s3://$BUCKET/templates/email_template.txt /tmp/email_template.txt
aws s3 cp s3://$BUCKET/templates/email_template.html /tmp/email_template.html

echo "Sending emails..."
python3 ses_emailer.py \
  --sender studio_support@amaze.co \
  --sender-name "Amaze Software" \
  --recipients-file /tmp/recipients.csv \
  --subject "Important update: Amaze Studio will shut down December 15th, 2025" \
  --body-file /tmp/email_template.txt \
  --body-html-file /tmp/email_template.html \
  --region $REGION \
  --batch-size 50 \
  --use-bcc \
  --rate-limit 0.1

echo "Uploading logs..."
aws s3 cp send_log.txt s3://$BUCKET/logs/$(date +%Y%m%d_%H%M%S)_send.log || true
EOF

chmod +x download_and_send.sh
chown ec2-user:ec2-user -R /home/ec2-user/emailer

# Log completion
echo "Setup complete at $(date)" > /home/ec2-user/setup_complete.log

