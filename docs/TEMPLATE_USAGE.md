# Email Template Usage Guide

## Files Created

1. **`email_template.txt`** - Plain text email template (edit before sending)
2. **`email_template.html`** - HTML email template (edit before sending)
3. **`test_recipients.csv`** - Test recipient list with ange752@gmail.com and islington73@gmail.com

## How to Use

### Step 1: Edit the Email Template

Open and edit either:
- `email_template.txt` for plain text emails
- `email_template.html` for HTML emails (recommended)

Customize:
- The greeting and message content
- Your name and company information
- Any links or buttons
- Colors and styling (in HTML version)

### Step 2: Preview the Email (Recommended)

Before sending, preview how your email will look:

```bash
python ses_emailer.py \
  --sender your-verified-email@example.com \
  --recipients-file test_recipients.csv \
  --subject "Your Email Subject" \
  --body-file email_template.txt \
  --body-html-file email_template.html \
  --preview
```

This will:
- Show the plain text version in the terminal
- Open the HTML version in your browser
- **NOT send the email** - it's safe to test

### Step 3: Send the Email

**Using plain text template:**
```bash
python ses_emailer.py \
  --sender your-verified-email@example.com \
  --recipients-file test_recipients.csv \
  --subject "Your Email Subject" \
  --body-file email_template.txt
```

**Using HTML template (recommended):**
```bash
python ses_emailer.py \
  --sender your-verified-email@example.com \
  --recipients-file test_recipients.csv \
  --subject "Your Email Subject" \
  --body-file email_template.txt \
  --body-html-file email_template.html
```

**Note:** Always provide both plain text and HTML versions. The plain text version is used as a fallback.

### Step 4: Test First (Optional)

Before sending to all recipients, you can test with a single email (or just use --preview):
```bash
python ses_emailer.py \
  --sender your-verified-email@example.com \
  --recipients your-test-email@example.com \
  --subject "Test Email" \
  --body-file email_template.txt \
  --body-html-file email_template.html
```

## Quick Tips

- Edit the template files in any text editor
- Save your changes before running the script
- The HTML template includes inline CSS that works in most email clients
- You can add images by hosting them online and using `<img src="URL">` tags
- Test your email in multiple email clients before sending to all recipients

