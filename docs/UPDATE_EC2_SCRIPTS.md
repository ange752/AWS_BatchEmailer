# Update Scripts on EC2 Instance

## Quick Update Command

Once you're SSH'd into your EC2 instance, run:

```bash
cd ~/emailer
aws s3 sync s3://amaze-aws-emailer/scripts/ . --region us-west-2
chmod +x *.sh *.py
```

This will download all updated scripts from S3.

---

## Individual Script Updates

If you only want to update specific scripts:

```bash
cd ~/emailer

# Update send campaign script
aws s3 cp s3://amaze-aws-emailer/scripts/ec2_send_campaign.sh . --region us-west-2
chmod +x ec2_send_campaign.sh

# Update custom send script
aws s3 cp s3://amaze-aws-emailer/scripts/ec2_send_custom.sh . --region us-west-2
chmod +x ec2_send_custom.sh

# Update main emailer script
aws s3 cp s3://amaze-aws-emailer/scripts/ses_emailer.py . --region us-west-2
chmod +x ses_emailer.py
```

---

## What's Updated

The following scripts have been updated in S3:

1. **ec2_send_campaign.sh**
   - Now accepts template name and recipient list as parameters
   - Usage: `./ec2_send_campaign.sh [batch] [template] [recipients]`

2. **ec2_send_custom.sh** (NEW)
   - Flexible script for custom campaigns
   - Usage: `./ec2_send_custom.sh <recipients> [template] [subject]`

3. **ec2_send_all_batches.sh**
   - Sends to all batches sequentially

4. **ses_emailer.py**
   - Main email sending script

---

## Verify Updates

After downloading, verify the scripts are updated:

```bash
# Check script help/usage
./ec2_send_custom.sh

# Should show usage and list available templates/recipients
```

---

## Full Setup (First Time)

If this is your first time setting up on EC2:

```bash
# Create directory
mkdir -p ~/emailer
cd ~/emailer

# Download all scripts
aws s3 sync s3://amaze-aws-emailer/scripts/ . --region us-west-2

# Make executable
chmod +x *.sh *.py

# Verify
ls -la
```

