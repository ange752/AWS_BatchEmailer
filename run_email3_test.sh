#!/bin/bash
# Run EMAIL3 template test with test_recipients.csv

# Template name (adjust if different)
TEMPLATE_NAME="1099_TAX_EMAIL3"

# Check if templates exist locally
if [ ! -f "${TEMPLATE_NAME}.txt" ] || [ ! -f "${TEMPLATE_NAME}.html" ]; then
    echo "⚠️  Templates not found locally. Downloading from S3..."
    echo ""
    
    # Download from S3
    aws s3 cp s3://amaze-aws-emailer/templates/${TEMPLATE_NAME}.txt ./${TEMPLATE_NAME}.txt --region us-west-2
    aws s3 cp s3://amaze-aws-emailer/templates/${TEMPLATE_NAME}.html ./${TEMPLATE_NAME}.html --region us-west-2
    
    if [ ! -f "${TEMPLATE_NAME}.txt" ] || [ ! -f "${TEMPLATE_NAME}.html" ]; then
        echo "❌ Could not download templates from S3"
        echo "   Please check template name or download manually"
        exit 1
    fi
    
    echo "✅ Templates downloaded"
    echo ""
fi

# Run preview (dry run)
echo "🧪 Testing EMAIL3 template with test recipients (PREVIEW MODE)"
echo "=============================================================="
echo ""

python3 ses_emailer.py \
  --sender studio_support@amaze.co \
  --sender-name "Amaze Software" \
  --recipients-file test_recipients.csv \
  --subject "1099 Tax Form Available" \
  --body-file ${TEMPLATE_NAME}.txt \
  --body-html-file ${TEMPLATE_NAME}.html \
  --preview

echo ""
echo "✅ Preview complete!"
echo ""
echo "To actually send (remove --preview):"
echo "python3 ses_emailer.py \\"
echo "  --sender studio_support@amaze.co \\"
echo "  --recipients-file test_recipients.csv \\"
echo "  --subject \"1099 Tax Form Available\" \\"
echo "  --body-file ${TEMPLATE_NAME}.txt \\"
echo "  --body-html-file ${TEMPLATE_NAME}.html"
