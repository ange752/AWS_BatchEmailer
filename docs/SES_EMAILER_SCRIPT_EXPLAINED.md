# ses_emailer.py - Script Overview

## What is it?

`ses_emailer.py` is the **main Python script** that handles sending mass emails via AWS SES (Simple Email Service). It's the core component used by both Lambda and EC2 deployments.

---

## Main Features

### 1. **Email Sending**
- Send emails to single or multiple recipients
- Support for both plain text and HTML emails
- BCC support for recipient privacy
- Custom sender display name

### 2. **Batch Processing**
- Automatically splits large recipient lists into batches
- Configurable batch size (default: 50)
- Rate limiting to respect AWS SES limits
- Progress tracking

### 3. **File Support**
- Load recipients from CSV or JSON files
- Load email templates from files
- Support for email attachments

### 4. **Email Verification**
- Verify email addresses with SES
- Check verification status

### 5. **Preview Mode**
- Preview emails before sending
- View in terminal (text) or browser (HTML)

---

## Main Components

### `SESEmailer` Class

The core class that handles all email operations:

- **`send_email()`** - Send email to recipients
- **`send_email_batch()`** - Send emails in batches with rate limiting
- **`send_email_with_attachments()`** - Send emails with file attachments
- **`verify_email_identity()`** - Verify sender email with SES

### Helper Functions

- **`load_recipients_from_file()`** - Load recipients from CSV/JSON files
- **`preview_email()`** - Preview email before sending
- **`main()`** - Command-line interface

---

## Command-Line Usage

### Basic Examples

**Send to single recipient:**
```bash
python3 ses_emailer.py \
  --sender studio_support@amaze.co \
  --recipients user@example.com \
  --subject "Hello" \
  --body "Plain text message"
```

**Send to list from file:**
```bash
python3 ses_emailer.py \
  --sender studio_support@amaze.co \
  --recipients-file recipients.csv \
  --subject "Newsletter" \
  --body-file email_template.txt \
  --body-html-file email_template.html
```

**Send with BCC (privacy):**
```bash
python3 ses_emailer.py \
  --sender studio_support@amaze.co \
  --recipients-file recipients.csv \
  --subject "Update" \
  --body-file email.txt \
  --use-bcc
```

**Send in batches:**
```bash
python3 ses_emailer.py \
  --sender studio_support@amaze.co \
  --recipients-file recipients.csv \
  --subject "Campaign" \
  --body-file email.txt \
  --batch-size 50 \
  --rate-limit 0.1
```

**Preview before sending:**
```bash
python3 ses_emailer.py \
  --sender studio_support@amaze.co \
  --recipients user@example.com \
  --subject "Test" \
  --body-file email.txt \
  --body-html-file email.html \
  --preview
```

**Verify email:**
```bash
python3 ses_emailer.py --verify studio_support@amaze.co
```

---

## Command-Line Arguments

| Argument | Description | Required |
|----------|-------------|----------|
| `--sender` | Sender email (must be verified) | Yes* |
| `--sender-name` | Display name for sender | No |
| `--recipients` | List of recipient emails | Yes* |
| `--recipients-file` | CSV/JSON file with recipients | Yes* |
| `--subject` | Email subject line | Yes |
| `--body` | Plain text email body | Yes* |
| `--body-file` | File with plain text body | Yes* |
| `--body-html` | HTML email body | No |
| `--body-html-file` | File with HTML body | No |
| `--attachment` | File to attach (can repeat) | No |
| `--reply-to` | Reply-to email addresses | No |
| `--region` | AWS region (default: us-west-2) | No |
| `--batch-size` | Recipients per batch (default: 50) | No |
| `--use-bcc` | Use BCC for privacy (default: True) | No |
| `--no-bcc` | Disable BCC | No |
| `--rate-limit` | Seconds between batches (default: 0.1) | No |
| `--preview` | Preview email without sending | No |
| `--verify` | Verify email address with SES | No |

*Either option required

---

## How It's Used

### In Lambda
- Lambda handler (`lambda_handler.py`) calls `SESEmailer` class
- Downloads templates/recipients from S3
- Sends emails via SES
- Returns results

### In EC2
- EC2 scripts (`ec2_send_campaign.sh`, etc.) call the script directly
- Downloads templates/recipients from S3
- Runs `ses_emailer.py` with command-line arguments
- Sends emails via SES

### Standalone
- Can be run directly from command line
- Useful for testing and small campaigns

---

## Key Features Explained

### BCC Privacy
When `--use-bcc` is enabled:
- Recipients can't see each other's email addresses
- Each recipient only sees their own address in "To" field
- Protects recipient privacy

### Batch Processing
For large lists (> batch-size):
- Automatically splits into batches
- Sends batches sequentially
- Respects rate limits
- Shows progress

### Rate Limiting
- Prevents hitting AWS SES rate limits
- Configurable delay between batches
- Default: 0.1 seconds (10 batches/second)

---

## Dependencies

- `boto3` - AWS SDK for Python
- `botocore` - Core AWS functionality
- Python 3.7+

---

## File Structure

```
ses_emailer.py
├── SESEmailer class
│   ├── __init__() - Initialize SES client
│   ├── send_email() - Send single email
│   ├── send_email_batch() - Send in batches
│   ├── send_email_with_attachments() - Send with files
│   └── verify_email_identity() - Verify email
├── load_recipients_from_file() - Load from CSV/JSON
├── preview_email() - Preview before sending
└── main() - CLI interface
```

---

## Example Workflow

1. **Prepare files:**
   - Create email template (`email_template.txt`, `email_template.html`)
   - Create recipient list (`recipients.csv`)

2. **Run script:**
   ```bash
   python3 ses_emailer.py \
     --sender studio_support@amaze.co \
     --sender-name "Amaze Software" \
     --recipients-file recipients.csv \
     --subject "Important Update" \
     --body-file email_template.txt \
     --body-html-file email_template.html \
     --batch-size 50 \
     --use-bcc
   ```

3. **Script does:**
   - Loads recipients from CSV
   - Loads templates from files
   - Splits into batches (if needed)
   - Sends emails via SES
   - Shows progress and results

---

## Summary

`ses_emailer.py` is the **core email sending engine** that:
- ✅ Handles all AWS SES interactions
- ✅ Supports batch processing for large lists
- ✅ Provides privacy with BCC
- ✅ Works with Lambda, EC2, or standalone
- ✅ Includes preview and verification features

It's the script that actually sends your emails!

