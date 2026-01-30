# Lambda Quick Start Guide

## 🚀 One-Command Setup

Run the automated setup script:

```bash
./setup_lambda.sh
```

This will:
1. ✅ Create S3 buckets for templates, recipients, and logs
2. ✅ Upload your email templates and recipient lists
3. ✅ Create IAM role with necessary permissions
4. ✅ Package and deploy Lambda function
5. ✅ Create test scripts

---

## 📋 Manual Setup (Alternative)

If you prefer manual setup, follow `LAMBDA_SETUP_GUIDE.md` step by step.

---

## 🧪 Test Your Setup

After setup, test with a small batch:

```bash
# Test with test_recipients.csv
./test_lambda.sh
```

Or test with a specific batch:

```bash
./send_lambda_batch.sh recipients_batch_01.csv test
```

---

## 📧 Send Production Emails

Send to a batch:

```bash
./send_lambda_batch.sh recipients_batch_01.csv
./send_lambda_batch.sh recipients_batch_02.csv
./send_lambda_batch.sh recipients_batch_03.csv
./send_lambda_batch.sh recipients_batch_04.csv
```

---

## 📊 Monitor Execution

View logs in real-time:

```bash
aws logs tail /aws/lambda/email-sender --follow --region us-west-2
```

Or check in AWS Console:
- CloudWatch → Log Groups → `/aws/lambda/email-sender`

---

## 🔧 Update Lambda Code

If you modify `ses_emailer.py` or `lambda_handler.py`:

```bash
./deploy_to_lambda.sh
aws lambda update-function-code \
  --function-name email-sender \
  --zip-file fileb://lambda-deployment.zip \
  --region us-west-2
```

---

## 📝 Configuration

Your configuration is saved in `lambda_config.json`:

```json
{
  "function_name": "email-sender",
  "region": "us-west-2",
  "s3_buckets": {
    "templates": "amaze-emailer-templates-XXXXX",
    "recipients": "amaze-emailer-recipients-XXXXX",
    "logs": "amaze-emailer-logs-XXXXX"
  },
  "sender": "studio_support@amaze.co",
  "sender_name": "Amaze Software",
  "subject": "Important update: Amaze Studio will shut down December 15th, 2025"
}
```

---

## ⚠️ Important Notes

1. **Lambda Timeout:** 15 minutes max. For 4,000+ emails, consider EC2 instead.
2. **SES Limits:** Make sure you're out of sandbox mode for production.
3. **S3 Buckets:** Bucket names must be globally unique.
4. **IAM Permissions:** The setup script uses full access policies. For production, create custom policies with least privilege.

---

## 🆘 Troubleshooting

**Function not found:**
- Run `./setup_lambda.sh` again

**Access denied:**
- Check IAM role has SES and S3 permissions
- Verify sender email is verified in SES

**Timeout:**
- Reduce batch size
- Split into multiple Lambda invocations
- Consider EC2 for very large lists

**View detailed logs:**
```bash
aws logs tail /aws/lambda/email-sender --follow --region us-west-2
```

---

## 💰 Cost

- **Lambda:** Free tier covers most use cases
- **S3:** ~$0.01/month for storage
- **SES:** $0.10 per 1,000 emails
- **Total for 462 emails:** ~$0.06/month

---

## 📚 More Information

- Full setup guide: `LAMBDA_SETUP_GUIDE.md`
- Deployment guide: `AWS_DEPLOYMENT_GUIDE.md`
- EC2 setup: `EC2_SETUP_GUIDE.md` (coming next)

