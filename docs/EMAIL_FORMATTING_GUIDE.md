# Email Formatting Guide

This guide explains how to format email messages when using the AWS SES emailer script.

## Email Structure

An email consists of:
1. **Subject Line** - Required
2. **Plain Text Body** - Required (fallback for email clients that don't support HTML)
3. **HTML Body** - Optional (recommended for better formatting)

## Formatting Options

### Option 1: Inline Formatting (Command Line)

**Plain Text:**
```bash
python ses_emailer.py \
  --sender sender@example.com \
  --recipients user@example.com \
  --subject "Hello" \
  --body "This is a plain text email body."
```

**HTML:**
```bash
python ses_emailer.py \
  --sender sender@example.com \
  --recipients user@example.com \
  --subject "Hello" \
  --body "Plain text version" \
  --body-html "<h1>Hello</h1><p>This is HTML content</p>"
```

### Option 2: File-Based Formatting (Recommended)

**Plain Text from File:**
```bash
python ses_emailer.py \
  --sender sender@example.com \
  --recipients-file recipients.csv \
  --subject "Hello" \
  --body-file email_body.txt
```

**HTML from File:**
```bash
python ses_emailer.py \
  --sender sender@example.com \
  --recipients-file recipients.csv \
  --subject "Hello" \
  --body-file email_body.txt \
  --body-html-file email_body.html
```

## Plain Text Email Formatting

### Best Practices:
- Keep lines to 72-80 characters for readability
- Use blank lines to separate paragraphs
- Use simple formatting:
  - `*` or `-` for bullet points
  - `#` for numbered lists
  - `---` for horizontal rules
- Avoid special characters that might not render correctly
- Always include a signature

### Example Plain Text Email:
```
Hello [Name],

Thank you for your interest in our service.

Here are some key points:
- Feature 1
- Feature 2
- Feature 3

If you have any questions, please don't hesitate to contact us.

Best regards,
Your Name
Your Company
```

## HTML Email Formatting

### Best Practices:
- Always provide a plain text version as well
- Use inline CSS or embedded styles (many email clients strip external stylesheets)
- Keep HTML simple - avoid complex layouts
- Test in multiple email clients
- Use tables for layout (many email clients don't support CSS Grid/Flexbox well)
- Host images online (don't embed them)
- Keep email width to 600px or less
- Use web-safe fonts (Arial, Helvetica, Times New Roman, etc.)

### Basic HTML Email Structure:
```html
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            color: #333;
        }
    </style>
</head>
<body>
    <h1>Hello!</h1>
    <p>Your email content here.</p>
</body>
</html>
```

### HTML Email Template Components:

1. **Header Section:**
```html
<div style="background-color: #4CAF50; color: white; padding: 20px; text-align: center;">
    <h1>Your Company Name</h1>
</div>
```

2. **Content Section:**
```html
<div style="padding: 20px;">
    <h2>Hello!</h2>
    <p>Your main content goes here.</p>
</div>
```

3. **Button/Link:**
```html
<a href="https://example.com" style="display: inline-block; padding: 12px 24px; background-color: #4CAF50; color: white; text-decoration: none; border-radius: 4px;">
    Click Here
</a>
```

4. **Footer:**
```html
<div style="text-align: center; padding: 20px; font-size: 12px; color: #666;">
    <p>© 2024 Your Company. All rights reserved.</p>
</div>
```

## Email Subject Line Best Practices

- Keep it concise (50 characters or less)
- Be specific and descriptive
- Avoid spam trigger words (FREE, URGENT, etc.)
- Personalize when possible
- Test different subject lines for better open rates

Examples:
- ✅ Good: "Your order confirmation #12345"
- ✅ Good: "Welcome to our newsletter!"
- ❌ Bad: "FREE!!! URGENT!!! CLICK NOW!!!"
- ❌ Bad: "Re:"

## Personalization

While the current script doesn't support template variables, you can:

1. **Create separate email files** for different recipient types
2. **Use a script** to generate personalized emails:
```python
# Example: Generate personalized emails
recipients = [
    {"email": "john@example.com", "name": "John"},
    {"email": "jane@example.com", "name": "Jane"}
]

for recipient in recipients:
    body = f"Hello {recipient['name']},\n\nYour personalized message here."
    # Send email...
```

## Testing Your Email Format

Before sending to all recipients:
1. Send a test email to yourself
2. Check it in multiple email clients (Gmail, Outlook, Apple Mail)
3. Verify both plain text and HTML versions render correctly
4. Check on mobile devices
5. Test all links and buttons

## Common Email Formatting Issues

1. **Images not showing**: Host images online and use absolute URLs
2. **Styles not working**: Use inline styles instead of external stylesheets
3. **Layout broken**: Use tables for layout, not CSS Grid/Flexbox
4. **Fonts not loading**: Use web-safe fonts as fallbacks
5. **Links not working**: Always use full URLs (https://example.com)

## Example Files

The repository includes example templates:
- `email_body_example.txt` - Plain text example
- `email_body_example.html` - Full-featured HTML example
- `email_template_simple.html` - Simple HTML template

You can use these as starting points for your own emails.

