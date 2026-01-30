#!/bin/bash
# Test command for running email_template with test recipients

python3 ses_emailer.py \
  --sender studio_support@amaze.co \
  --sender-name "Amaze Software" \
  --recipients-file test_recipients.csv \
  --subject "Test Email - Template Test" \
  --body-file email_template.txt \
  --body-html-file email_template.html \
  --preview
