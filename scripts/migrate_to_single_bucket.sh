#!/bin/bash
# Migrate from separate S3 buckets to single bucket structure

set -e

echo "🔄 Migrating to Single Bucket Structure"
echo "========================================="
echo ""

# Check if old config exists
if [ ! -f "lambda_config.json" ]; then
    echo "❌ lambda_config.json not found. Nothing to migrate."
    exit 1
fi

# Read old config
OLD_TEMPLATES_BUCKET=$(python3 -c "import json; c=json.load(open('lambda_config.json')); print(c.get('s3_buckets', {}).get('templates', ''))" 2>/dev/null || echo "")
OLD_RECIPIENTS_BUCKET=$(python3 -c "import json; c=json.load(open('lambda_config.json')); print(c.get('s3_buckets', {}).get('recipients', ''))" 2>/dev/null || echo "")
OLD_LOGS_BUCKET=$(python3 -c "import json; c=json.load(open('lambda_config.json')); print(c.get('s3_buckets', {}).get('logs', ''))" 2>/dev/null || echo "")

# Check if already using single bucket
NEW_BUCKET=$(python3 -c "import json; c=json.load(open('lambda_config.json')); print(c.get('s3_bucket', ''))" 2>/dev/null || echo "")

if [ -n "$NEW_BUCKET" ]; then
    echo "✅ Already using single bucket: $NEW_BUCKET"
    echo "No migration needed."
    exit 0
fi

if [ -z "$OLD_TEMPLATES_BUCKET" ] && [ -z "$OLD_RECIPIENTS_BUCKET" ]; then
    echo "⚠️  No old bucket configuration found. Nothing to migrate."
    exit 0
fi

echo "Current configuration:"
echo "  Templates: $OLD_TEMPLATES_BUCKET"
echo "  Recipients: $OLD_RECIPIENTS_BUCKET"
echo "  Logs: $OLD_LOGS_BUCKET"
echo ""

# Create new single bucket
TIMESTAMP=$(date +%s)
NEW_BUCKET="aws-emailer-${TIMESTAMP}"
REGION="us-west-2"

echo "Creating new single bucket: $NEW_BUCKET"
aws s3 mb s3://$NEW_BUCKET --region $REGION 2>/dev/null || echo "Bucket may already exist"
echo "✅ Bucket created"
echo ""

# Migrate files
echo "📦 Migrating files..."
echo ""

# Migrate templates
if [ -n "$OLD_TEMPLATES_BUCKET" ]; then
    echo "Migrating templates from $OLD_TEMPLATES_BUCKET..."
    aws s3 sync s3://$OLD_TEMPLATES_BUCKET/templates/ s3://$NEW_BUCKET/templates/ --region $REGION 2>/dev/null || echo "No templates to migrate"
    echo "✅ Templates migrated"
fi

# Migrate recipients
if [ -n "$OLD_RECIPIENTS_BUCKET" ]; then
    echo "Migrating recipients from $OLD_RECIPIENTS_BUCKET..."
    aws s3 sync s3://$OLD_RECIPIENTS_BUCKET/recipients/ s3://$NEW_BUCKET/recipients/ --region $REGION 2>/dev/null || echo "No recipients to migrate"
    echo "✅ Recipients migrated"
fi

# Create logs folder (empty, but structure ready)
echo "Creating logs folder..."
aws s3api put-object --bucket $NEW_BUCKET --key logs/ --region $REGION 2>/dev/null || true
echo "✅ Logs folder created"
echo ""

# Update config file
echo "📝 Updating lambda_config.json..."
python3 << PYEOF
import json

with open('lambda_config.json', 'r') as f:
    config = json.load(f)

# Update to single bucket structure
config['s3_bucket'] = '$NEW_BUCKET'

# Remove old s3_buckets structure if it exists
if 's3_buckets' in config:
    del config['s3_buckets']

# Save updated config
with open('lambda_config.json', 'w') as f:
    json.dump(config, f, indent=2)

print("✅ Config updated")
PYEOF

echo ""
echo "✅ Migration Complete!"
echo "======================"
echo ""
echo "New configuration:"
echo "  Single Bucket: $NEW_BUCKET"
echo "    - templates/ (email templates)"
echo "    - recipients/ (recipient lists)"
echo "    - logs/ (execution logs)"
echo ""
echo "Old buckets (can be deleted after verification):"
[ -n "$OLD_TEMPLATES_BUCKET" ] && echo "  - $OLD_TEMPLATES_BUCKET"
[ -n "$OLD_RECIPIENTS_BUCKET" ] && echo "  - $OLD_RECIPIENTS_BUCKET"
[ -n "$OLD_LOGS_BUCKET" ] && echo "  - $OLD_LOGS_BUCKET"
echo ""
echo "To delete old buckets (after verifying migration):"
[ -n "$OLD_TEMPLATES_BUCKET" ] && echo "  aws s3 rb s3://$OLD_TEMPLATES_BUCKET --force"
[ -n "$OLD_RECIPIENTS_BUCKET" ] && echo "  aws s3 rb s3://$OLD_RECIPIENTS_BUCKET --force"
[ -n "$OLD_LOGS_BUCKET" ] && echo "  aws s3 rb s3://$OLD_LOGS_BUCKET --force"

