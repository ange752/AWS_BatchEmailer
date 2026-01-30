# How to Run Lambda Function

## Quick Start

### Option 1: Use the Test Script (Easiest)
```bash
./test_lambda.sh
```
This will:
- Use `test_recipients.csv` (2 emails)
- Add "TEST" to the subject line
- Send via Lambda

### Option 2: Send to a Specific Batch
```bash
./send_lambda_batch.sh recipients_batch_01.csv
```

For test mode (adds "TEST" to subject):
```bash
./send_lambda_batch.sh recipients_batch_01.csv test
```

---

## Manual Methods

### Method 1: AWS CLI (Direct Invocation)

**Basic command:**
```bash
aws lambda invoke \
  --function-name email-sender \
  --payload file://payload.json \
  --region us-west-2 \
  response.json
```

**Create payload file:**
```bash
cat > payload.json << 'EOF'
{
  "sender": "studio_support@amaze.co",
  "sender_name": "Amaze Software",
  "s3_bucket": "amaze-aws-emailer",
  "recipients_key": "recipients/test_recipients.csv",
  "template_text_key": "templates/email_template.txt",
  "template_html_key": "templates/email_template.html",
  "subject": "Important update: Amaze Studio will shut down December 15th, 2025",
  "region": "us-west-2",
  "batch_size": 50,
  "use_bcc": true
}
EOF
```

**Then invoke:**
```bash
aws lambda invoke \
  --function-name email-sender \
  --payload file://payload.json \
  --region us-west-2 \
  --cli-binary-format raw-in-base64-out \
  response.json

# View response
cat response.json | python3 -m json.tool
```

---

### Method 2: Using Configuration File

The scripts automatically read from `lambda_config.json`, so you can create a simple payload:

```bash
# Get values from config
BUCKET=$(python3 -c "import json; print(json.load(open('lambda_config.json'))['s3_bucket'])")
SENDER=$(python3 -c "import json; print(json.load(open('lambda_config.json'))['sender'])")
SUBJECT=$(python3 -c "import json; print(json.load(open('lambda_config.json'))['subject'])")

# Create payload
cat > payload.json << EOF
{
  "sender": "$SENDER",
  "sender_name": "Amaze Software",
  "s3_bucket": "$BUCKET",
  "recipients_key": "recipients/recipients_batch_01.csv",
  "template_text_key": "templates/email_template.txt",
  "template_html_key": "templates/email_template.html",
  "subject": "$SUBJECT",
  "region": "us-west-2",
  "batch_size": 50,
  "use_bcc": true
}
EOF

# Invoke
aws lambda invoke \
  --function-name email-sender \
  --payload file://payload.json \
  --region us-west-2 \
  --cli-binary-format raw-in-base64-out \
  response.json
```

---

## Examples

### Example 1: Test with Small List
```bash
./test_lambda.sh
```

### Example 2: Send to Batch 1
```bash
./send_lambda_batch.sh recipients_batch_01.csv
```

### Example 3: Send to All Batches
```bash
./send_lambda_batch.sh recipients_batch_01.csv
./send_lambda_batch.sh recipients_batch_02.csv
./send_lambda_batch.sh recipients_batch_03.csv
./send_lambda_batch.sh recipients_batch_04.csv
```

### Example 4: Custom Payload
```bash
cat > custom-payload.json << 'EOF'
{
  "sender": "studio_support@amaze.co",
  "sender_name": "Amaze Software",
  "s3_bucket": "amaze-aws-emailer",
  "recipients_key": "recipients/recipients_batch_01.csv",
  "template_text_key": "templates/email_template.txt",
  "template_html_key": "templates/email_template.html",
  "subject": "Custom Subject Line",
  "region": "us-west-2",
  "batch_size": 50,
  "use_bcc": true
}
EOF

aws lambda invoke \
  --function-name email-sender \
  --payload file://custom-payload.json \
  --region us-west-2 \
  --cli-binary-format raw-in-base64-out \
  response.json
```

---

## Payload Parameters

| Parameter | Required | Description | Example |
|-----------|----------|-------------|---------|
| `sender` | Yes | Verified sender email | `studio_support@amaze.co` |
| `sender_name` | No | Display name for sender | `Amaze Software` |
| `s3_bucket` | Yes | S3 bucket name | `amaze-aws-emailer` |
| `recipients_key` | Yes | S3 key for recipients CSV | `recipients/batch_01.csv` |
| `template_text_key` | Yes | S3 key for text template | `templates/email_template.txt` |
| `template_html_key` | No | S3 key for HTML template | `templates/email_template.html` |
| `subject` | Yes | Email subject line | `Your subject here` |
| `region` | No | AWS region (default: us-west-2) | `us-west-2` |
| `batch_size` | No | Emails per batch (default: 50) | `50` |
| `use_bcc` | No | Use BCC for privacy (default: true) | `true` |

---

## Response Format

Successful response:
```json
{
  "statusCode": 200,
  "body": "{\"success\": true, \"total\": 150, \"successful\": 150, \"failed\": 0, \"batches\": 3}"
}
```

Error response:
```json
{
  "statusCode": 500,
  "body": "{\"error\": \"Error message here\", \"type\": \"ErrorType\"}"
}
```

---

## Monitoring

### View Logs in Real-Time
```bash
aws logs tail /aws/lambda/email-sender --follow --region us-west-2
```

### View Recent Logs
```bash
aws logs tail /aws/lambda/email-sender --since 10m --region us-west-2
```

### View in AWS Console
1. Go to CloudWatch → Log Groups
2. Select `/aws/lambda/email-sender`
3. View latest log stream

---

## Troubleshooting

### Error: "Function not found"
- Check function name: `aws lambda list-functions --region us-west-2`
- Verify you're in the correct region

### Error: "Access Denied"
- Check IAM role has SES and S3 permissions
- Verify sender email is verified in SES

### Error: "File not found in S3"
- Verify file exists: `aws s3 ls s3://amaze-aws-emailer/recipients/`
- Check the `recipients_key` path is correct

### Error: "Timeout"
- Lambda has 15-minute max timeout
- For large lists (4000+), consider EC2 instead

### Check Function Status
```bash
aws lambda get-function --function-name email-sender --region us-west-2
```

---

## Best Practices

1. **Always test first**: Use `./test_lambda.sh` before production sends
2. **Upload recipients first**: Make sure recipient files are in S3
3. **Monitor logs**: Watch CloudWatch logs during execution
4. **Start small**: Test with small batches before large campaigns
5. **Check SES limits**: Verify you're out of sandbox mode for production

---

## Quick Reference

```bash
# Test
./test_lambda.sh

# Send to batch
./send_lambda_batch.sh recipients_batch_01.csv

# View logs
aws logs tail /aws/lambda/email-sender --follow --region us-west-2

# Check function
aws lambda get-function --function-name email-sender --region us-west-2
```

