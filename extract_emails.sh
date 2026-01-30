#!/bin/bash
# Extract just the email column from 1099_List3_2026.csv

INPUT_FILE="${1:-1099_List3_2026.csv}"
OUTPUT_FILE="${2:-1099_List3_2026_emails_only.csv}"

echo "📧 Extracting emails from $INPUT_FILE"
echo ""

# Extract EMAIL column (column 2) and add header
awk -F',' 'NR==1 {print "email"} NR>1 && $2 {print $2}' "$INPUT_FILE" > "$OUTPUT_FILE"

# Count emails
EMAIL_COUNT=$(tail -n +2 "$OUTPUT_FILE" | wc -l | tr -d ' ')
echo "✅ Extracted $EMAIL_COUNT emails to $OUTPUT_FILE"
echo ""
echo "First 5 emails:"
head -6 "$OUTPUT_FILE"
echo ""
