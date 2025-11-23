# AWS Deployment Guide for Mass Marketing Emails

## Overview

This guide covers the best ways to deploy your email sending solution on AWS for mass marketing campaigns.

## Recommended Architecture Options

### Option 1: AWS Lambda (Recommended for Scheduled/Event-Driven)

**Best for:**
- Scheduled email campaigns
- Event-triggered sends (e.g., user signups)
- Cost-effective for intermittent use
- Automatic scaling

**Architecture:**
```
CloudWatch Events (Schedule) → Lambda → SES → Emails Sent
```

**Setup:**
1. Package script as Lambda function
2. Store email templates in S3
3. Store recipient lists in S3
4. Use CloudWatch Events for scheduling
5. Lambda reads from S3 and sends via SES

**Pros:**
- Pay only for execution time
- Automatic scaling
- No server management
- Built-in retry logic

**Cons:**
- 15-minute execution limit (can use Step Functions for longer)
- Cold start latency
- Memory/CPU limits

**Cost:** ~$0.20 per 1M requests + execution time

---

### Option 2: AWS EC2 (Recommended for Large/Continuous Campaigns)

**Best for:**
- Large-scale continuous sending
- Complex processing requirements
- Long-running campaigns
- Full control over environment

**Architecture:**
```
EC2 Instance → Reads from S3 → SES → Emails Sent
```

**Setup:**
1. Launch EC2 instance (t3.small or t3.medium)
2. Install Python and dependencies
3. Store templates/recipients in S3
4. Run script directly or via cron
5. Use CloudWatch for monitoring

**Pros:**
- No execution time limits
- Full control
- Can handle very large lists
- Persistent storage

**Cons:**
- Always running = always paying
- Need to manage server
- Manual scaling

**Cost:** ~$15-30/month for t3.small + data transfer

---

### Option 3: AWS ECS/Fargate (Recommended for Containerized/Scaling)

**Best for:**
- Containerized deployments
- Need to scale up/down
- Multiple campaigns running
- Team deployments

**Architecture:**
```
ECS Task → Reads from S3 → SES → Emails Sent
```

**Setup:**
1. Containerize the script (Docker)
2. Push to ECR (Elastic Container Registry)
3. Deploy as ECS task
4. Auto-scale based on queue size

**Pros:**
- Containerized (consistent environment)
- Auto-scaling
- Good for multiple campaigns
- Easy to update

**Cons:**
- More complex setup
- Container management overhead

**Cost:** ~$0.04/vCPU-hour + $0.004/GB-hour

---

### Option 4: AWS Step Functions + Lambda (Recommended for Complex Workflows)

**Best for:**
- Complex multi-step campaigns
- Need to handle bounces/complaints
- Workflow orchestration
- Long-running processes

**Architecture:**
```
Step Functions → Lambda Functions → SES → SNS (Bounces) → Lambda (Process)
```

**Pros:**
- Handles long-running processes
- Built-in error handling
- Visual workflow
- Can orchestrate multiple steps

**Cons:**
- More complex
- Higher cost for simple use cases

---

## Recommended Setup for Mass Marketing

### Complete Architecture:

```
S3 (Templates & Lists)
    ↓
Lambda/EC2 (Email Sender)
    ↓
SES (Email Service)
    ↓
SNS (Notifications)
    ↓
S3 (Bounce/Complaint Logs)
```

### Key AWS Services:

1. **SES** - Email sending (already using)
2. **S3** - Store templates, recipient lists, logs
3. **Lambda** - Serverless execution
4. **SNS** - Bounce/complaint notifications
5. **CloudWatch** - Monitoring and logging
6. **IAM** - Security and permissions
7. **Step Functions** - Workflow orchestration (optional)

---

## Step-by-Step: Lambda Deployment (Recommended)

### 1. Prepare Your Code

Create a Lambda-compatible version:

```python
# lambda_handler.py
import json
import boto3
from ses_emailer import SESEmailer, load_recipients_from_file

def lambda_handler(event, context):
    # Get parameters from event
    sender = event.get('sender')
    sender_name = event.get('sender_name', 'Amaze Software')
    s3_bucket = event.get('s3_bucket')
    recipients_key = event.get('recipients_key')  # S3 key for recipients CSV
    template_key = event.get('template_key')     # S3 key for template
    
    # Download from S3
    s3 = boto3.client('s3')
    
    # Download recipients
    recipients_file = '/tmp/recipients.csv'
    s3.download_file(s3_bucket, recipients_key, recipients_file)
    
    # Download templates
    body_text_file = '/tmp/email_template.txt'
    body_html_file = '/tmp/email_template.html'
    s3.download_file(s3_bucket, f'{template_key}.txt', body_text_file)
    s3.download_file(s3_bucket, f'{template_key}.html', body_html_file)
    
    # Load recipients
    recipients = load_recipients_from_file(recipients_file)
    
    # Read templates
    with open(body_text_file) as f:
        body_text = f.read()
    with open(body_html_file) as f:
        body_html = f.read()
    
    # Send emails
    emailer = SESEmailer(region_name='us-west-2')
    result = emailer.send_email_batch(
        sender=sender,
        recipients=recipients,
        subject=event.get('subject'),
        body_text=body_text,
        body_html=body_html,
        batch_size=50,
        use_bcc=True,
        sender_name=sender_name
    )
    
    return {
        'statusCode': 200,
        'body': json.dumps(result)
    }
```

### 2. Package for Lambda

```bash
# Create deployment package
zip -r lambda-deployment.zip ses_emailer.py lambda_handler.py boto3/ botocore/
```

### 3. Upload to Lambda

- Create Lambda function
- Upload zip file
- Set timeout to 15 minutes (max)
- Set memory to 512MB-1GB
- Configure IAM role with SES and S3 permissions

### 4. Store Files in S3

```bash
# Upload templates
aws s3 cp email_template.txt s3://your-bucket/templates/email_template.txt
aws s3 cp email_template.html s3://your-bucket/templates/email_template.html

# Upload recipient lists
aws s3 cp recipients_batch_01.csv s3://your-bucket/recipients/batch_01.csv
```

### 5. Invoke Lambda

**Via AWS Console:**
```json
{
  "sender": "studio_support@amaze.co",
  "sender_name": "Amaze Software",
  "s3_bucket": "your-bucket",
  "recipients_key": "recipients/batch_01.csv",
  "template_key": "templates/email_template",
  "subject": "Important update: Amaze Studio will shut down December 15th, 2025"
}
```

**Via AWS CLI:**
```bash
aws lambda invoke \
  --function-name email-sender \
  --payload file://payload.json \
  response.json
```

**Via CloudWatch Events (Scheduled):**
- Create CloudWatch Events rule
- Schedule (e.g., daily at 9 AM)
- Target: Lambda function

---

## Step-by-Step: EC2 Deployment (For Large Campaigns)

### 1. Launch EC2 Instance

```bash
# Launch t3.small instance
# AMI: Amazon Linux 2023
# Security Group: Allow SSH (port 22)
```

### 2. Setup on EC2

```bash
# SSH into instance
ssh -i your-key.pem ec2-user@your-instance-ip

# Install Python and dependencies
sudo yum update -y
sudo yum install python3 pip3 -y
pip3 install boto3

# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Configure AWS credentials
aws configure
```

### 3. Deploy Script

```bash
# Create directory
mkdir -p ~/emailer
cd ~/emailer

# Upload your script (via SCP or git)
# Or download from S3
aws s3 cp s3://your-bucket/scripts/ses_emailer.py .

# Make executable
chmod +x ses_emailer.py
```

### 4. Store Files in S3

```bash
# Upload templates and recipient lists to S3
aws s3 sync ./templates/ s3://your-bucket/templates/
aws s3 sync ./recipients/ s3://your-bucket/recipients/
```

### 5. Create Send Script

```bash
# create send_campaign.sh
#!/bin/bash
BUCKET="your-bucket"
REGION="us-west-2"

# Download latest files from S3
aws s3 cp s3://$BUCKET/recipients/recipients_batch_01.csv /tmp/recipients.csv
aws s3 cp s3://$BUCKET/templates/email_template.txt /tmp/email_template.txt
aws s3 cp s3://$BUCKET/templates/email_template.html /tmp/email_template.html

# Send emails
python3 ses_emailer.py \
  --sender studio_support@amaze.co \
  --sender-name "Amaze Software" \
  --recipients-file /tmp/recipients.csv \
  --subject "Important update: Amaze Studio will shut down December 15th, 2025" \
  --body-file /tmp/email_template.txt \
  --body-html-file /tmp/email_template.html \
  --region $REGION

# Upload logs to S3
aws s3 cp send_log.txt s3://$BUCKET/logs/$(date +%Y%m%d)_send.log
```

### 6. Run Manually or Schedule

```bash
# Run manually
./send_campaign.sh

# Or schedule with cron
crontab -e
# Add: 0 9 * * * /home/ec2-user/emailer/send_campaign.sh
```

---

## Best Practices for Mass Marketing

### 1. Handle Bounces and Complaints

**Setup SNS Notifications:**

```python
# Configure SES to send bounces/complaints to SNS
# Then process them:

import boto3
import json

def handle_bounce(event, context):
    message = json.loads(event['Records'][0]['Sns']['Message'])
    email = message['mail']['destination'][0]
    
    # Remove from future sends
    # Log to S3 or database
    print(f"Bounce: {email}")
```

### 2. Monitor Sending

**CloudWatch Metrics:**
- Sending quota usage
- Bounce rate
- Complaint rate
- Send rate

**Set up alarms:**
- Bounce rate > 5%
- Complaint rate > 0.1%
- Approaching sending quota

### 3. List Management

**Store in S3 or DynamoDB:**
- Active recipients
- Bounced emails
- Unsubscribed emails
- Suppression list

**Before sending:**
- Remove bounced emails
- Remove unsubscribed
- Check suppression list

### 4. Compliance

**For Marketing Emails:**
- Include unsubscribe link
- Include physical address
- Honor unsubscribe requests
- Maintain suppression list
- Follow CAN-SPAM, GDPR, etc.

### 5. Cost Optimization

**SES Costs:**
- $0.10 per 1,000 emails
- 462 emails = ~$0.05
- 10,000 emails = ~$1.00

**Lambda Costs:**
- First 1M requests free
- $0.20 per 1M requests after
- Execution time: $0.0000166667 per GB-second

**EC2 Costs:**
- t3.small: ~$15/month
- t3.medium: ~$30/month

---

## Recommended Setup for Your Use Case

### For 462 Emails (Current Campaign):

**Option A: Lambda (One-time send)**
- Cost: ~$0.01 (free tier covers it)
- Setup time: 30 minutes
- Best for: One-time or occasional sends

**Option B: EC2 (Ongoing campaigns)**
- Cost: ~$15/month
- Setup time: 1 hour
- Best for: Regular marketing campaigns

### For Larger Scale (10,000+ emails):

**Recommended: Lambda + Step Functions**
- Handles long-running processes
- Automatic retries
- Cost-effective
- Scalable

---

## Quick Start: Lambda Deployment

1. **Create S3 bucket:**
```bash
aws s3 mb s3://amaze-emailer-templates
aws s3 mb s3://amaze-emailer-recipients
```

2. **Upload files:**
```bash
aws s3 cp email_template.txt s3://amaze-emailer-templates/
aws s3 cp email_template.html s3://amaze-emailer-templates/
aws s3 cp recipients_batch_01.csv s3://amaze-emailer-recipients/
```

3. **Create Lambda function** (use the lambda_handler.py code above)

4. **Invoke:**
```bash
aws lambda invoke \
  --function-name email-sender \
  --payload '{
    "sender": "studio_support@amaze.co",
    "sender_name": "Amaze Software",
    "s3_bucket": "amaze-emailer-templates",
    "recipients_key": "recipients_batch_01.csv",
    "template_key": "email_template",
    "subject": "Important update: Amaze Studio will shut down December 15th, 2025"
  }' \
  response.json
```

---

## Additional Considerations

### 1. Unsubscribe Handling

Add unsubscribe link to email template:
```html
<p><a href="https://amaze.co/unsubscribe?email={{email}}">Unsubscribe</a></p>
```

Store unsubscribes in DynamoDB or S3, check before sending.

### 2. A/B Testing

Use Lambda to send variations:
- Different subject lines
- Different content
- Track opens/clicks

### 3. Analytics

Track:
- Open rates (via SES Configuration Sets)
- Click rates
- Bounce rates
- Unsubscribe rates

### 4. Security

- Use IAM roles (not access keys in code)
- Encrypt S3 buckets
- Use VPC endpoints for S3 access
- Enable CloudTrail for audit logs

---

## Cost Estimate

**For 462 emails/month:**
- SES: $0.05/month
- Lambda: Free (within free tier)
- S3: $0.01/month
- **Total: ~$0.06/month**

**For 10,000 emails/month:**
- SES: $1.00/month
- Lambda: Free
- S3: $0.10/month
- **Total: ~$1.10/month**

**For 100,000 emails/month:**
- SES: $10.00/month
- Lambda: ~$0.20/month
- S3: $1.00/month
- **Total: ~$11.20/month**

---

## Next Steps

1. Choose deployment method (Lambda recommended for most cases)
2. Set up S3 buckets for templates/lists
3. Create Lambda function or EC2 instance
4. Configure SNS for bounce/complaint handling
5. Set up CloudWatch monitoring
6. Test with small batch
7. Scale up to full campaign

Would you like me to create the Lambda deployment package or EC2 setup scripts?

