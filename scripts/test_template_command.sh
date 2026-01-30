#!/bin/bash
# Test command for running email_template with test recipients
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

python3 "$SCRIPT_DIR/ses_emailer.py" \
  --sender studio_support@amaze.co \
  --sender-name "Amaze Software" \
  --recipients-file test_recipients.csv \
  --subject "Test Email - Template Test" \
  --body-file email_template.txt \
  --body-html-file email_template.html \
  --preview
