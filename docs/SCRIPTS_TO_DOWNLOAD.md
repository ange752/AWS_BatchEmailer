# Scripts to Download from S3

## Required Scripts

When setting up on EC2, you need to download these scripts from S3:

### 1. **ses_emailer.py** (REQUIRED)
- **What it is:** Main email sending script
- **Size:** ~39.5 KB
- **Purpose:** Core script that sends emails via AWS SES
- **Used by:** All send scripts

### 2. **ec2_send_campaign.sh** (REQUIRED)
- **What it is:** Script to send emails to a batch
- **Size:** ~1.9 KB
- **Purpose:** Sends emails to a specific batch (e.g., batch 01, 02, etc.)
- **Usage:** `./ec2_send_campaign.sh [batch_num] [template] [recipients]`

### 3. **ec2_send_custom.sh** (RECOMMENDED)
- **What it is:** Flexible script for custom campaigns
- **Size:** ~2.5 KB
- **Purpose:** Send with custom template, recipient list, and subject
- **Usage:** `./ec2_send_custom.sh <recipients> [template] [subject]`

### 4. **ec2_send_all_batches.sh** (OPTIONAL)
- **What it is:** Script to send to all batches sequentially
- **Size:** ~1 KB
- **Purpose:** Automatically sends to batches 01, 02, 03, 04, etc.
- **Usage:** `./ec2_send_all_batches.sh`

---

## Download Command

**Download all scripts at once:**
```bash
cd ~/emailer
aws s3 sync s3://amaze-aws-emailer/scripts/ . --region us-west-2
chmod +x *.sh *.py
```

**Download individual scripts:**
```bash
cd ~/emailer

# Main emailer script (REQUIRED)
aws s3 cp s3://amaze-aws-emailer/scripts/ses_emailer.py . --region us-west-2

# Send campaign script (REQUIRED)
aws s3 cp s3://amaze-aws-emailer/scripts/ec2_send_campaign.sh . --region us-west-2

# Custom send script (RECOMMENDED)
aws s3 cp s3://amaze-aws-emailer/scripts/ec2_send_custom.sh . --region us-west-2

# Send all batches script (OPTIONAL)
aws s3 cp s3://amaze-aws-emailer/scripts/ec2_send_all_batches.sh . --region us-west-2

# Make executable
chmod +x *.sh *.py
```

---

## What Each Script Does

### ses_emailer.py
- Core email sending functionality
- Handles batch processing
- Supports BCC, attachments, preview
- **Must have this to send emails**

### ec2_send_campaign.sh
- Downloads templates and recipients from S3
- Calls `ses_emailer.py` to send emails
- Good for batch-based campaigns
- **Easiest to use for standard campaigns**

### ec2_send_custom.sh
- Most flexible script
- Allows custom template names
- Allows custom recipient lists
- Allows custom subject lines
- **Best for custom campaigns**

### ec2_send_all_batches.sh
- Sends to multiple batches automatically
- Waits between batches
- **Useful for sending to all batches at once**

---

## Minimum Required

To send emails, you need at minimum:
1. ✅ `ses_emailer.py` - Core script
2. ✅ `ec2_send_campaign.sh` OR `ec2_send_custom.sh` - Wrapper script

---

## Verify Downloads

After downloading, verify:
```bash
ls -la

# Should show:
# -rwxr-xr-x  ses_emailer.py
# -rwxr-xr-x  ec2_send_campaign.sh
# -rwxr-xr-x  ec2_send_custom.sh
# -rwxr-xr-x  ec2_send_all_batches.sh
```

---

## Update Scripts

If scripts are updated in S3, re-download:
```bash
cd ~/emailer
aws s3 sync s3://amaze-aws-emailer/scripts/ . --region us-west-2
chmod +x *.sh *.py
```

---

## Summary

**Required:**
- `ses_emailer.py` - Core email sender
- `ec2_send_campaign.sh` - Batch sender

**Recommended:**
- `ec2_send_custom.sh` - Custom campaigns

**Optional:**
- `ec2_send_all_batches.sh` - Send all batches

**Quick download:**
```bash
aws s3 sync s3://amaze-aws-emailer/scripts/ . --region us-west-2
chmod +x *.sh *.py
```

