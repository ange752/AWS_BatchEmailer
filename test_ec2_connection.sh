#!/bin/bash
# Test EC2 Connection Script
# This script tests connectivity to your EC2 instance and verifies setup

set -e

# Configuration - Update these values
EC2_INSTANCE_IP="${EC2_INSTANCE_IP:-54.189.152.124}"
# Default to most recent oasis-dev key in ~/.ssh if available
DEFAULT_KEY=$(ls -1t ~/.ssh/oasis-dev*.pem 2>/dev/null | head -1)
EC2_SSH_KEY="${EC2_SSH_KEY:-${DEFAULT_KEY:-$HOME/.ssh/oasis-dev-20220131.pem}}"
EC2_USER="${EC2_USER:-ec2-user}"
EC2_SCRIPT_DIR="${EC2_SCRIPT_DIR:-~/emailer}"
REGION="${REGION:-us-west-2}"

echo "🔌 Testing EC2 Connection"
echo "========================="
echo ""
echo "Configuration:"
echo "  EC2 Instance: $EC2_USER@$EC2_INSTANCE_IP"
echo "  SSH Key: $EC2_SSH_KEY"
echo "  EC2 Script Directory: $EC2_SCRIPT_DIR"
echo "  Region: $REGION"
echo ""

# Check if SSH key exists
if [ ! -f "$EC2_SSH_KEY" ]; then
    echo "⚠️  SSH key not found in current directory: $EC2_SSH_KEY"
    echo ""
    echo "Searching common locations..."
    
    # Check ~/.ssh for oasis-dev keys
    if [ -d "$HOME/.ssh" ]; then
        OASIS_KEYS=($(ls -1t "$HOME/.ssh"/oasis-dev*.pem 2>/dev/null | head -5))
        if [ ${#OASIS_KEYS[@]} -gt 0 ]; then
            echo "   Found oasis-dev keys in ~/.ssh:"
            if [ ${#OASIS_KEYS[@]} -eq 1 ]; then
                # Only one key found, use it
                FOUND_KEY="${OASIS_KEYS[0]}"
                EC2_SSH_KEY="$FOUND_KEY"
                echo "   ✅ Using: $FOUND_KEY"
            else
                # Multiple keys found, show options
                echo ""
                for i in "${!OASIS_KEYS[@]}"; do
                    echo "   $((i+1)). ${OASIS_KEYS[$i]}"
                done
                echo ""
                read -p "Select key number (1-${#OASIS_KEYS[@]}) or press Enter for most recent [1]: " KEY_CHOICE
                KEY_CHOICE=${KEY_CHOICE:-1}
                if [ "$KEY_CHOICE" -ge 1 ] && [ "$KEY_CHOICE" -le ${#OASIS_KEYS[@]} ]; then
                    FOUND_KEY="${OASIS_KEYS[$((KEY_CHOICE-1))]}"
                    EC2_SSH_KEY="$FOUND_KEY"
                    echo "   ✅ Using: $FOUND_KEY"
                else
                    # Use most recent
                    FOUND_KEY="${OASIS_KEYS[0]}"
                    EC2_SSH_KEY="$FOUND_KEY"
                    echo "   ✅ Using most recent: $FOUND_KEY"
                fi
            fi
        fi
    fi
    
    # If still not found, check other common locations
    if [ -z "$FOUND_KEY" ]; then
        COMMON_LOCATIONS=(
            "$HOME/.ssh/oasis-dev-20220131.pem"
            "$HOME/.ssh/$EC2_SSH_KEY"
            "$HOME/Downloads/oasis-dev-20220131.pem"
            "$HOME/Downloads/$EC2_SSH_KEY"
            "./oasis-dev-20220131.pem"
            "./$EC2_SSH_KEY"
        )
        
        for location in "${COMMON_LOCATIONS[@]}"; do
            if [ -f "$location" ]; then
                echo "   ✅ Found at: $location"
                FOUND_KEY="$location"
                EC2_SSH_KEY="$location"
                break
            fi
        done
    fi
    
    if [ -z "$FOUND_KEY" ]; then
        echo "   ❌ SSH key not found in common locations"
        echo ""
        echo "Please provide the path to your SSH key file."
        read -p "Enter path to SSH key (or press Enter to exit): " SSH_KEY_PATH
        if [ -z "$SSH_KEY_PATH" ]; then
            echo ""
            echo "❌ No SSH key provided. Exiting."
            echo ""
            echo "💡 Available oasis-dev keys in ~/.ssh:"
            ls -1 "$HOME/.ssh"/oasis-dev*.pem 2>/dev/null | sed 's/^/   /' || echo "   (none found)"
            echo ""
            echo "💡 Or test manually:"
            echo "   ssh -i ~/.ssh/oasis-dev-01192021.pem ec2-user@54.189.152.124"
            exit 1
        elif [ ! -f "$SSH_KEY_PATH" ]; then
            echo "❌ SSH key not found: $SSH_KEY_PATH"
            exit 1
        else
            EC2_SSH_KEY="$SSH_KEY_PATH"
            echo "✅ Using SSH key: $EC2_SSH_KEY"
        fi
    fi
    echo ""
fi

# Check SSH key permissions
echo "🔑 Checking SSH key permissions..."
if [ -f "$EC2_SSH_KEY" ]; then
    KEY_PERMS=$(stat -f %A "$EC2_SSH_KEY" 2>/dev/null || stat -c %a "$EC2_SSH_KEY" 2>/dev/null || echo "unknown")
    echo "   Key permissions: $KEY_PERMS"
    if [ "$KEY_PERMS" != "600" ] && [ "$KEY_PERMS" != "400" ]; then
        echo "   ⚠️  Warning: SSH key should have permissions 600 or 400"
        echo "   Fix with: chmod 400 $EC2_SSH_KEY"
    else
        echo "   ✅ Permissions OK"
    fi
else
    echo "   ❌ SSH key file not found"
    exit 1
fi
echo ""

# Test 1: Basic connectivity (ping)
echo "🧪 Test 1: Basic Connectivity (Ping)"
echo "-------------------------------------"
if ping -c 1 -W 2 "$EC2_INSTANCE_IP" &>/dev/null; then
    echo "   ✅ Instance is reachable (ping successful)"
else
    echo "   ⚠️  Instance not reachable via ping (may be normal - ping may be disabled)"
    echo "   Will continue with SSH test..."
fi
echo ""

# Test 2: SSH connection
echo "🧪 Test 2: SSH Connection"
echo "-------------------------"
echo "   Attempting SSH connection..."
SSH_WORKS=false
if ssh -i "$EC2_SSH_KEY" \
    -o ConnectTimeout=10 \
    -o StrictHostKeyChecking=no \
    -o BatchMode=yes \
    -o LogLevel=ERROR \
    "$EC2_USER@$EC2_INSTANCE_IP" \
    "echo 'SSH connection successful!'" 2>&1; then
    echo "   ✅ SSH connection successful!"
    SSH_WORKS=true
else
    SSH_ERROR=$?
    echo "   ❌ SSH connection failed (exit code: $SSH_ERROR)"
    echo ""
    echo "   Common issues:"
    echo "   1. Instance may not be running"
    echo "   2. Security group may not allow SSH (port 22)"
    echo "   3. SSH key may be incorrect"
    echo "   4. Instance IP may have changed"
    echo "   5. Network connectivity issues"
    echo ""
    echo "   To check instance status:"
    echo "   aws ec2 describe-instances --instance-ids i-0462951dc6f221468 --region $REGION --query 'Reservations[0].Instances[0].State.Name' --output text"
    echo ""
    echo "   To check security group:"
    echo "   aws ec2 describe-instances --instance-ids i-0462951dc6f221468 --region $REGION --query 'Reservations[0].Instances[0].SecurityGroups'"
fi
echo ""

# If SSH works, run additional tests
if [ "$SSH_WORKS" = true ]; then
    # Test 3: System information
    echo "🧪 Test 3: System Information"
    echo "----------------------------"
    ssh -i "$EC2_SSH_KEY" \
        -o StrictHostKeyChecking=no \
        -o LogLevel=ERROR \
        "$EC2_USER@$EC2_INSTANCE_IP" \
        "echo '   Hostname:' \$(hostname); \
         echo '   OS:' \$(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d'\"' -f2 || uname -a); \
         echo '   Uptime:' \$(uptime -p 2>/dev/null || uptime | awk -F'up ' '{print \$2}' | awk -F',' '{print \$1}'); \
         echo '   Disk space:' \$(df -h / | tail -1 | awk '{print \$4 \" available of \" \$2}'); \
         echo '   Memory:' \$(free -h 2>/dev/null | grep Mem | awk '{print \$3 \" / \" \$2}' || echo 'N/A')" 2>/dev/null || echo "   ⚠️  Could not retrieve system info"
    echo ""
    
    # Test 4: Required tools
    echo "🧪 Test 4: Required Tools"
    echo "------------------------"
    ssh -i "$EC2_SSH_KEY" \
        -o StrictHostKeyChecking=no \
        -o LogLevel=ERROR \
        "$EC2_USER@$EC2_INSTANCE_IP" \
        "echo '   Python 3:' \$(python3 --version 2>&1 || echo 'NOT FOUND'); \
         echo '   AWS CLI:' \$(aws --version 2>&1 || echo 'NOT FOUND'); \
         echo '   pip3:' \$(pip3 --version 2>&1 || echo 'NOT FOUND'); \
         echo '   boto3:' \$(python3 -c 'import boto3; print(boto3.__version__)' 2>&1 || echo 'NOT INSTALLED')" 2>/dev/null || echo "   ⚠️  Could not check tools"
    echo ""
    
    # Test 5: AWS CLI configuration
    echo "🧪 Test 5: AWS CLI Configuration"
    echo "-------------------------------"
    ssh -i "$EC2_SSH_KEY" \
        -o StrictHostKeyChecking=no \
        -o LogLevel=ERROR \
        "$EC2_USER@$EC2_INSTANCE_IP" \
        "if aws sts get-caller-identity &>/dev/null; then
            echo '   ✅ AWS CLI is configured'
            echo '   Account:' \$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo 'N/A')
            echo '   User/Role:' \$(aws sts get-caller-identity --query Arn --output text 2>/dev/null || echo 'N/A')
            echo '   Region:' \$(aws configure get region 2>/dev/null || echo 'N/A')
        else
            echo '   ⚠️  AWS CLI not configured or credentials invalid'
        fi" 2>/dev/null || echo "   ⚠️  Could not check AWS CLI configuration"
    echo ""
    
    # Test 6: Script directory and files
    echo "🧪 Test 6: Script Directory"
    echo "--------------------------"
    ssh -i "$EC2_SSH_KEY" \
        -o StrictHostKeyChecking=no \
        -o LogLevel=ERROR \
        "$EC2_USER@$EC2_INSTANCE_IP" \
        "if [ -d $EC2_SCRIPT_DIR ]; then
            echo '   ✅ Directory exists: $EC2_SCRIPT_DIR'
            echo '   Files in directory:'
            ls -lh $EC2_SCRIPT_DIR 2>/dev/null | awk '{print \"      \" \$9 \" (\" \$5 \")\"}' | tail -n +2
            echo '   Total files:' \$(ls -1 $EC2_SCRIPT_DIR 2>/dev/null | wc -l)
        else
            echo '   ⚠️  Directory does not exist: $EC2_SCRIPT_DIR'
            echo '   Creating directory...'
            mkdir -p $EC2_SCRIPT_DIR && echo '   ✅ Directory created' || echo '   ❌ Failed to create directory'
        fi" 2>/dev/null || echo "   ⚠️  Could not check script directory"
    echo ""
    
    # Test 7: S3 access
    echo "🧪 Test 7: S3 Access"
    echo "-------------------"
    ssh -i "$EC2_SSH_KEY" \
        -o StrictHostKeyChecking=no \
        -o LogLevel=ERROR \
        "$EC2_USER@$EC2_INSTANCE_IP" \
        "if aws s3 ls s3://amaze-aws-emailer/ --region $REGION &>/dev/null; then
            echo '   ✅ S3 bucket accessible: amaze-aws-emailer'
            echo '   Files in scripts/ directory:'
            aws s3 ls s3://amaze-aws-emailer/scripts/ --region $REGION 2>/dev/null | awk '{print \"      \" \$4 \" (\" \$3 \" bytes)\"}' || echo '      (no files or error)'
        else
            echo '   ⚠️  Cannot access S3 bucket or permissions denied'
        fi" 2>/dev/null || echo "   ⚠️  Could not test S3 access"
    echo ""
    
    # Test 8: Network connectivity
    echo "🧪 Test 8: Network Connectivity"
    echo "------------------------------"
    ssh -i "$EC2_SSH_KEY" \
        -o StrictHostKeyChecking=no \
        -o LogLevel=ERROR \
        "$EC2_USER@$EC2_INSTANCE_IP" \
        "echo '   Internet connectivity:' \$(ping -c 1 -W 2 8.8.8.8 &>/dev/null && echo '✅ OK' || echo '❌ Failed'); \
         echo '   AWS endpoints:' \$(curl -s --connect-timeout 2 https://aws.amazon.com &>/dev/null && echo '✅ Reachable' || echo '⚠️  May need VPC endpoint')" 2>/dev/null || echo "   ⚠️  Could not test network connectivity"
    echo ""
    
    # Summary
    echo "✅ Connection Test Complete"
    echo "=========================="
    echo ""
    echo "✅ SSH connection is working!"
    echo ""
    echo "💡 Quick Commands:"
    echo "   SSH into instance:"
    echo "   ssh -i $EC2_SSH_KEY $EC2_USER@$EC2_INSTANCE_IP"
    echo ""
    echo "   Run a command on instance:"
    echo "   ssh -i $EC2_SSH_KEY $EC2_USER@$EC2_INSTANCE_IP 'command'"
    echo ""
    echo "   Check scripts:"
    echo "   ssh -i $EC2_SSH_KEY $EC2_USER@$EC2_INSTANCE_IP 'ls -lh $EC2_SCRIPT_DIR'"
    echo ""
fi

if [ "$SSH_WORKS" != true ]; then
    echo "❌ Connection Test Failed"
    echo "========================="
    echo ""
    echo "Could not establish SSH connection to the instance."
    echo ""
    echo "Next steps:"
    echo "1. Verify instance is running:"
    echo "   aws ec2 describe-instances --instance-ids i-0462951dc6f221468 --region $REGION"
    echo ""
    echo "2. Check instance public IP:"
    echo "   aws ec2 describe-instances --instance-ids i-0462951dc6f221468 --region $REGION --query 'Reservations[0].Instances[0].PublicIpAddress' --output text"
    echo ""
    echo "3. Verify security group allows SSH (port 22) from your IP"
    echo ""
    echo "4. Try manual SSH connection:"
    echo "   ssh -i $EC2_SSH_KEY $EC2_USER@$EC2_INSTANCE_IP"
    echo ""
    exit 1
fi

