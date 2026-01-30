#!/bin/bash
# Upload test_recipients.csv to EC2
# This script uploads the file to S3 (recommended) and optionally to EC2 directly

set -e

FILE="${1:-test_recipients.csv}"
EC2_INSTANCE_IP="${EC2_INSTANCE_IP:-54.189.152.124}"
EC2_SSH_KEY="${EC2_SSH_KEY:-$HOME/.ssh/oasis-dev-20200312.pem}"
EC2_USER="${EC2_USER:-ec2-user}"
EC2_SCRIPT_DIR="${EC2_SCRIPT_DIR:-~/emailer}"
BUCKET="${BUCKET:-amaze-aws-emailer}"
REGION="${REGION:-us-west-2}"

echo "📤 Uploading $FILE to EC2"
echo "=========================="
echo ""

# Check if file exists
if [ ! -f "$FILE" ]; then
    echo "❌ File not found: $FILE"
    exit 1
fi

echo "File: $FILE"
echo "Size: $(du -h "$FILE" | cut -f1)"
echo ""

# Option 1: Upload to S3 (Recommended - EC2 scripts use S3)
echo "📤 Option 1: Uploading to S3 (Recommended)"
echo "-------------------------------------------"
echo "Uploading to: s3://$BUCKET/recipients/$(basename $FILE)"
if aws s3 cp "$FILE" "s3://$BUCKET/recipients/$(basename $FILE)" --region "$REGION"; then
    echo "✅ Uploaded to S3 successfully!"
    echo ""
    echo "On EC2, you can now use:"
    echo "  ./ec2_send_custom.sh $(basename $FILE) email_template"
else
    echo "❌ Failed to upload to S3"
    exit 1
fi
echo ""

# Option 2: Upload directly to EC2 via SCP (Optional)
read -p "Also upload directly to EC2 instance? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "📤 Option 2: Uploading directly to EC2"
    echo "---------------------------------------"
    
    # Find SSH key if not found
    if [ ! -f "$EC2_SSH_KEY" ]; then
        DEFAULT_KEY=$(ls -1t ~/.ssh/oasis-dev*.pem 2>/dev/null | head -1)
        if [ -n "$DEFAULT_KEY" ]; then
            EC2_SSH_KEY="$DEFAULT_KEY"
            echo "Using SSH key: $EC2_SSH_KEY"
        else
            echo "❌ SSH key not found: $EC2_SSH_KEY"
            echo "Please specify path to SSH key:"
            read -p "SSH key path: " EC2_SSH_KEY
            if [ ! -f "$EC2_SSH_KEY" ]; then
                echo "❌ SSH key not found: $EC2_SSH_KEY"
                exit 1
            fi
        fi
    fi
    
    echo "Uploading to: $EC2_USER@$EC2_INSTANCE_IP:$EC2_SCRIPT_DIR/"
    
    # Create directory on EC2 if it doesn't exist
    ssh -i "$EC2_SSH_KEY" -o StrictHostKeyChecking=no "$EC2_USER@$EC2_INSTANCE_IP" \
        "mkdir -p $EC2_SCRIPT_DIR" 2>/dev/null || true
    
    # Upload file
    if scp -i "$EC2_SSH_KEY" -o StrictHostKeyChecking=no "$FILE" "$EC2_USER@$EC2_INSTANCE_IP:$EC2_SCRIPT_DIR/"; then
        echo "✅ Uploaded directly to EC2 successfully!"
        echo ""
        echo "On EC2, file is at: $EC2_SCRIPT_DIR/$(basename $FILE)"
    else
        echo "❌ Failed to upload to EC2"
        echo "   (S3 upload succeeded, so you can still use it from S3)"
    fi
fi

echo ""
echo "✅ Upload complete!"
echo ""
echo "💡 Usage on EC2:"
echo "   # From S3 (recommended):"
echo "   ./ec2_send_custom.sh $(basename $FILE) email_template"
echo ""
echo "   # Or download from S3 first:"
echo "   aws s3 cp s3://$BUCKET/recipients/$(basename $FILE) /tmp/recipients.csv --region $REGION"
echo "   python3 ses_emailer.py --recipients-file /tmp/recipients.csv ..."
