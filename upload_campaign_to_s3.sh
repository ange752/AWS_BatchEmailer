#!/bin/bash
# Universal campaign upload: upload recipients + template (.txt and optional .html) to S3 for EC2.
# Usage: ./upload_campaign_to_s3.sh <campaign_name>
# Example: ./upload_campaign_to_s3.sh Howie_Order
#
# Expects in current directory:
#   {campaign_name}_recipients.csv  -> s3 recipients/
#   {campaign_name}.txt or {campaign_name}_Copy.txt  -> s3 templates/{campaign_name}.txt
#   {campaign_name}.html (optional) -> s3 templates/{campaign_name}.html

set -e

NAME="${1:?Usage: $0 <campaign_name>   Example: $0 Howie_Order}"
BUCKET="${BUCKET:-amaze-aws-emailer}"
REGION="${REGION:-us-west-2}"

RECIPIENTS="${NAME}_recipients.csv"
TXT_S3="${NAME}.txt"
HTML_S3="${NAME}.html"

echo "Uploading campaign: $NAME"
echo "Bucket: s3://$BUCKET"
echo ""

UPLOADED=0

# Recipients
if [ -f "$RECIPIENTS" ]; then
  echo "1. Recipients: $RECIPIENTS -> recipients/"
  aws s3 cp "$RECIPIENTS" "s3://$BUCKET/recipients/$RECIPIENTS" --region "$REGION" || exit 1
  echo "   Done."
  UPLOADED=1
else
  echo "1. Skip (file not found: $RECIPIENTS)"
fi
echo ""

# Template .txt (accept {NAME}.txt or {NAME}_Copy.txt)
TXT_LOCAL=""
[ -f "${NAME}.txt" ] && TXT_LOCAL="${NAME}.txt"
[ -z "$TXT_LOCAL" ] && [ -f "${NAME}_Copy.txt" ] && TXT_LOCAL="${NAME}_Copy.txt"

if [ -n "$TXT_LOCAL" ]; then
  echo "2. Template text: $TXT_LOCAL -> templates/$TXT_S3"
  aws s3 cp "$TXT_LOCAL" "s3://$BUCKET/templates/$TXT_S3" --region "$REGION" || exit 1
  echo "   Done."
  UPLOADED=1
else
  echo "2. Skip (file not found: ${NAME}.txt or ${NAME}_Copy.txt)"
fi
echo ""

# Template .html (optional)
if [ -f "$HTML_S3" ]; then
  echo "3. Template HTML: $HTML_S3 -> templates/"
  aws s3 cp "$HTML_S3" "s3://$BUCKET/templates/$HTML_S3" --region "$REGION" || exit 1
  echo "   Done."
  UPLOADED=1
else
  echo "3. Skip (file not found: $HTML_S3)"
fi
echo ""

if [ "$UPLOADED" -eq 0 ]; then
  echo "No files uploaded. Expected one or more of:"
  echo "  $RECIPIENTS"
  echo "  ${NAME}.txt or ${NAME}_Copy.txt"
  echo "  $HTML_S3"
  exit 1
fi

echo "All set. On EC2, run:"
echo ""
echo "  # Dry run (preview only):"
echo "  ./ec2_send_custom.sh --preview $RECIPIENTS $NAME \"<subject>\" <sender_email> \"<sender_name>\""
echo ""
echo "  # Send for real:"
echo "  ./ec2_send_custom.sh $RECIPIENTS $NAME \"<subject>\" <sender_email> \"<sender_name>\""
echo ""
