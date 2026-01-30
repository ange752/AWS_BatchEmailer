#!/bin/bash
# EC2 Custom Email Campaign Sender
# Allows specifying template, recipient list, subject, sender, and UTM parameters
# Usage: ./ec2_send_custom.sh <recipient_list> [template_name] [subject] [sender_email] [sender_name] [utm_source] [utm_medium] [utm_campaign]

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Configuration
BUCKET="amaze-aws-emailer"
REGION="us-west-2"
DEFAULT_SENDER="studio_support@amaze.co"
DEFAULT_SENDER_NAME="Amaze Software"
DEFAULT_SUBJECT="Important update: Amaze Studio will shut down December 15th, 2025"

# Check for --preview flag
PREVIEW_MODE=false
if [[ "$1" == "--preview" ]] || [[ "$1" == "-p" ]]; then
    PREVIEW_MODE=true
    shift  # Remove --preview from arguments
fi

# Get parameters
if [ -z "$1" ]; then
    echo "Usage: $0 [--preview] <recipient_list> [template_name] [subject] [sender_email] [sender_name] [utm_source] [utm_medium] [utm_campaign]"
    echo ""
    echo "Options:"
    echo "  --preview, -p    Preview mode (dry run - does not send emails)"
    echo ""
    echo "Examples:"
    echo "  $0 recipients_batch_01.csv"
    echo "  $0 --preview recipients_batch_01.csv email_template"
    echo "  $0 recipients_batch_01.csv email_template \"Custom Subject\""
    echo "  $0 recipients_batch_01.csv email_template \"Custom Subject\" support@example.com"
    echo "  $0 recipients_batch_01.csv email_template \"Custom Subject\" support@example.com \"Company Name\""
    echo "  $0 recipients_batch_01.csv email_template \"Subject\" support@example.com \"Company\" email newsletter blackfriday2025"
    echo ""
    echo "UTM Parameters (optional):"
    echo "  utm_source: Source of traffic (e.g., 'email', 'newsletter')"
    echo "  utm_medium: Medium (e.g., 'email', 'cpc')"
    echo "  utm_campaign: Campaign name (e.g., 'blackfriday2025')"
    echo ""
    echo "Available templates in S3:"
    aws s3 ls s3://$BUCKET/templates/ --region $REGION | grep -E "\.(txt|html)$" | awk '{print "  " $4}' | sort -u
    echo ""
    echo "Available recipient lists in S3:"
    aws s3 ls s3://$BUCKET/recipients/ --region $REGION | grep "\.csv$" | awk '{print "  " $4}'
    exit 1
fi

RECIPIENT_LIST="$1"
TEMPLATE_NAME=${2:-email_template}
SUBJECT=${3:-$DEFAULT_SUBJECT}
SENDER=${4:-$DEFAULT_SENDER}
SENDER_NAME=${5:-$DEFAULT_SENDER_NAME}
UTM_SOURCE=${6:-}
UTM_MEDIUM=${7:-}
UTM_CAMPAIGN=${8:-}

echo "📧 Custom Email Campaign"
echo "========================"
echo ""
echo "Configuration:"
echo "  Bucket: $BUCKET"
echo "  Region: $REGION"
echo "  Sender: $SENDER_NAME <$SENDER>"
echo "  Template: $TEMPLATE_NAME"
echo "  Recipient List: $RECIPIENT_LIST"
echo "  Subject: $SUBJECT"
if [ -n "$UTM_SOURCE" ] || [ -n "$UTM_MEDIUM" ] || [ -n "$UTM_CAMPAIGN" ]; then
    echo "  UTM Parameters:"
    [ -n "$UTM_SOURCE" ] && echo "    Source: $UTM_SOURCE"
    [ -n "$UTM_MEDIUM" ] && echo "    Medium: $UTM_MEDIUM"
    [ -n "$UTM_CAMPAIGN" ] && echo "    Campaign: $UTM_CAMPAIGN"
fi
echo ""

# Download files from S3
echo "📥 Downloading files from S3..."
# Remove old files first to ensure fresh download
rm -f /tmp/recipients.csv /tmp/email_template.txt /tmp/email_template.html
# Download with no-cache to ensure latest version
aws s3 cp s3://$BUCKET/recipients/$RECIPIENT_LIST /tmp/recipients.csv --region $REGION --cache-control "no-cache"
aws s3 cp s3://$BUCKET/templates/${TEMPLATE_NAME}.txt /tmp/email_template.txt --region $REGION --cache-control "no-cache"
aws s3 cp s3://$BUCKET/templates/${TEMPLATE_NAME}.html /tmp/email_template.html --region $REGION --cache-control "no-cache"

# Add UTM parameters to HTML if provided
if [ -n "$UTM_SOURCE" ] || [ -n "$UTM_MEDIUM" ] || [ -n "$UTM_CAMPAIGN" ]; then
    echo "🔗 Adding UTM parameters to links..."
    
    # Build UTM query string
    UTM_PARAMS=""
    [ -n "$UTM_SOURCE" ] && UTM_PARAMS="${UTM_PARAMS}utm_source=${UTM_SOURCE}&"
    [ -n "$UTM_MEDIUM" ] && UTM_PARAMS="${UTM_PARAMS}utm_medium=${UTM_MEDIUM}&"
    [ -n "$UTM_CAMPAIGN" ] && UTM_PARAMS="${UTM_PARAMS}utm_campaign=${UTM_CAMPAIGN}&"
    UTM_PARAMS=$(echo "$UTM_PARAMS" | sed 's/&$//')  # Remove trailing &
    
    # Add UTM parameters to all href links in HTML
    # This handles links like: href="https://example.com" or href='https://example.com'
    # It appends UTM params, handling existing query strings
    if [ -n "$UTM_PARAMS" ]; then
        # Use Python to properly handle URL modification
        python3 << PYEOF
import re
import sys

# Read HTML file
with open('/tmp/email_template.html', 'r', encoding='utf-8') as f:
    html_content = f.read()

# Pattern to match href attributes with URLs
def add_utm_to_url(match):
    url = match.group(1)
    quote = match.group(2)
    
    # Skip if already has UTM or is mailto/tel/anchor
    if 'utm_' in url or url.startswith('mailto:') or url.startswith('tel:') or url.startswith('#'):
        return match.group(0)
    
    # Determine separator
    separator = '&' if '?' in url else '?'
    
    # Add UTM parameters
    new_url = f"{url}{separator}${UTM_PARAMS}"
    
    return f'href={quote}{new_url}{quote}'

# Replace href attributes
html_content = re.sub(
    r'href=(["\'])(https?://[^"\']+)\1',
    add_utm_to_url,
    html_content,
    flags=re.IGNORECASE
)

# Write back
with open('/tmp/email_template.html', 'w', encoding='utf-8') as f:
    f.write(html_content)

PYEOF
        
        echo "✅ UTM parameters added: $UTM_PARAMS"
    fi
fi

# Verify files
if [ ! -f /tmp/recipients.csv ]; then
    echo "❌ Error: Could not download recipients.csv"
    exit 1
fi

# Count recipients
RECIPIENT_COUNT=$(tail -n +2 /tmp/recipients.csv 2>/dev/null | wc -l | tr -d ' ')
echo "✅ Found $RECIPIENT_COUNT recipients"
echo ""

# Send emails or preview
if [ "$PREVIEW_MODE" = true ]; then
    echo "🔍 PREVIEW MODE (Dry Run - No emails will be sent)"
    echo "=================================================="
    echo ""
    
    python3 "$SCRIPT_DIR/ses_emailer.py" \
      --sender "$SENDER" \
      --sender-name "$SENDER_NAME" \
      --recipients-file /tmp/recipients.csv \
      --subject "$SUBJECT" \
      --body-file /tmp/email_template.txt \
      --body-html-file /tmp/email_template.html \
      --region $REGION \
      --preview
    
    echo ""
    echo "✅ Preview complete! No emails were sent."
    echo "📊 Remove --preview flag to actually send emails"
else
    echo "🚀 Sending emails..."
    echo "This may take 10-15 minutes for large batches..."
    echo ""
    
    python3 "$SCRIPT_DIR/ses_emailer.py" \
      --sender "$SENDER" \
      --sender-name "$SENDER_NAME" \
      --recipients-file /tmp/recipients.csv \
      --subject "$SUBJECT" \
      --body-file /tmp/email_template.txt \
      --body-html-file /tmp/email_template.html \
      --region $REGION \
      --batch-size 50 \
      --use-bcc \
      --rate-limit 0.1
    
    echo ""
    echo "✅ Campaign complete!"
    echo "📊 Check logs above for details"
fi

