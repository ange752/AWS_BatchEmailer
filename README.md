# AWS SES Mass Email Sender

A simple Python script to send mass emails using AWS SES (Simple Email Service).

## Prerequisites

1. **AWS Account**: You need an AWS account with SES access
2. **AWS Credentials**: Configure your AWS credentials using one of these methods:
   - AWS CLI: `aws configure`
   - Environment variables: `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`
   - IAM role (if running on EC2)
   - Credentials file: `~/.aws/credentials`
3. **Verified Email Address**: Your sender email address must be verified in SES
   - In SES Sandbox mode, recipient addresses also need to be verified
   - To move out of Sandbox mode, request production access in AWS SES console

## Installation

1. Install Python dependencies:
```bash
pip install -r requirements.txt
```

## Usage

### Basic Usage

Send email to multiple recipients:

```bash
python ses_emailer.py \
  --sender your-email@example.com \
  --recipients recipient1@example.com recipient2@example.com \
  --subject "Hello from AWS SES" \
  --body "This is a test email sent via AWS SES"
```

### Using a Recipients File (CSV or JSON)

The script supports both CSV and JSON files for recipient lists.

#### CSV File Format

**Option 1: Simple CSV (one email per line, no header)**
```csv
user1@example.com
user2@example.com
user3@example.com
```

**Option 2: CSV with header**
```csv
email
user1@example.com
user2@example.com
user3@example.com
```

The script automatically detects common email column names: `email`, `Email`, `EMAIL`, `e-mail`, `E-mail`, `email_address`, `EmailAddress`. If no standard column is found, it uses the first column.

#### JSON File Format

**Option 1: Simple array**
```json
[
  "user1@example.com",
  "user2@example.com",
  "user3@example.com"
]
```

**Option 2: Object with recipients key**
```json
{
  "recipients": [
    "user1@example.com",
    "user2@example.com"
  ]
}
```

#### Usage

```bash
# Using CSV file
python ses_emailer.py \
  --sender your-email@example.com \
  --recipients-file recipients.csv \
  --subject "Hello" \
  --body "Test email"

# Using JSON file
python ses_emailer.py \
  --sender your-email@example.com \
  --recipients-file recipients.json \
  --subject "Hello" \
  --body "Test email"
```

### HTML Email

Send HTML formatted email (inline):

```bash
python ses_emailer.py \
  --sender your-email@example.com \
  --recipients user@example.com \
  --subject "HTML Email" \
  --body "Plain text version" \
  --body-html "<h1>HTML Version</h1><p>This is HTML content</p>"
```

### Using Email Templates from Files

For better formatting, especially with HTML emails, use template files:

```bash
# Plain text from file
python ses_emailer.py \
  --sender your-email@example.com \
  --recipients-file recipients.csv \
  --subject "Hello" \
  --body-file email_body.txt

# HTML email from files (recommended)
python ses_emailer.py \
  --sender your-email@example.com \
  --recipients-file recipients.csv \
  --subject "Hello" \
  --body-file email_body.txt \
  --body-html-file email_body.html
```

**Note:** Always provide both plain text and HTML versions. Plain text is used as a fallback for email clients that don't support HTML.

See `EMAIL_FORMATTING_GUIDE.md` for detailed formatting guidelines and examples.

### Preview Email Before Sending

Preview your email before sending to see exactly how it will appear:

```bash
# Preview with HTML
python ses_emailer.py \
  --sender your-email@example.com \
  --recipients-file test_recipients.csv \
  --subject "Hello" \
  --body-file email_template.txt \
  --body-html-file email_template.html \
  --preview
```

**Preview features:**
- Shows plain text version in the terminal
- Opens HTML version in your default web browser
- Displays sender, recipients, and subject
- **Does NOT send the email** - safe to test

**Note:** Sender and recipients are optional when using `--preview` mode, but recommended to see the full preview.

### Send Email with Attachments

Attach files to your emails:

```bash
# Single attachment
python ses_emailer.py \
  --sender your-email@example.com \
  --recipients-file test_recipients.csv \
  --subject "Document Attached" \
  --body-file email_template.txt \
  --attachment document.pdf

# Multiple attachments
python ses_emailer.py \
  --sender your-email@example.com \
  --recipients-file test_recipients.csv \
  --subject "Files Attached" \
  --body-file email_template.txt \
  --attachment file1.pdf \
  --attachment file2.jpg \
  --attachment file3.docx
```

**Attachment features:**
- Support for any file type (PDF, images, documents, etc.)
- Multiple attachments per email
- File size validation (AWS SES has limits - typically 10MB per email)
- Preview shows attachment information

**Important notes:**
- AWS SES has a 10MB limit per email (including attachments)
- Large attachments may take longer to send
- All attachments are sent to all recipients
- Preview mode shows attachment file names and sizes

### Verify Email Address

Before sending emails, verify your sender email address:

```bash
python ses_emailer.py --verify your-email@example.com
```

Check your email inbox and click the verification link from AWS.

### Specify AWS Region

```bash
python ses_emailer.py \
  --region us-west-2 \
  --sender your-email@example.com \
  --recipients user@example.com \
  --subject "Hello" \
  --body "Test"
```

### Add Reply-To Address

```bash
python ses_emailer.py \
  --sender your-email@example.com \
  --recipients user@example.com \
  --subject "Hello" \
  --body "Test" \
  --reply-to support@example.com
```

## Command Line Options

- `--sender, -s`: Sender email address (required, must be verified)
- `--recipients, -r`: List of recipient email addresses
- `--recipients-file, -f`: CSV or JSON file containing list of recipients
- `--subject`: Email subject line (required)
- `--body, -b`: Email body in plain text (required, unless using --body-file)
- `--body-file`: File containing plain text email body (alternative to --body)
- `--body-html`: Email body in HTML format (optional)
- `--body-html-file`: File containing HTML email body (optional)
- `--attachment, -a`: File to attach (can be used multiple times for multiple attachments)
- `--reply-to`: List of reply-to email addresses (optional)
- `--region`: AWS region (default: us-east-1)
- `--preview`: Preview email before sending (does not send email)
- `--verify`: Verify an email address with SES

## Important Notes

1. **SES Sandbox Mode**: If your account is in sandbox mode:
   - You can only send to verified email addresses
   - You have a sending limit (usually 200 emails/day)
   - Request production access to send to any email address

2. **Email Verification**: Always verify your sender email address before sending

3. **Rate Limits**: AWS SES has rate limits. For high-volume sending, consider:
   - Using SES Configuration Sets
   - Implementing retry logic with exponential backoff
   - Using SES Sending Statistics to monitor your sending

4. **Bounce and Complaint Handling**: Set up SNS notifications for bounces and complaints

## Example Script

You can also use the `SESEmailer` class in your own Python scripts:

```python
from ses_emailer import SESEmailer

# Initialize
emailer = SESEmailer(region_name='us-east-1')

# Send email
result = emailer.send_email(
    sender='sender@example.com',
    recipients=['user1@example.com', 'user2@example.com'],
    subject='Hello',
    body_text='This is the email body',
    body_html='<h1>This is the email body</h1>'
)

if result['success']:
    print(f"Email sent! Message ID: {result['message_id']}")
```

## Troubleshooting

- **MessageRejected**: Sender email not verified. Verify it first.
- **MailFromDomainNotVerified**: Domain not verified. Verify the domain in SES.
- **Throttling**: You're sending too fast. Implement rate limiting.
- **AccountSendingPaused**: Your account is paused. Check SES console.

## License

This script is provided as-is for educational and development purposes.

