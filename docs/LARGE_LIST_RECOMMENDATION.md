# Best Approach for 4,000 Email List

## Quick Answer: **EC2 is Better for 4,000 Emails**

For a 4,000 email list, **EC2 is the recommended choice** because:
- ✅ No execution time limits
- ✅ More reliable for large batches
- ✅ Better error handling and recovery
- ✅ Can pause/resume if needed
- ✅ Lower risk of timeout issues

---

## Detailed Comparison

### Lambda Limitations for 4,000 Emails

**Time Calculation:**
- 4,000 emails ÷ 50 per batch = **80 batches**
- With BCC enabled: Each email sent individually = **4,000 API calls**
- Rate limit: 0.1 seconds between batches = **8 seconds minimum** (just delays)
- SES API response time: ~100-200ms per call
- **Total estimated time: 7-15 minutes** (approaching Lambda's 15-minute limit)

**Risks:**
- ⚠️ Could timeout if SES is slow
- ⚠️ No easy way to resume if interrupted
- ⚠️ Need to split into multiple Lambda invocations
- ⚠️ More complex error handling

**Cost:** ~$0.01 (still very cheap)

---

### EC2 Advantages for 4,000 Emails

**Benefits:**
- ✅ **No time limits** - Can run for hours if needed
- ✅ **More reliable** - Won't timeout mid-send
- ✅ **Better monitoring** - Can watch progress in real-time
- ✅ **Easy recovery** - Can resume from where it stopped
- ✅ **Flexible** - Can adjust batch size/rate on the fly

**Time:** Same 7-15 minutes, but no timeout risk

**Cost:** 
- **One-time send:** ~$0.10 (t3.small for 1 hour, then stop)
- **Monthly:** ~$15 if left running (but you can stop it)

---

## Recommendation: EC2 for 4,000 Emails

### Setup Steps:

1. **Launch EC2 Instance:**
   ```bash
   # Use t3.small (2 vCPU, 2GB RAM) - sufficient for this
   # Amazon Linux 2023 AMI
   # Security Group: Allow SSH (port 22) from your IP
   ```

2. **Connect and Setup:**
   ```bash
   ssh -i your-key.pem ec2-user@your-instance-ip
   
   # Install dependencies
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

3. **Upload Script:**
   ```bash
   # Create directory
   mkdir -p ~/emailer
   cd ~/emailer
   
   # Upload your script (via SCP)
   # Or download from S3 if you stored it there
   ```

4. **Store Files in S3:**
   ```bash
   # Upload templates
   aws s3 cp email_template.txt s3://your-bucket/templates/
   aws s3 cp email_template.html s3://your-bucket/templates/
   
   # Upload recipient list
   aws s3 cp recipients_4000.csv s3://your-bucket/recipients/
   ```

5. **Create Send Script:**
   ```bash
   # create send_4000.sh
   #!/bin/bash
   
   BUCKET="your-bucket"
   REGION="us-west-2"
   
   # Download from S3
   aws s3 cp s3://$BUCKET/recipients/recipients_4000.csv /tmp/recipients.csv
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
     --region $REGION \
     --batch-size 50 \
     --use-bcc \
     --rate-limit 0.1
   
   # Upload logs
   aws s3 cp send_log.txt s3://$BUCKET/logs/$(date +%Y%m%d_%H%M%S)_send.log
   ```

6. **Run:**
   ```bash
   chmod +x send_4000.sh
   ./send_4000.sh
   ```

7. **Stop Instance When Done:**
   ```bash
   # Stop the instance to save costs
   aws ec2 stop-instances --instance-ids i-xxxxxxxxx
   ```

---

## Alternative: Lambda with Step Functions (For Automation)

If you want serverless but need to handle 4,000 emails:

**Use Step Functions to orchestrate multiple Lambda invocations:**
- Split 4,000 into 4 batches of 1,000
- Each Lambda handles 1,000 emails (~3-4 minutes)
- Step Functions coordinates the batches
- More complex but fully serverless

**Cost:** ~$0.05 (Step Functions + Lambda)

---

## Cost Comparison for 4,000 Emails

| Option | One-Time Cost | Monthly Cost | Reliability |
|--------|--------------|--------------|-------------|
| **EC2 (t3.small)** | $0.10 (1 hour) | $15 (if running) | ⭐⭐⭐⭐⭐ |
| **Lambda** | $0.01 | $0 | ⭐⭐⭐ |
| **Lambda + Step Functions** | $0.05 | $0 | ⭐⭐⭐⭐ |

**Note:** EC2 can be stopped after sending, so actual cost is just the hour of runtime (~$0.10).

---

## Performance Estimates

**4,000 emails with current settings:**
- Batch size: 50
- Rate limit: 0.1s (10 batches/second)
- BCC enabled: Individual sends

**Timing:**
- 4,000 emails ÷ 50 = 80 batches
- 80 batches × 0.1s delay = 8 seconds (just delays)
- 4,000 API calls × ~150ms = 600 seconds (10 minutes)
- **Total: ~10-12 minutes**

**SES Limits:**
- Default sending rate: 1 email/second (sandbox) or 14 emails/second (production)
- If you're in production: 4,000 ÷ 14 = ~5 minutes minimum
- Your rate limit of 0.1s (10/second) is fine if you have production access

---

## Final Recommendation

### For 4,000 Emails: **Use EC2**

**Why:**
1. ✅ No timeout risk
2. ✅ Can monitor progress
3. ✅ Easy to pause/resume
4. ✅ Cost is minimal (~$0.10 for one-time)
5. ✅ More reliable for large batches

**Setup Time:** ~30 minutes
**Runtime:** ~10-12 minutes
**Total Cost:** ~$0.10 (one-time)

### When to Use Lambda Instead:
- ✅ Lists under 1,000 emails
- ✅ Need fully automated/scheduled sends
- ✅ Want zero infrastructure management
- ✅ Multiple small campaigns

---

## Quick Start: EC2 Setup Script

I can create a setup script that:
1. Launches EC2 instance
2. Installs dependencies
3. Downloads script from S3
4. Runs the email send
5. Stops instance when done

Would you like me to create this automated setup script?

