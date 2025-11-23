#!/bin/bash
# EC2 Email Campaign Sender
# Run this script on your EC2 instance to send email campaigns
# Usage: ./ec2_send_campaign.sh [batch_num] [template_name] [recipient_list]

set -e

# Configuration
BUCKET="amaze-aws-emailer"
REGION="us-west-2"
SENDER="studio_support@amaze.co"
SENDER_NAME="Amaze Software"
SUBJECT="Important update: Amaze Studio will shut down December 15th, 2025"

# Get parameters from arguments
BATCH_NUM=${1:-01}
TEMPLATE_NAME=${2:-email_template}
RECIPIENT_LIST=${3:-recipients_batch_${BATCH_NUM}.csv}

echo "📧 Email Campaign Sender"
echo "======================="
echo ""
echo "Configuration:"
echo "  Bucket: $BUCKET"
echo "  Region: $REGION"
echo "  Sender: $SENDER_NAME <$SENDER>"
echo "  Template: $TEMPLATE_NAME"
echo "  Recipient List: $RECIPIENT_LIST"
echo ""

# Download files from S3
echo "📥 Downloading files from S3..."
aws s3 cp s3://$BUCKET/recipients/$RECIPIENT_LIST /tmp/recipients.csv --region $REGION
aws s3 cp s3://$BUCKET/templates/${TEMPLATE_NAME}.txt /tmp/email_template.txt --region $REGION
aws s3 cp s3://$BUCKET/templates/${TEMPLATE_NAME}.html /tmp/email_template.html --region $REGION

# Verify files
if [ ! -f /tmp/recipients.csv ]; then
    echo "❌ Error: Could not download recipients.csv"
    exit 1
fi

# Count recipients
RECIPIENT_COUNT=$(tail -n +2 /tmp/recipients.csv 2>/dev/null | wc -l | tr -d ' ')
echo "✅ Found $RECIPIENT_COUNT recipients"
echo ""

# Send emails
echo "🚀 Sending emails..."
echo "This may take 10-15 minutes for large batches..."
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

echo ""
echo "✅ Campaign complete!"
echo "📊 Check logs above for details"

