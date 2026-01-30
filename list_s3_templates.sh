#!/bin/bash
# List Templates and Recipients in S3
# This script shows what templates and recipient lists are available in S3

set -e

BUCKET="${BUCKET:-amaze-aws-emailer}"
REGION="${REGION:-us-west-2}"

echo "📋 Listing S3 Bucket Contents"
echo "=============================="
echo ""
echo "Bucket: s3://$BUCKET"
echo "Region: $REGION"
echo ""

# List templates
echo "📧 Email Templates in S3:"
echo "-------------------------"
if aws s3 ls "s3://$BUCKET/templates/" --region "$REGION" 2>/dev/null | grep -E "\.(txt|html)$"; then
    echo ""
    echo "Templates found (shown above)"
else
    echo "   ⚠️  No templates found or error accessing S3"
    echo ""
fi

echo ""

# List templates with details
echo "📧 Template Files (Detailed):"
echo "------------------------------"
aws s3 ls "s3://$BUCKET/templates/" --recursive --region "$REGION" 2>/dev/null | \
    grep -E "\.(txt|html)$" | \
    awk '{printf "   %-50s %10s  %s\n", $4, $3, $1" "$2}' || echo "   ⚠️  Could not list templates"
echo ""

# Group templates by base name (without extension)
echo "📋 Template Sets (Base Names):"
echo "-------------------------------"
aws s3 ls "s3://$BUCKET/templates/" --region "$REGION" 2>/dev/null | \
    grep -E "\.(txt|html)$" | \
    awk '{print $4}' | \
    sed 's/\.\(txt\|html\)$//' | \
    sort -u | \
    while read template_base; do
        # Check if both .txt and .html exist
        txt_exists=$(aws s3 ls "s3://$BUCKET/templates/${template_base}.txt" --region "$REGION" 2>/dev/null | wc -l | tr -d ' ')
        html_exists=$(aws s3 ls "s3://$BUCKET/templates/${template_base}.html" --region "$REGION" 2>/dev/null | wc -l | tr -d ' ')
        
        if [ "$txt_exists" -gt 0 ] && [ "$html_exists" -gt 0 ]; then
            echo "   ✅ $template_base (both .txt and .html)"
        elif [ "$txt_exists" -gt 0 ]; then
            echo "   ⚠️  $template_base (only .txt)"
        elif [ "$html_exists" -gt 0 ]; then
            echo "   ⚠️  $template_base (only .html)"
        fi
    done || echo "   ⚠️  Could not process templates"
echo ""

# List recipients
echo "📬 Recipient Lists in S3:"
echo "-------------------------"
aws s3 ls "s3://$BUCKET/recipients/" --region "$REGION" 2>/dev/null | \
    grep "\.csv$" | \
    awk '{printf "   %-40s %10s  %s\n", $4, $3, $1" "$2}' || echo "   ⚠️  No recipient lists found"
echo ""

# Summary
echo "📊 Summary:"
echo "-----------"
TEMPLATE_COUNT=$(aws s3 ls "s3://$BUCKET/templates/" --region "$REGION" 2>/dev/null | grep -E "\.(txt|html)$" | wc -l | tr -d ' ')
RECIPIENT_COUNT=$(aws s3 ls "s3://$BUCKET/recipients/" --region "$REGION" 2>/dev/null | grep "\.csv$" | wc -l | tr -d ' ')

echo "   Templates: $TEMPLATE_COUNT files"
echo "   Recipient Lists: $RECIPIENT_COUNT files"
echo ""

# Usage examples
echo "💡 Usage Examples:"
echo "------------------"
echo "   Use a template on EC2:"
echo "   ./ec2_send_custom.sh recipients_batch_01.csv email_template"
echo ""
echo "   Download a template locally:"
echo "   aws s3 cp s3://$BUCKET/templates/email_template.txt ./email_template.txt --region $REGION"
echo "   aws s3 cp s3://$BUCKET/templates/email_template.html ./email_template.html --region $REGION"
echo ""
