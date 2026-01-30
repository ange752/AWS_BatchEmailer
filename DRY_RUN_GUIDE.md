# Dry Run / Preview Guide

How to test your email campaigns without actually sending emails.

## Quick Dry Run

Add `--preview` flag to any command:

```bash
python3 ses_emailer.py \
  --sender studio_support@amaze.co \
  --recipients-file 1099_List3_2026.csv \
  --subject "Test Subject" \
  --body-file email_template.txt \
  --body-html-file email_template.html \
  --preview
```

**This will:**
- ✅ Show email preview in terminal
- ✅ Open HTML preview in browser
- ✅ Show all email details
- ❌ **NOT send any emails**

## Examples

### Preview with Recipient File

```bash
python3 ses_emailer.py \
  --sender studio_support@amaze.co \
  --recipients-file 1099_List3_2026.csv \
  --subject "1099 Tax Form Available" \
  --body-file 1099_Tax_Reminder.txt \
  --body-html-file 1099_Tax_Reminder.html \
  --preview
```

### Preview with Single Recipient

```bash
python3 ses_emailer.py \
  --sender studio_support@amaze.co \
  --recipients your-email@example.com \
  --subject "Test Email" \
  --body-file email_template.txt \
  --body-html-file email_template.html \
  --preview
```

### Preview with Personalized Content

```bash
python3 ses_emailer.py \
  --sender studio_support@amaze.co \
  --recipients-file 1099_List3_2026.csv \
  --subject "Hello [NAME]" \
  --body-file email_template.txt \
  --body-html-file email_template.html \
  --personalized \
  --preview
```

## What Preview Shows

1. **Terminal Output:**
   - From/To addresses
   - Subject line
   - Plain text version
   - File attachments (if any)

2. **Browser Preview:**
   - Opens HTML version in your default browser
   - Shows exactly how email will appear
   - Includes warning banner: "⚠️ PREVIEW MODE - This preview will not be sent"

## Testing Before Sending

### Step 1: Preview First

```bash
python3 ses_emailer.py \
  --sender studio_support@amaze.co \
  --recipients-file 1099_List3_2026.csv \
  --subject "Your Subject" \
  --body-file email_template.txt \
  --body-html-file email_template.html \
  --preview
```

### Step 2: Review Preview

- Check terminal output
- Review browser preview
- Verify subject, content, formatting

### Step 3: Send (Remove --preview)

```bash
python3 ses_emailer.py \
  --sender studio_support@amaze.co \
  --recipients-file 1099_List3_2026.csv \
  --subject "Your Subject" \
  --body-file email_template.txt \
  --body-html-file email_template.html
  # No --preview flag = actually sends
```

## Testing with Small Batch

If you want to test with actual sending but to a small group:

### Option 1: Create Test CSV

```bash
# Create test file with just a few emails
head -5 1099_List3_2026.csv > test_recipients.csv
# Edit to keep header + 2-3 test emails

# Send to test group
python3 ses_emailer.py \
  --sender studio_support@amaze.co \
  --recipients-file test_recipients.csv \
  --subject "Test Email" \
  --body-file email_template.txt \
  --body-html-file email_template.html
```

### Option 2: Use Preview with Sample

```bash
# Preview shows you exactly what will be sent
python3 ses_emailer.py \
  --sender studio_support@amaze.co \
  --recipients-file 1099_List3_2026.csv \
  --subject "Test" \
  --body-file email_template.txt \
  --preview
```

## EC2 Dry Run

On EC2, you can also preview:

```bash
# SSH into EC2
ssh -i ~/.ssh/oasis-dev-*.pem ec2-user@54.189.152.124

cd ~/emailer

# Download files first
aws s3 cp s3://amaze-aws-emailer/recipients/1099_List3_2026.csv /tmp/recipients.csv --region us-west-2
aws s3 cp s3://amaze-aws-emailer/templates/email_template.txt /tmp/email_template.txt --region us-west-2
aws s3 cp s3://amaze-aws-emailer/templates/email_template.html /tmp/email_template.html --region us-west-2

# Preview (won't open browser on EC2, but shows in terminal)
python3 ses_emailer.py \
  --sender studio_support@amaze.co \
  --recipients-file /tmp/recipients.csv \
  --subject "Test" \
  --body-file /tmp/email_template.txt \
  --body-html-file /tmp/email_template.html \
  --preview
```

## What Preview Doesn't Test

Preview mode shows you the email content but doesn't:
- ❌ Test actual email delivery
- ❌ Test SES sending limits
- ❌ Test bounce/complaint handling
- ❌ Test rate limiting
- ❌ Test batch processing

For those, use a small test batch with real sending.

## Quick Reference

```bash
# Preview (dry run)
python3 ses_emailer.py [options] --preview

# Send (remove --preview)
python3 ses_emailer.py [options]
```

## Tips

1. **Always preview first** before large campaigns
2. **Check both text and HTML** versions
3. **Verify personalization** if using `--personalized`
4. **Test with your own email** before sending to full list
5. **Review browser preview** to see exact formatting
