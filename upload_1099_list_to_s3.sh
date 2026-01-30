#!/bin/bash
# Upload 1099_List3_2026_emails_only.csv to S3

BUCKET="amaze-aws-emailer"
REGION="us-west-2"
FILE="1099_List3_2026_emails_only.csv"

echo "📤 Uploading $FILE to S3"
echo "========================"
echo ""

# Check if file exists
if [ ! -f "$FILE" ]; then
    echo "❌ File not found: $FILE"
    echo "   Run: ./extract_emails.sh 1099_List3_2026.csv first"
    exit 1
fi

echo "File: $FILE"
echo "Size: $(du -h "$FILE" | cut -f1)"
echo "Recipients: $(tail -n +2 "$FILE" | wc -l | tr -d ' ')"
echo ""

# Upload to S3
echo "Uploading to: s3://$BUCKET/recipients/$FILE"
if aws s3 cp "$FILE" "s3://$BUCKET/recipients/$FILE" --region "$REGION"; then
    echo ""
    echo "✅ Upload successful!"
    echo ""
    echo "💡 Usage on EC2:"
    echo "   ./ec2_send_custom.sh $FILE 1099_TAX_EMAIL3 \"Subject\" sender@example.com \"Name\""
    echo ""
    echo "   Or with preview:"
    echo "   ./ec2_send_custom.sh --preview $FILE 1099_TAX_EMAIL3 \"Subject\" sender@example.com \"Name\""
else
    echo ""
    echo "❌ Upload failed"
    exit 1
fi
