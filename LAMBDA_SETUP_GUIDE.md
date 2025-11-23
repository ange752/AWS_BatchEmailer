# Lambda Setup Guide - Step by Step

This guide will walk you through setting up your email sender on AWS Lambda.

## Prerequisites

- AWS CLI installed and configured
- AWS account with SES access
- Sender email verified in SES
- Python 3.9+ installed locally

---

## Step 1: Create S3 Buckets

First, we'll create S3 buckets to store your email templates and recipient lists.

```bash
# Create buckets (update bucket names to be globally unique)
aws s3 mb s3://amaze-emailer-templates-$(date +%s)
aws s3 mb s3://amaze-emailer-recipients-$(date +%s)
aws s3 mb s3://amaze-emailer-logs-$(date +%s)
```

**Note:** S3 bucket names must be globally unique. The timestamp makes yours unique.

---

## Step 2: Upload Files to S3

Upload your email templates and recipient lists:

```bash
# Set your bucket names (from Step 1)
TEMPLATES_BUCKET="amaze-emailer-templates-XXXXX"
RECIPIENTS_BUCKET="amaze-emailer-recipients-XXXXX"

# Upload templates
aws s3 cp email_template.txt s3://$TEMPLATES_BUCKET/templates/email_template.txt
aws s3 cp email_template.html s3://$TEMPLATES_BUCKET/templates/email_template.html

# Upload recipient lists
aws s3 cp recipients_batch_01.csv s3://$RECIPIENTS_BUCKET/recipients/batch_01.csv
aws s3 cp recipients_batch_02.csv s3://$RECIPIENTS_BUCKET/recipients/batch_02.csv
aws s3 cp recipients_batch_03.csv s3://$RECIPIENTS_BUCKET/recipients/batch_03.csv
aws s3 cp recipients_batch_04.csv s3://$RECIPIENTS_BUCKET/recipients/batch_04.csv
```

---

## Step 3: Create IAM Role for Lambda

Lambda needs permissions to:
- Send emails via SES
- Read from S3
- Write logs to CloudWatch

```bash
# Create trust policy
cat > lambda-trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Create IAM role
aws iam create-role \
  --role-name EmailSenderLambdaRole \
  --assume-role-policy-document file://lambda-trust-policy.json

# Attach SES policy
aws iam attach-role-policy \
  --role-name EmailSenderLambdaRole \
  --policy-arn arn:aws:iam::aws:policy/AmazonSESFullAccess

# Attach S3 read policy
aws iam attach-role-policy \
  --role-name EmailSenderLambdaRole \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess

# Attach CloudWatch Logs policy
aws iam attach-role-policy \
  --role-name EmailSenderLambdaRole \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
```

**Note:** For production, create custom policies with least privilege instead of full access.

---

## Step 4: Package Lambda Function

Package your code for deployment:

```bash
# Run the deployment script
./deploy_to_lambda.sh
```

This creates `lambda-deployment.zip` with all dependencies.

---

## Step 5: Create Lambda Function

Create the Lambda function via AWS CLI:

```bash
# Get your account ID (needed for role ARN)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION="us-west-2"

# Create Lambda function
aws lambda create-function \
  --function-name email-sender \
  --runtime python3.11 \
  --role arn:aws:iam::${ACCOUNT_ID}:role/EmailSenderLambdaRole \
  --handler lambda_handler.lambda_handler \
  --zip-file fileb://lambda-deployment.zip \
  --timeout 900 \
  --memory-size 512 \
  --region $REGION \
  --description "Send mass emails via SES"
```

**Settings:**
- **Timeout:** 900 seconds (15 minutes - Lambda max)
- **Memory:** 512 MB (sufficient for email sending)
- **Runtime:** Python 3.11

---

## Step 6: Test Lambda Function

Test with a small batch first:

```bash
# Create test payload
cat > test-payload.json << EOF
{
  "sender": "studio_support@amaze.co",
  "sender_name": "Amaze Software",
  "s3_bucket": "amaze-emailer-templates-XXXXX",
  "recipients_key": "recipients/batch_01.csv",
  "template_text_key": "templates/email_template.txt",
  "template_html_key": "templates/email_template.html",
  "subject": "Test: Important update from Amaze",
  "region": "us-west-2",
  "batch_size": 50,
  "use_bcc": true
}
EOF

# Update bucket name in test-payload.json
# Then invoke Lambda
aws lambda invoke \
  --function-name email-sender \
  --payload file://test-payload.json \
  --region us-west-2 \
  response.json

# Check response
cat response.json | python3 -m json.tool
```

---

## Step 7: Monitor Lambda Execution

View logs in CloudWatch:

```bash
# View recent logs
aws logs tail /aws/lambda/email-sender --follow --region us-west-2
```

Or check in AWS Console:
- CloudWatch → Log Groups → `/aws/lambda/email-sender`

---

## Step 8: Schedule Lambda (Optional)

To run campaigns on a schedule:

```bash
# Create CloudWatch Events rule (daily at 9 AM UTC)
aws events put-rule \
  --name email-campaign-daily \
  --schedule-expression "cron(0 9 * * ? *)" \
  --region us-west-2

# Add Lambda as target
aws events put-targets \
  --rule email-campaign-daily \
  --targets "Id"="1","Arn"="arn:aws:lambda:us-west-2:${ACCOUNT_ID}:function:email-sender" \
  --region us-west-2

# Grant permission for Events to invoke Lambda
aws lambda add-permission \
  --function-name email-sender \
  --statement-id allow-cloudwatch-events \
  --action lambda:InvokeFunction \
  --principal events.amazonaws.com \
  --source-arn "arn:aws:events:us-west-2:${ACCOUNT_ID}:rule/email-campaign-daily" \
  --region us-west-2
```

---

## Step 9: Invoke for Production Campaign

Send to all batches:

```bash
# Batch 1
aws lambda invoke \
  --function-name email-sender \
  --payload '{
    "sender": "studio_support@amaze.co",
    "sender_name": "Amaze Software",
    "s3_bucket": "amaze-emailer-templates-XXXXX",
    "recipients_key": "recipients/batch_01.csv",
    "template_text_key": "templates/email_template.txt",
    "template_html_key": "templates/email_template.html",
    "subject": "Important update: Amaze Studio will shut down December 15th, 2025",
    "region": "us-west-2",
    "batch_size": 50,
    "use_bcc": true
  }' \
  --region us-west-2 \
  batch1-response.json

# Repeat for batches 2, 3, 4...
```

---

## Troubleshooting

### Error: "Unable to import module 'lambda_handler'"
- Check that `lambda_handler.py` is in the zip file
- Verify handler name: `lambda_handler.lambda_handler`

### Error: "Access Denied" for S3
- Check IAM role has S3 read permissions
- Verify bucket names are correct

### Error: "Access Denied" for SES
- Check IAM role has SES permissions
- Verify sender email is verified in SES

### Timeout Error
- Increase timeout (max 15 minutes)
- Reduce batch size
- Check CloudWatch logs for slow operations

### Out of Memory
- Increase memory allocation (up to 10GB)
- Memory affects CPU allocation too

---

## Cost Estimate

**For 462 emails:**
- Lambda invocations: Free (first 1M requests/month)
- Execution time: ~$0.0001 (within free tier)
- S3 storage: ~$0.01/month
- **Total: ~$0.01/month**

**For 4,000 emails:**
- Lambda invocations: Free
- Execution time: ~$0.001 (10-15 minutes)
- S3 storage: ~$0.01/month
- **Total: ~$0.01/month**

---

## Next Steps

1. ✅ Complete Step 1-5 (Setup)
2. ✅ Test with small batch (Step 6)
3. ✅ Monitor logs (Step 7)
4. ✅ Send production campaign (Step 9)
5. ⏭️ Set up EC2 for larger campaigns (see EC2_SETUP_GUIDE.md)

---

## Quick Reference

**Update Lambda code:**
```bash
./deploy_to_lambda.sh
aws lambda update-function-code \
  --function-name email-sender \
  --zip-file fileb://lambda-deployment.zip \
  --region us-west-2
```

**View Lambda details:**
```bash
aws lambda get-function --function-name email-sender --region us-west-2
```

**Delete Lambda:**
```bash
aws lambda delete-function --function-name email-sender --region us-west-2
```

