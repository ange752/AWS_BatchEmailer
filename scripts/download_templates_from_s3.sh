#!/bin/bash
# Download Templates from S3
# This script downloads all email templates from S3 to your local directory

set -e

BUCKET="${BUCKET:-amaze-aws-emailer}"
REGION="${REGION:-us-west-2}"
DOWNLOAD_DIR="${DOWNLOAD_DIR:-.}"

echo "📥 Downloading Templates from S3"
echo "================================="
echo ""
echo "S3 Bucket: s3://$BUCKET/templates/"
echo "Region: $REGION"
echo "Download to: $DOWNLOAD_DIR"
echo ""

# Check if download directory exists
if [ ! -d "$DOWNLOAD_DIR" ]; then
    echo "Creating download directory: $DOWNLOAD_DIR"
    mkdir -p "$DOWNLOAD_DIR"
fi

# List templates first
echo "📋 Available templates in S3:"
echo "-----------------------------"
TEMPLATES=$(aws s3 ls "s3://$BUCKET/templates/" --region "$REGION" 2>/dev/null | grep -E "\.(txt|html)$" | awk '{print $4}' || echo "")

if [ -z "$TEMPLATES" ]; then
    echo "   ⚠️  No templates found in S3"
    echo "   Or error accessing S3 bucket"
    exit 1
fi

echo "$TEMPLATES" | while read -r template; do
    echo "   - $template"
done
echo ""

# Download templates
echo "📥 Downloading templates..."
echo "---------------------------"

DOWNLOADED=0
FAILED=0

echo "$TEMPLATES" | while read -r template; do
    if [ -z "$template" ]; then
        continue
    fi
    
    echo -n "   Downloading $template... "
    
    if aws s3 cp "s3://$BUCKET/templates/$template" "$DOWNLOAD_DIR/$template" --region "$REGION" 2>/dev/null; then
        echo "✅"
        DOWNLOADED=$((DOWNLOADED + 1))
        
        # Show file size
        if [ -f "$DOWNLOAD_DIR/$template" ]; then
            SIZE=$(du -h "$DOWNLOAD_DIR/$template" | cut -f1)
            echo "      Size: $SIZE"
        fi
    else
        echo "❌ Failed"
        FAILED=$((FAILED + 1))
    fi
done

echo ""
echo "✅ Download Complete!"
echo "   Downloaded: $DOWNLOADED files"
if [ $FAILED -gt 0 ]; then
    echo "   Failed: $FAILED files"
fi
echo ""

# Show downloaded files
if [ $DOWNLOADED -gt 0 ]; then
    echo "📁 Downloaded files:"
    echo "--------------------"
    ls -lh "$DOWNLOAD_DIR"/*.{txt,html} 2>/dev/null | awk '{printf "   %-40s %10s\n", $9, $5}' || echo "   (none)"
    echo ""
    
    # Group by template name
    echo "📋 Template Sets:"
    echo "-----------------"
    cd "$DOWNLOAD_DIR"
    for txt_file in *.txt; do
        if [ -f "$txt_file" ]; then
            base_name="${txt_file%.txt}"
            if [ -f "${base_name}.html" ]; then
                echo "   ✅ $base_name (both .txt and .html)"
            else
                echo "   ⚠️  $base_name (only .txt)"
            fi
        fi
    done
    for html_file in *.html; do
        if [ -f "$html_file" ]; then
            base_name="${html_file%.html}"
            if [ ! -f "${base_name}.txt" ]; then
                echo "   ⚠️  $base_name (only .html)"
            fi
        fi
    done
fi

echo ""
echo "💡 Note: These files have been downloaded to: $DOWNLOAD_DIR"
echo "   Original files (if they exist) have been preserved with .bak extension"
