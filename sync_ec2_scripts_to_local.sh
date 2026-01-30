#!/bin/bash
# Sync EC2 Scripts to Local
# Downloads scripts from EC2 instance or S3 to local directory

set -e

# Configuration
EC2_INSTANCE_IP="${EC2_INSTANCE_IP:-54.189.152.124}"
EC2_SSH_KEY="${EC2_SSH_KEY:-$HOME/.ssh/oasis-dev-20220131.pem}"
EC2_USER="${EC2_USER:-ec2-user}"
EC2_SCRIPT_DIR="${EC2_SCRIPT_DIR:-~/emailer}"
REGION="${REGION:-us-west-2}"
S3_BUCKET="${S3_BUCKET:-amaze-aws-emailer}"
S3_SCRIPT_DIR="${S3_SCRIPT_DIR:-scripts}"

# Local directory to save scripts
LOCAL_DIR="$(pwd)"
BACKUP_DIR="${LOCAL_DIR}/ec2_scripts_backup_$(date +%Y%m%d_%H%M%S)"

# Scripts to sync
SCRIPTS=(
    "ses_emailer.py"
    "ec2_send_campaign.sh"
    "ec2_send_custom.sh"
    "ec2_send_all_batches.sh"
    "lambda_handler.py"
)

echo "📥 Syncing EC2 Scripts to Local"
echo "================================"
echo ""
echo "Configuration:"
echo "  EC2 Instance: $EC2_USER@$EC2_INSTANCE_IP"
echo "  EC2 Script Directory: $EC2_SCRIPT_DIR"
echo "  Local Directory: $LOCAL_DIR"
echo "  S3 Bucket: s3://$S3_BUCKET/$S3_SCRIPT_DIR/"
echo ""

# Method selection
echo "Choose download method:"
echo "  1) From S3 (Recommended - faster, no SSH needed)"
echo "  2) From EC2 via SCP (direct from instance)"
echo "  3) Both (S3 first, then EC2 for comparison)"
read -p "Enter choice [1-3] (default: 1): " METHOD
METHOD=${METHOD:-1}

# Create backup directory
mkdir -p "$BACKUP_DIR"
echo "📦 Backing up existing scripts to: $BACKUP_DIR"
for script in "${SCRIPTS[@]}"; do
    if [ -f "$LOCAL_DIR/$script" ]; then
        cp "$LOCAL_DIR/$script" "$BACKUP_DIR/$script.bak" 2>/dev/null || true
    fi
done
echo ""

# Method 1: Download from S3
if [[ "$METHOD" == "1" ]] || [[ "$METHOD" == "3" ]]; then
    echo "📥 Downloading from S3..."
    echo "---------------------------"
    
    for script in "${SCRIPTS[@]}"; do
        S3_PATH="s3://$S3_BUCKET/$S3_SCRIPT_DIR/$script"
        if aws s3 cp "$S3_PATH" "$LOCAL_DIR/$script" --region "$REGION" 2>/dev/null; then
            echo "  ✅ Downloaded $script from S3"
            # Make executable if it's a script
            if [[ "$script" == *.sh ]]; then
                chmod +x "$LOCAL_DIR/$script"
            fi
        else
            echo "  ⚠️  $script not found in S3"
        fi
    done
    echo ""
fi

# Method 2: Download from EC2 via SCP
if [[ "$METHOD" == "2" ]] || [[ "$METHOD" == "3" ]]; then
    echo "📥 Downloading from EC2 instance..."
    echo "------------------------------------"
    
    # Find SSH key if not found
    if [ ! -f "$EC2_SSH_KEY" ]; then
        DEFAULT_KEY=$(ls -1t ~/.ssh/oasis-dev*.pem 2>/dev/null | head -1)
        if [ -n "$DEFAULT_KEY" ]; then
            EC2_SSH_KEY="$DEFAULT_KEY"
            echo "Using SSH key: $EC2_SSH_KEY"
        else
            echo "⚠️  SSH key not found: $EC2_SSH_KEY"
            read -p "Enter path to SSH key (or press Enter to skip EC2 download): " SSH_KEY_PATH
            if [ -z "$SSH_KEY_PATH" ] || [ ! -f "$SSH_KEY_PATH" ]; then
                echo "⚠️  Skipping EC2 download"
                USE_SSH=false
            else
                EC2_SSH_KEY="$SSH_KEY_PATH"
                USE_SSH=true
            fi
        fi
    else
        USE_SSH=true
    fi
    
    if [ "$USE_SSH" = true ]; then
        # Test SSH connection
        if ! ssh -i "$EC2_SSH_KEY" -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$EC2_USER@$EC2_INSTANCE_IP" "echo 'Connected'" &>/dev/null; then
            echo "❌ Cannot connect to EC2 instance. Please check:"
            echo "   - Instance is running"
            echo "   - SSH key is correct"
            echo "   - Security group allows SSH"
            echo ""
            if [[ "$METHOD" == "2" ]]; then
                exit 1
            else
                echo "⚠️  Continuing with S3 files only..."
            fi
        else
            # Download scripts from EC2
            for script in "${SCRIPTS[@]}"; do
                EC2_PATH="$EC2_USER@$EC2_INSTANCE_IP:$EC2_SCRIPT_DIR/$script"
                if scp -i "$EC2_SSH_KEY" -o StrictHostKeyChecking=no "$EC2_PATH" "$LOCAL_DIR/${script}.ec2" 2>/dev/null; then
                    echo "  ✅ Downloaded $script from EC2"
                    # Make executable if it's a script
                    if [[ "$script" == *.sh ]]; then
                        chmod +x "$LOCAL_DIR/${script}.ec2"
                    fi
                else
                    echo "  ⚠️  $script not found on EC2"
                fi
            done
        fi
    fi
    echo ""
fi

# Summary
echo "✅ Download complete!"
echo ""
echo "📋 Downloaded files:"
for script in "${SCRIPTS[@]}"; do
    if [ -f "$LOCAL_DIR/$script" ]; then
        SIZE=$(du -h "$LOCAL_DIR/$script" | cut -f1)
        echo "  ✅ $script ($SIZE)"
    fi
    if [ -f "$LOCAL_DIR/${script}.ec2" ]; then
        SIZE=$(du -h "$LOCAL_DIR/${script}.ec2" | cut -f1)
        echo "  ✅ ${script}.ec2 ($SIZE) [from EC2]"
    fi
done
echo ""

# Compare if both methods were used
if [[ "$METHOD" == "3" ]]; then
    echo "🔍 Comparing S3 vs EC2 versions..."
    for script in "${SCRIPTS[@]}"; do
        if [ -f "$LOCAL_DIR/$script" ] && [ -f "$LOCAL_DIR/${script}.ec2" ]; then
            if diff -q "$LOCAL_DIR/$script" "$LOCAL_DIR/${script}.ec2" >/dev/null 2>&1; then
                echo "  ✅ $script: S3 and EC2 versions match"
            else
                echo "  ⚠️  $script: S3 and EC2 versions differ"
                echo "     Run: diff $script ${script}.ec2"
            fi
        fi
    done
    echo ""
fi

echo "📦 Backup saved to: $BACKUP_DIR"
echo ""
echo "💡 Next steps:"
echo "   - Review downloaded scripts"
if [[ "$METHOD" == "3" ]]; then
    echo "   - Compare S3 vs EC2 versions if they differ"
fi
echo "   - Use compare_ec2_scripts.sh to see differences"
