#!/bin/bash
# Send emails via Lambda for a specific batch

CONFIG_FILE="lambda_config.json"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ lambda_config.json not found. Run setup_lambda.sh first."
    exit 1
fi

if [ -z "$1" ]; then
    echo "Usage: $0 <batch_file> [test]"
    echo "Example: $0 recipients_batch_01.csv"
    echo "Example: $0 recipients_batch_01.csv test  (adds TEST to subject)"
    exit 1
fi

BATCH_FILE="$1"
TEST_MODE="$2"

FUNCTION_NAME=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['function_name'])")
REGION=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['region'])")
S3_BUCKET=$(python3 -c "import json; c=json.load(open('$CONFIG_FILE')); print(c.get('s3_bucket') or c.get('s3_buckets', {}).get('templates', ''))")
SENDER=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['sender'])")
SENDER_NAME=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['sender_name'])")
SUBJECT=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['subject'])")

# Add TEST to subject if test mode
if [ "$TEST_MODE" = "test" ]; then
    SUBJECT="TEST: $SUBJECT"
fi

# Check if batch file exists locally
if [ ! -f "$BATCH_FILE" ]; then
    echo "⚠️  Local file not found: $BATCH_FILE"
    echo "Assuming it's already in S3..."
    S3_KEY="recipients/$(basename $BATCH_FILE)"
else
    # Upload to S3
    echo "📤 Uploading $BATCH_FILE to S3..."
    aws s3 cp "$BATCH_FILE" "s3://$S3_BUCKET/recipients/$(basename $BATCH_FILE)"
    S3_KEY="recipients/$(basename $BATCH_FILE)"
fi

echo "🚀 Sending emails via Lambda"
echo "  Function: $FUNCTION_NAME"
echo "  Batch: $BATCH_FILE"
echo "  Recipients: $(tail -n +2 "$BATCH_FILE" 2>/dev/null | wc -l | tr -d ' ') emails"
echo "  Subject: $SUBJECT"
echo ""

# Create payload
cat > /tmp/lambda-payload.json << EOF
{
  "sender": "$SENDER",
  "sender_name": "$SENDER_NAME",
  "s3_bucket": "$S3_BUCKET",
  "recipients_key": "$S3_KEY",
  "template_text_key": "templates/email_template.txt",
  "template_html_key": "templates/email_template.html",
  "subject": "$SUBJECT",
  "region": "$REGION",
  "batch_size": 50,
  "use_bcc": true
}
EOF

# Invoke Lambda
echo "Invoking Lambda function..."
RESPONSE_FILE="/tmp/lambda-response-$(date +%s).json"
aws lambda invoke \
    --function-name $FUNCTION_NAME \
    --payload file:///tmp/lambda-payload.json \
    --region $REGION \
    $RESPONSE_FILE

echo ""
echo "✅ Response:"
cat $RESPONSE_FILE | python3 -m json.tool

echo ""
echo "📊 View logs:"
echo "aws logs tail /aws/lambda/$FUNCTION_NAME --follow --region $REGION"

