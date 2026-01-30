#!/bin/bash
# Sync Local Scripts to EC2 Instance
# This script uploads local scripts to the EC2 instance and S3

set -e

# Configuration - Update these values
EC2_INSTANCE_IP="${EC2_INSTANCE_IP:-54.189.152.124}"
EC2_SSH_KEY="${EC2_SSH_KEY:-$HOME/.ssh/oasis-dev-20220131.pem}"
EC2_USER="${EC2_USER:-ec2-user}"
EC2_SCRIPT_DIR="${EC2_SCRIPT_DIR:-~/emailer}"
REGION="${REGION:-us-west-2}"
S3_BUCKET="${S3_BUCKET:-amaze-aws-emailer}"
S3_SCRIPT_DIR="${S3_SCRIPT_DIR:-scripts}"

# Local script directory
LOCAL_DIR="$(pwd)"

echo "🔄 Syncing Local Scripts to EC2 and S3"
echo "======================================"
echo ""
echo "Configuration:"
echo "  EC2 Instance: $EC2_USER@$EC2_INSTANCE_IP"
echo "  SSH Key: $EC2_SSH_KEY"
echo "  EC2 Script Directory: $EC2_SCRIPT_DIR"
echo "  Local Directory: $LOCAL_DIR"
echo "  S3 Bucket: s3://$S3_BUCKET/$S3_SCRIPT_DIR/"
echo ""

# Check if SSH key exists, try common locations
if [ ! -f "$EC2_SSH_KEY" ]; then
    echo "⚠️  SSH key not found at: $EC2_SSH_KEY"
    echo ""
    echo "Searching common locations..."
    
    # Check common locations (prioritize ~/.ssh)
    COMMON_LOCATIONS=(
        "$HOME/.ssh/oasis-dev-20220131.pem"
        "$HOME/.ssh/$EC2_SSH_KEY"
        "./oasis-dev-20220131.pem"
        "./$EC2_SSH_KEY"
    )
    
    FOUND_KEY=""
    for location in "${COMMON_LOCATIONS[@]}"; do
        if [ -f "$location" ]; then
            echo "   ✅ Found at: $location"
            FOUND_KEY="$location"
            EC2_SSH_KEY="$location"
            break
        fi
    done
    
    if [ -z "$FOUND_KEY" ]; then
        echo "   ❌ SSH key not found in common locations"
        echo ""
        read -p "Enter path to SSH key (or press Enter to skip EC2 sync): " SSH_KEY_PATH
        if [ -z "$SSH_KEY_PATH" ] || [ ! -f "$SSH_KEY_PATH" ]; then
            echo "⚠️  Skipping EC2 sync. Will only sync to S3."
            USE_SSH=false
        else
            EC2_SSH_KEY="$SSH_KEY_PATH"
            USE_SSH=true
        fi
    else
        USE_SSH=true
    fi
    echo ""
else
    USE_SSH=true
fi

# Scripts to sync
SCRIPTS=(
    "ses_emailer.py"
    "ec2_send_campaign.sh"
    "ec2_send_custom.sh"
    "ec2_send_all_batches.sh"
    "lambda_handler.py"
)

# Ask for confirmation
echo "📋 Scripts to sync:"
for script in "${SCRIPTS[@]}"; do
    if [ -f "$LOCAL_DIR/$script" ]; then
        echo "  ✅ $script"
    else
        echo "  ⚠️  $script (not found locally)"
    fi
done
echo ""

read -p "Sync these scripts to EC2 and S3? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Cancelled"
    exit 0
fi

# Sync to S3
echo ""
echo "📤 Uploading to S3..."
for script in "${SCRIPTS[@]}"; do
    if [ -f "$LOCAL_DIR/$script" ]; then
        if aws s3 cp "$LOCAL_DIR/$script" "s3://$S3_BUCKET/$S3_SCRIPT_DIR/$script" --region "$REGION"; then
            echo "  ✅ Uploaded $script to S3"
        else
            echo "  ❌ Failed to upload $script to S3"
        fi
    else
        echo "  ⚠️  Skipping $script (not found locally)"
    fi
done

# Sync to EC2
if [ "$USE_SSH" = true ]; then
    echo ""
    echo "📤 Uploading to EC2 instance..."
    
    # Test SSH connection
    if ! ssh -i "$EC2_SSH_KEY" -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$EC2_USER@$EC2_INSTANCE_IP" "echo 'Connected'" &>/dev/null; then
        echo "❌ Cannot connect to EC2 instance. Please check:"
        echo "   - Instance is running"
        echo "   - SSH key is correct"
        echo "   - Security group allows SSH"
        exit 1
    fi
    
    # Create directory on EC2 if it doesn't exist
    ssh -i "$EC2_SSH_KEY" -o StrictHostKeyChecking=no "$EC2_USER@$EC2_INSTANCE_IP" "mkdir -p $EC2_SCRIPT_DIR" || true
    
    for script in "${SCRIPTS[@]}"; do
        if [ -f "$LOCAL_DIR/$script" ]; then
            if scp -i "$EC2_SSH_KEY" -o StrictHostKeyChecking=no "$LOCAL_DIR/$script" "$EC2_USER@$EC2_INSTANCE_IP:$EC2_SCRIPT_DIR/$script"; then
                echo "  ✅ Uploaded $script to EC2"
                # Make executable if it's a script
                if [[ "$script" == *.sh ]]; then
                    ssh -i "$EC2_SSH_KEY" -o StrictHostKeyChecking=no "$EC2_USER@$EC2_INSTANCE_IP" "chmod +x $EC2_SCRIPT_DIR/$script" || true
                fi
            else
                echo "  ❌ Failed to upload $script to EC2"
            fi
        else
            echo "  ⚠️  Skipping $script (not found locally)"
        fi
    done
fi

echo ""
echo "✅ Sync complete!"
echo ""
echo "📋 Next steps:"
if [ "$USE_SSH" = true ]; then
    echo "  1. SSH into EC2: ssh -i $EC2_SSH_KEY $EC2_USER@$EC2_INSTANCE_IP"
    echo "  2. Navigate to: cd $EC2_SCRIPT_DIR"
    echo "  3. Verify files: ls -lh"
fi
echo "  4. Compare again: ./compare_ec2_scripts.sh"

