#!/bin/bash
# Test Lambda function with a small batch

CONFIG_FILE="lambda_config.json"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ lambda_config.json not found. Run setup_lambda.sh first."
    exit 1
fi

FUNCTION_NAME=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['function_name'])")
REGION=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['region'])")
S3_BUCKET=$(python3 -c "import json; c=json.load(open('$CONFIG_FILE')); print(c.get('s3_bucket') or c.get('s3_buckets', {}).get('templates', ''))")
SENDER=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['sender'])")
SENDER_NAME=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['sender_name'])")
SUBJECT=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['subject'])")

# Use test_recipients.csv if available, otherwise batch_01
RECIPIENT_FILE="test_recipients.csv"
if [ ! -f "$RECIPIENT_FILE" ]; then
    RECIPIENT_FILE="recipients_batch_01.csv"
fi

echo "🧪 Testing Lambda Function"
echo "Function: $FUNCTION_NAME"
echo "Recipients: $RECIPIENT_FILE"
echo ""

# Create payload
PAYLOAD_FILE="/tmp/test-payload-$$.json"
cat > $PAYLOAD_FILE << EOF
{
  "sender": "$SENDER",
  "sender_name": "$SENDER_NAME",
  "s3_bucket": "$S3_BUCKET",
  "recipients_key": "recipients/$(basename $RECIPIENT_FILE)",
  "template_text_key": "templates/email_template.txt",
  "template_html_key": "templates/email_template.html",
  "subject": "$SUBJECT (TEST)",
  "region": "$REGION",
  "batch_size": 50,
  "use_bcc": true
}
EOF

echo "Invoking Lambda..."
RESPONSE_FILE="/tmp/lambda-response-$$.json"
aws lambda invoke \
    --function-name $FUNCTION_NAME \
    --payload file://$PAYLOAD_FILE \
    --region $REGION \
    --cli-binary-format raw-in-base64-out \
    $RESPONSE_FILE

echo ""
echo "Response:"
if [ -f "$RESPONSE_FILE" ]; then
    cat $RESPONSE_FILE | python3 -m json.tool
else
    echo "❌ No response file generated"
fi

echo ""
echo "📊 View logs:"
echo "aws logs tail /aws/lambda/$FUNCTION_NAME --follow --region $REGION"
