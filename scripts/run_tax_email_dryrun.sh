#!/bin/bash
# Dry run command for Tax Email List with 1099_Tax_Reminder template
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

python3 "$SCRIPT_DIR/ses_emailer.py" \
  --sender creatorhelp@amaze.co \
  --sender-name "Creator Help" \
  --recipients-file TaxEmailList_1.csv \
  --subject "Action Required: Verify Your Tax Details on Spring" \
  --body-file 1099_Tax_Reminder.txt \
  --body-html-file 1099_Tax_Reminder.html \
  --preview
