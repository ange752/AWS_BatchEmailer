#!/bin/bash
# Diagnose EC2 Connection Issues
# This script helps diagnose why you can't connect to an EC2 instance

set -e

EC2_IP="${1:-54.189.152.124}"
EC2_USER="${EC2_USER:-ec2-user}"
REGION="${REGION:-us-west-2}"

# Find SSH key
DEFAULT_KEY=$(ls -1t ~/.ssh/oasis-dev*.pem 2>/dev/null | head -1)
EC2_SSH_KEY="${EC2_SSH_KEY:-${DEFAULT_KEY}}"

echo "🔍 Diagnosing EC2 Connection Issues"
echo "===================================="
echo ""
echo "Target: $EC2_USER@$EC2_IP"
echo "SSH Key: $EC2_SSH_KEY"
echo "Region: $REGION"
echo ""

# Test 1: Basic connectivity
echo "🧪 Test 1: Basic Connectivity (Ping)"
echo "-------------------------------------"
if ping -c 3 -W 2 "$EC2_IP" &>/dev/null; then
    echo "   ✅ Instance is reachable (ping successful)"
    PING_OK=true
else
    echo "   ❌ Instance is NOT reachable (ping failed)"
    echo "   This could mean:"
    echo "   - Instance is stopped/terminated"
    echo "   - Wrong IP address"
    echo "   - Network connectivity issues"
    PING_OK=false
fi
echo ""

# Test 2: Port 22 (SSH) connectivity
echo "🧪 Test 2: SSH Port (22) Connectivity"
echo "--------------------------------------"
if command -v nc &>/dev/null; then
    if timeout 5 nc -zv "$EC2_IP" 22 2>&1 | grep -q "succeeded"; then
        echo "   ✅ Port 22 is OPEN and accepting connections"
        PORT_22_OPEN=true
    else
        echo "   ❌ Port 22 is CLOSED or TIMEOUT"
        PORT_22_OPEN=false
    fi
elif command -v telnet &>/dev/null; then
    if timeout 5 bash -c "echo >/dev/tcp/$EC2_IP/22" 2>/dev/null; then
        echo "   ✅ Port 22 is OPEN"
        PORT_22_OPEN=true
    else
        echo "   ❌ Port 22 is CLOSED or TIMEOUT"
        PORT_22_OPEN=false
    fi
else
    echo "   ⚠️  Cannot test port (nc/telnet not available)"
    PORT_22_OPEN=unknown
fi
echo ""

# Test 3: SSH connection attempt
echo "🧪 Test 3: SSH Connection Attempt"
echo "----------------------------------"
if [ -f "$EC2_SSH_KEY" ]; then
    echo "   Attempting SSH connection..."
    SSH_OUTPUT=$(timeout 10 ssh -i "$EC2_SSH_KEY" \
        -o ConnectTimeout=5 \
        -o StrictHostKeyChecking=no \
        -o BatchMode=yes \
        -o LogLevel=ERROR \
        "$EC2_USER@$EC2_IP" \
        "echo 'SSH successful'" 2>&1)
    
    if [ $? -eq 0 ]; then
        echo "   ✅ SSH connection successful!"
        SSH_WORKS=true
    else
        echo "   ❌ SSH connection failed"
        echo "   Error output:"
        echo "$SSH_OUTPUT" | sed 's/^/      /'
        SSH_WORKS=false
    fi
else
    echo "   ⚠️  SSH key not found: $EC2_SSH_KEY"
    SSH_WORKS=false
fi
echo ""

# Test 4: Check if instance exists in AWS
echo "🧪 Test 4: Verify Instance in AWS"
echo "----------------------------------"
if command -v aws &>/dev/null; then
    echo "   Checking AWS for instance with IP $EC2_IP..."
    
    # Try to find instance by public IP
    INSTANCE_INFO=$(aws ec2 describe-instances \
        --region "$REGION" \
        --filters "Name=ip-address,Values=$EC2_IP" \
        --query 'Reservations[*].Instances[*].[InstanceId,State.Name,PublicIpAddress,PrivateIpAddress,KeyName]' \
        --output text 2>&1 || echo "ERROR")
    
    if [[ "$INSTANCE_INFO" != *"ERROR"* ]] && [[ -n "$INSTANCE_INFO" ]]; then
        echo "   ✅ Found instance in AWS:"
        echo "$INSTANCE_INFO" | while read -r instance_id state pub_ip priv_ip key_name; do
            echo "      Instance ID: $instance_id"
            echo "      State: $state"
            echo "      Public IP: $pub_ip"
            echo "      Private IP: $priv_ip"
            echo "      Key Name: $key_name"
        done
    else
        echo "   ⚠️  Could not find instance with IP $EC2_IP in AWS"
        echo "   This could mean:"
        echo "   - Instance is in a different region"
        echo "   - Instance has been terminated"
        echo "   - IP address has changed"
    fi
else
    echo "   ⚠️  AWS CLI not available or not configured"
fi
echo ""

# Diagnosis summary
echo "📊 Diagnosis Summary"
echo "===================="
echo ""

if [ "$PING_OK" = true ] && [ "$PORT_22_OPEN" != true ]; then
    echo "🔴 Problem: Instance is reachable but SSH port (22) is CLOSED"
    echo ""
    echo "Most likely causes:"
    echo "1. ⚠️  Security Group doesn't allow SSH (port 22) from your IP"
    echo "   Solution: Update security group to allow SSH from your IP"
    echo ""
    echo "2. ⚠️  SSH service is not running on the instance"
    echo "   Solution: Check instance system logs or restart instance"
    echo ""
    echo "3. ⚠️  Instance firewall is blocking port 22"
    echo "   Solution: Check iptables/firewalld configuration on instance"
    echo ""
    echo "Quick fixes:"
    echo "  • Check security group rules:"
    echo "    aws ec2 describe-instances --region $REGION --filters \"Name=ip-address,Values=$EC2_IP\" --query 'Reservations[0].Instances[0].SecurityGroups'"
    echo ""
    echo "  • Add your IP to security group:"
    echo "    MY_IP=$(curl -s https://checkip.amazonaws.com)"
    echo "    aws ec2 authorize-security-group-ingress --group-id sg-xxxxx --protocol tcp --port 22 --cidr $MY_IP/32 --region $REGION"
fi

if [ "$PING_OK" = false ]; then
    echo "🔴 Problem: Instance is NOT reachable"
    echo ""
    echo "Most likely causes:"
    echo "1. ⚠️  Instance is stopped or terminated"
    echo "   Solution: Check instance state and start if stopped"
    echo ""
    echo "2. ⚠️  Wrong IP address"
    echo "   Solution: Verify the correct IP address for your instance"
    echo ""
    echo "3. ⚠️  Instance doesn't have a public IP"
    echo "   Solution: Check if instance is in a private subnet"
    echo ""
    echo "Quick fixes:"
    echo "  • Check instance state:"
    echo "    aws ec2 describe-instances --region $REGION --filters \"Name=ip-address,Values=$EC2_IP\""
    echo ""
    echo "  • Get current public IP:"
    echo "    aws ec2 describe-instances --instance-ids i-xxxxx --region $REGION --query 'Reservations[0].Instances[0].PublicIpAddress' --output text"
fi

if [ "$PING_OK" = true ] && [ "$PORT_22_OPEN" = true ] && [ "$SSH_WORKS" = false ]; then
    echo "🟡 Problem: Port 22 is open but SSH authentication failed"
    echo ""
    echo "Most likely causes:"
    echo "1. ⚠️  Wrong SSH key"
    echo "   Solution: Use the correct key pair for this instance"
    echo ""
    echo "2. ⚠️  Wrong username"
    echo "   Solution: Try 'ec2-user' (Amazon Linux), 'ubuntu' (Ubuntu), or 'admin' (Debian)"
    echo ""
    echo "3. ⚠️  SSH key permissions incorrect"
    echo "   Solution: chmod 400 $EC2_SSH_KEY"
    echo ""
fi

if [ "$PING_OK" = true ] && [ "$PORT_22_OPEN" = true ] && [ "$SSH_WORKS" = true ]; then
    echo "✅ Connection is working!"
fi

echo ""
echo "💡 Common Solutions:"
echo "  1. Check instance is running:"
echo "     aws ec2 describe-instances --region $REGION --instance-ids i-xxxxx"
echo ""
echo "  2. Check security group allows SSH from your IP:"
echo "     MY_IP=$(curl -s https://checkip.amazonaws.com 2>/dev/null || echo 'YOUR_IP')"
echo "     echo \"Your IP: $MY_IP\""
echo ""
echo "  3. Try different username:"
echo "     ssh -i $EC2_SSH_KEY ubuntu@$EC2_IP"
echo "     ssh -i $EC2_SSH_KEY admin@$EC2_IP"
echo ""
echo "  4. Check SSH key permissions:"
echo "     chmod 400 $EC2_SSH_KEY"
echo ""

