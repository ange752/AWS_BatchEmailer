#!/bin/bash
# Replace Local Scripts with EC2 Scripts from S3
# Downloads scripts from S3 and replaces local versions

set -e

# Configuration
REGION="${REGION:-us-west-2}"
S3_BUCKET="${S3_BUCKET:-amaze-aws-emailer}"
S3_SCRIPT_DIR="${S3_SCRIPT_DIR:-scripts}"

# Local directory
LOCAL_DIR="$(pwd)"
BACKUP_DIR="${LOCAL_DIR}/local_scripts_backup_$(date +%Y%m%d_%H%M%S)"

# Scripts to replace
SCRIPTS=(
    "ses_emailer.py"
    "ec2_send_campaign.sh"
    "ec2_send_custom.sh"
    "ec2_send_all_batches.sh"
    "lambda_handler.py"
)

echo "🔄 Replacing Local Scripts with EC2 Scripts"
echo "==========================================="
echo ""
echo "Source: s3://$S3_BUCKET/$S3_SCRIPT_DIR/"
echo "Target: $LOCAL_DIR"
echo ""

# Create backup directory
echo "📦 Creating backup of local scripts..."
mkdir -p "$BACKUP_DIR"
BACKED_UP=0
for script in "${SCRIPTS[@]}"; do
    if [ -f "$LOCAL_DIR/$script" ]; then
        cp "$LOCAL_DIR/$script" "$BACKUP_DIR/$script" 2>/dev/null || true
        BACKED_UP=$((BACKED_UP + 1))
    fi
done
if [ $BACKED_UP -gt 0 ]; then
    echo "  ✅ Backed up $BACKED_UP local script(s) to: $BACKUP_DIR"
else
    echo "  ℹ️  No local scripts to backup"
fi
echo ""

# Confirm replacement
echo "📋 Scripts to download and replace:"
for script in "${SCRIPTS[@]}"; do
    if [ -f "$LOCAL_DIR/$script" ]; then
        SIZE=$(du -h "$LOCAL_DIR/$script" | cut -f1)
        echo "  ⚠️  $script ($SIZE) - will be replaced"
    else
        echo "  ➕ $script - will be downloaded"
    fi
done
echo ""

read -p "Replace local scripts with EC2 versions from S3? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Cancelled"
    exit 0
fi

# Download and replace scripts
echo ""
echo "📥 Downloading from S3..."
echo "---------------------------"

SUCCESS=0
FAILED=0

for script in "${SCRIPTS[@]}"; do
    S3_PATH="s3://$S3_BUCKET/$S3_SCRIPT_DIR/$script"
    if aws s3 cp "$S3_PATH" "$LOCAL_DIR/$script" --region "$REGION" 2>/dev/null; then
        echo "  ✅ Downloaded and replaced $script"
        # Make executable if it's a script
        if [[ "$script" == *.sh ]]; then
            chmod +x "$LOCAL_DIR/$script"
        fi
        SUCCESS=$((SUCCESS + 1))
    else
        echo "  ❌ Failed to download $script from S3"
        FAILED=$((FAILED + 1))
    fi
done

echo ""
echo "✅ Replacement complete!"
echo ""
echo "📊 Summary:"
echo "  ✅ Successfully replaced: $SUCCESS script(s)"
if [ $FAILED -gt 0 ]; then
    echo "  ❌ Failed to download: $FAILED script(s)"
fi
echo "  📦 Backup saved to: $BACKUP_DIR"
echo ""

# Show what was replaced
if [ $SUCCESS -gt 0 ]; then
    echo "📋 Replaced files:"
    for script in "${SCRIPTS[@]}"; do
        if [ -f "$LOCAL_DIR/$script" ]; then
            SIZE=$(du -h "$LOCAL_DIR/$script" | cut -f1)
            MTIME=$(stat -f "%Sm" "$LOCAL_DIR/$script" 2>/dev/null || stat -c "%y" "$LOCAL_DIR/$script" 2>/dev/null | cut -d' ' -f1)
            echo "  ✅ $script ($SIZE, modified: $MTIME)"
        fi
    done
    echo ""
fi

echo "💡 To restore local scripts:"
echo "   cp $BACKUP_DIR/* ."
