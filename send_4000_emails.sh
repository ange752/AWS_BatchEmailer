#!/bin/bash
# Simple script to send 4,000 emails from EC2
# Run this on your EC2 instance after setup

set -e

BUCKET="your-bucket-name"  # Update with your S3 bucket
REGION="us-west-2"
SENDER="studio_support@amaze.co"
SENDER_NAME="Amaze Software"
SUBJECT="Important update: Amaze Studio will shut down December 15th, 2025"

echo "📧 Starting email campaign..."
echo "=============================="
echo ""

# Download files from S3
echo "📥 Downloading files from S3..."
aws s3 cp s3://$BUCKET/recipients/recipients_4000.csv /tmp/recipients.csv
aws s3 cp s3://$BUCKET/templates/email_template.txt /tmp/email_template.txt
aws s3 cp s3://$BUCKET/templates/email_template.html /tmp/email_template.html

# Verify files downloaded
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
echo "This may take 10-15 minutes for 4,000 emails..."
echo ""

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

# Upload logs to S3
LOG_FILE="send_log_$(date +%Y%m%d_%H%M%S).txt"
echo ""
echo "📤 Uploading logs to S3..."
aws s3 cp send_log.txt s3://$BUCKET/logs/$LOG_FILE || echo "⚠️  No log file to upload"

echo ""
echo "✅ Email campaign complete!"
echo "📊 Check logs in S3: s3://$BUCKET/logs/$LOG_FILE"

