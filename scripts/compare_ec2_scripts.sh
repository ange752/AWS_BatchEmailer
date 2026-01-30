#!/bin/bash
# Compare Local Scripts with EC2 Instance Scripts
# This script checks if scripts on the remote EC2 instance match local versions

set -e

# Configuration - Update these values
EC2_INSTANCE_IP="${EC2_INSTANCE_IP:-54.189.152.124}"
EC2_SSH_KEY="${EC2_SSH_KEY:-$HOME/.ssh/oasis-dev-20220131.pem}"
EC2_USER="${EC2_USER:-ec2-user}"
EC2_SCRIPT_DIR="${EC2_SCRIPT_DIR:-~/emailer}"
REGION="${REGION:-us-west-2}"
S3_BUCKET="${S3_BUCKET:-amaze-aws-emailer}"
S3_SCRIPT_DIR="${S3_SCRIPT_DIR:-scripts}"

# Local script directory (where this script lives = scripts/)
LOCAL_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "🔍 Comparing Local Scripts with EC2 Instance"
echo "============================================="
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
        read -p "Enter path to SSH key (or press Enter to skip SSH comparison): " SSH_KEY_PATH
        if [ -z "$SSH_KEY_PATH" ] || [ ! -f "$SSH_KEY_PATH" ]; then
            echo "⚠️  Skipping SSH comparison. Will only check S3."
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

# Test SSH connection if using SSH
if [ "$USE_SSH" = true ]; then
    echo "🔌 Testing SSH connection..."
    if ssh -i "$EC2_SSH_KEY" -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$EC2_USER@$EC2_INSTANCE_IP" "echo 'Connected'" &>/dev/null; then
        echo "✅ SSH connection successful"
    else
        echo "❌ SSH connection failed"
        echo "   Trying to connect anyway..."
        USE_SSH=true  # Still try, might work
    fi
    echo ""
fi

# Scripts to compare
SCRIPTS=(
    "ses_emailer.py"
    "ec2_send_campaign.sh"
    "ec2_send_custom.sh"
    "ec2_send_all_batches.sh"
    "lambda_handler.py"
)

# Create temporary directory for remote files
TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT

echo "📋 Scripts to Compare:"
for script in "${SCRIPTS[@]}"; do
    echo "  - $script"
done
echo ""

# Function to get file from EC2 via SSH
get_ec2_file() {
    local file=$1
    local remote_path="$EC2_SCRIPT_DIR/$file"
    local local_path="$TMP_DIR/ec2_$file"
    
    if [ "$USE_SSH" = true ]; then
        ssh -i "$EC2_SSH_KEY" -o StrictHostKeyChecking=no "$EC2_USER@$EC2_INSTANCE_IP" "cat $remote_path" 2>/dev/null > "$local_path" || return 1
    else
        return 1
    fi
}

# Function to get file from S3
get_s3_file() {
    local file=$1
    local local_path="$TMP_DIR/s3_$file"
    
    aws s3 cp "s3://$S3_BUCKET/$S3_SCRIPT_DIR/$file" "$local_path" --region "$REGION" 2>/dev/null || return 1
}

# Function to get file modification time from EC2
get_ec2_mtime() {
    local file=$1
    local remote_path="$EC2_SCRIPT_DIR/$file"
    
    if [ "$USE_SSH" = true ]; then
        # Get modification time in seconds since epoch
        ssh -i "$EC2_SSH_KEY" -o StrictHostKeyChecking=no "$EC2_USER@$EC2_INSTANCE_IP" "stat -c %Y $remote_path 2>/dev/null || stat -f %m $remote_path 2>/dev/null" 2>/dev/null || echo ""
    else
        echo ""
    fi
}

# Function to get S3 file LastModified timestamp
get_s3_mtime() {
    local file=$1
    local s3_path="s3://$S3_BUCKET/$S3_SCRIPT_DIR/$file"
    
    # Get LastModified in ISO format, convert to epoch using Python
    aws s3api head-object --bucket "$S3_BUCKET" --key "$S3_SCRIPT_DIR/$file" --region "$REGION" 2>/dev/null | \
        python3 -c "import sys, json; from datetime import datetime; data=json.load(sys.stdin); dt=datetime.fromisoformat(data['LastModified'].replace('Z', '+00:00')); print(int(dt.timestamp()))" 2>/dev/null || \
    # Fallback: get from s3 ls
    aws s3 ls "$s3_path" --region "$REGION" 2>/dev/null | awk '{if (NF >= 4) {date=$1" "$2; gsub(/-/, " ", date); gsub(/:/, " ", date); print date}}' | \
        python3 -c "import sys; from datetime import datetime; line=sys.stdin.read().strip(); dt=datetime.strptime(line, '%Y %m %d %H %M %S'); print(int(dt.timestamp()))" 2>/dev/null || \
    echo ""
}

# Function to format timestamp for display
format_timestamp() {
    local timestamp=$1
    if [ -n "$timestamp" ] && [ "$timestamp" != "0" ] && [ "$timestamp" != "" ]; then
        # Use Python for cross-platform date formatting
        python3 -c "import sys; from datetime import datetime; print(datetime.fromtimestamp(int(sys.argv[1])).strftime('%Y-%m-%d %H:%M:%S'))" "$timestamp" 2>/dev/null || \
        # Fallback to system date command
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            date -r "$timestamp" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "$timestamp"
        else
            # Linux
            date -d "@$timestamp" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "$timestamp"
        fi
    else
        echo "Unknown"
    fi
}

# Function to compare timestamps and determine which is newer
compare_timestamps() {
    local local_ts=$1
    local remote_ts=$2
    local name=$3
    
    if [ -z "$remote_ts" ] || [ "$remote_ts" = "0" ]; then
        echo "⚠️  (timestamp unavailable)"
        return
    fi
    
    if [ -z "$local_ts" ] || [ "$local_ts" = "0" ]; then
        echo "🆕 $name is newer (local timestamp unavailable)"
        return
    fi
    
    if [ "$local_ts" -gt "$remote_ts" ]; then
        local diff=$((local_ts - remote_ts))
        local diff_hr=$((diff / 3600))
        local diff_min=$(((diff % 3600) / 60))
        if [ $diff_hr -gt 0 ]; then
            echo "🆕 Local is newer by ${diff_hr}h ${diff_min}m"
        elif [ $diff_min -gt 0 ]; then
            echo "🆕 Local is newer by ${diff_min}m"
        else
            echo "🆕 Local is newer by ${diff}s"
        fi
    elif [ "$remote_ts" -gt "$local_ts" ]; then
        local diff=$((remote_ts - local_ts))
        local diff_hr=$((diff / 3600))
        local diff_min=$(((diff % 3600) / 60))
        if [ $diff_hr -gt 0 ]; then
            echo "🆕 $name is newer by ${diff_hr}h ${diff_min}m"
        elif [ $diff_min -gt 0 ]; then
            echo "🆕 $name is newer by ${diff_min}m"
        else
            echo "🆕 $name is newer by ${diff}s"
        fi
    else
        echo "⏰ Same timestamp"
    fi
}

# Function to analyze diff and show change summary
analyze_diff() {
    local file1=$1
    local file2=$2
    local name=$3
    local filename=$4  # Original filename for diff file naming
    
    if [ ! -f "$file1" ] || [ ! -f "$file2" ]; then
        return
    fi
    
    # Get unified diff
    local diff_output=$(diff -u "$file1" "$file2" 2>/dev/null || true)
    
    if [ -z "$diff_output" ]; then
        return
    fi
    
    # Count additions, deletions (exclude diff headers)
    local added=$(echo "$diff_output" | grep -E "^\+[^+]" | wc -l | tr -d ' ')
    local removed=$(echo "$diff_output" | grep -E "^\-[^-]" | wc -l | tr -d ' ')
    
    # Default to 0 if empty
    [ -z "$added" ] && added=0
    [ -z "$removed" ] && removed=0
    
    # Calculate net change
    local net_change=$((added - removed))
    
    echo "          📊 Change Summary vs $name:"
    if [ "$added" -gt 0 ] || [ "$removed" -gt 0 ]; then
        echo "            + $added lines added"
        echo "            - $removed lines removed"
        if [ "$net_change" -gt 0 ]; then
            echo "            📈 Net: +$net_change lines (file grew)"
        elif [ "$net_change" -lt 0 ]; then
            echo "            📉 Net: $net_change lines (file shrunk)"
        else
            echo "            ↔️  Net: 0 lines (same size, content changed)"
        fi
    fi
    
    # Show key changes (function/variable definitions, imports, etc.)
    echo "          🔍 Key Changes:"
    
    # Check for added/removed functions or classes
    local func_changes=$(echo "$diff_output" | grep -E "^[-+].*(def |class |function |^\+\+\+|^---)" | head -15 || true)
    if [ -n "$func_changes" ]; then
        echo "$func_changes" | head -10 | while IFS= read -r line || [ -n "$line" ]; do
            local prefix=$(echo "$line" | cut -c1)
            local content=$(echo "$line" | cut -c2- | sed 's/^[[:space:]]*//' | cut -c1-90)
            if [ "$prefix" = "+" ] && ! echo "$content" | grep -qE "^\+{3}|^@"; then
                echo "            ➕ Added: $content"
            elif [ "$prefix" = "-" ] && ! echo "$content" | grep -qE "^-{3}|^@"; then
                echo "            ➖ Removed: $content"
            fi
        done
    fi
    
    # Check for configuration changes (common patterns)
    local config_changes=$(echo "$diff_output" | grep -iE "^[-+].*(BUCKET|REGION|SENDER|KEY|CONFIG|INSTANCE|IP|SSH)" | grep -vE "^[-+]{3}|^@@" | head -10 || true)
    if [ -n "$config_changes" ]; then
        echo "            ⚙️  Configuration changes:"
        echo "$config_changes" | head -5 | while IFS= read -r line || [ -n "$line" ]; do
            local prefix=$(echo "$line" | cut -c1)
            local content=$(echo "$line" | cut -c2- | sed 's/^[[:space:]]*//' | cut -c1-75)
            if [ "$prefix" = "+" ]; then
                echo "               + $content"
            elif [ "$prefix" = "-" ]; then
                echo "               - $content"
            fi
        done
    fi
    
    # Show sample of actual code changes with context
    echo "          📝 Sample Code Changes (unified diff):"
    echo "$diff_output" | grep -E "^[-+][^-+]" | head -20 | while IFS= read -r line || [ -n "$line" ]; do
        local prefix=$(echo "$line" | cut -c1)
        local content=$(echo "$line" | cut -c2- | cut -c1-100)
        if [ "$prefix" = "+" ]; then
            echo "            + $content"
        elif [ "$prefix" = "-" ]; then
            echo "            - $content"
        fi
    done | head -20
    
    # Show context around changes (hunk headers)
    local hunks=$(echo "$diff_output" | grep -E "^@@" | head -5 || true)
    if [ -n "$hunks" ]; then
        echo "          📍 Change locations:"
        echo "$hunks" | while IFS= read -r hunk || [ -n "$hunk" ]; do
            echo "            $hunk"
        done
    fi
    
    # Save full diff to a file for later review
    local safe_filename=$(echo "$filename" | sed 's/[^a-zA-Z0-9._-]/_/g')
    local diff_file="$TMP_DIR/diff_${safe_filename}_${name}.patch"
    diff -u "$file1" "$file2" > "$diff_file" 2>/dev/null || true
    if [ -f "$diff_file" ] && [ -s "$diff_file" ]; then
        echo "          💾 Full diff saved: $diff_file"
        echo "            (View with: cat $diff_file or diff -u local remote)"
    fi
}

# Function to compare files with detailed change analysis
compare_files() {
    local file=$1
    local local_file="$LOCAL_DIR/$file"
    local remote_file="$TMP_DIR/ec2_$file"
    local s3_file="$TMP_DIR/s3_$file"
    
    if [ ! -f "$local_file" ]; then
        echo "  ⚠️  Local file not found: $file"
        return
    fi
    
    local has_ec2=false
    local has_s3=false
    
    # Check EC2
    if [ "$USE_SSH" = true ] && [ -f "$remote_file" ] && [ -s "$remote_file" ]; then
        has_ec2=true
    fi
    
    # Check S3
    if [ -f "$s3_file" ] && [ -s "$s3_file" ]; then
        has_s3=true
    fi
    
    # Get modification timestamps
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        local local_mtime=$(stat -f %m "$local_file" 2>/dev/null || echo "0")
    else
        # Linux
        local local_mtime=$(stat -c %Y "$local_file" 2>/dev/null || echo "0")
    fi
    local ec2_mtime=""
    local s3_mtime=""
    
    if [ "$has_ec2" = true ]; then
        ec2_mtime=$(get_ec2_mtime "$file")
    fi
    
    if [ "$has_s3" = true ]; then
        s3_mtime=$(get_s3_mtime "$file")
    fi
    
    echo ""
    echo "📄 $file"
    echo "=========================================="
    local local_date=$(format_timestamp "$local_mtime")
    echo "   Local: ✅ $(wc -l < "$local_file" | tr -d ' ') lines, $(du -h "$local_file" | cut -f1)"
    echo "          📅 Modified: $local_date"
    
    if [ "$has_ec2" = true ]; then
        local ec2_date=$(format_timestamp "$ec2_mtime")
        if diff -q "$local_file" "$remote_file" &>/dev/null; then
            echo "   EC2:   ✅ MATCH ($(wc -l < "$remote_file" | tr -d ' ') lines)"
            echo "          📅 Modified: $ec2_date"
            compare_timestamps "$local_mtime" "$ec2_mtime" "EC2"
        else
            echo "   EC2:   ❌ DIFFERENT ($(wc -l < "$remote_file" | tr -d ' ') lines)"
            echo "          📅 Modified: $ec2_date"
            compare_timestamps "$local_mtime" "$ec2_mtime" "EC2"
            analyze_diff "$local_file" "$remote_file" "EC2" "$file"
        fi
    else
        echo "   EC2:   ⚠️  Not found or couldn't retrieve"
    fi
    
    if [ "$has_s3" = true ]; then
        local s3_date=$(format_timestamp "$s3_mtime")
        if diff -q "$local_file" "$s3_file" &>/dev/null; then
            echo "   S3:    ✅ MATCH ($(wc -l < "$s3_file" | tr -d ' ') lines)"
            echo "          📅 Modified: $s3_date"
            compare_timestamps "$local_mtime" "$s3_mtime" "S3"
        else
            echo "   S3:    ❌ DIFFERENT ($(wc -l < "$s3_file" | tr -d ' ') lines)"
            echo "          📅 Modified: $s3_date"
            compare_timestamps "$local_mtime" "$s3_mtime" "S3"
            analyze_diff "$local_file" "$s3_file" "S3" "$file"
        fi
    else
        echo "   S3:    ⚠️  Not found or couldn't retrieve"
    fi
    echo ""
}

# Download files from EC2
if [ "$USE_SSH" = true ]; then
    echo "📥 Downloading scripts from EC2 instance..."
    for script in "${SCRIPTS[@]}"; do
        if get_ec2_file "$script"; then
            echo "  ✅ Downloaded $script from EC2"
        else
            echo "  ⚠️  Could not download $script from EC2"
        fi
    done
    echo ""
fi

# Download files from S3
echo "📥 Downloading scripts from S3..."
for script in "${SCRIPTS[@]}"; do
    if get_s3_file "$script"; then
        echo "  ✅ Downloaded $script from S3"
    else
        echo "  ⚠️  Could not download $script from S3"
    fi
done
echo ""

# Compare files
echo "🔍 Comparing Files..."
echo "===================="
for script in "${SCRIPTS[@]}"; do
    compare_files "$script"
done

# Summary
echo ""
echo "📊 Summary"
echo "=========="
echo ""

# Count matches and track which versions are newer
MATCH_EC2=0
MATCH_S3=0
TOTAL=0
NEWER_LOCAL_EC2=0
NEWER_EC2_LOCAL=0
NEWER_LOCAL_S3=0
NEWER_S3_LOCAL=0

echo "📋 Version Comparison Summary:"
echo ""

for script in "${SCRIPTS[@]}"; do
    local_file="$LOCAL_DIR/$script"
    if [ ! -f "$local_file" ]; then
        continue
    fi
    TOTAL=$((TOTAL + 1))
    
    remote_file="$TMP_DIR/ec2_$script"
    s3_file="$TMP_DIR/s3_$script"
    
    # Get timestamps for comparison
    if [[ "$OSTYPE" == "darwin"* ]]; then
        local_mtime=$(stat -f %m "$local_file" 2>/dev/null || echo "0")
    else
        local_mtime=$(stat -c %Y "$local_file" 2>/dev/null || echo "0")
    fi
    
    # Check EC2
    if [ "$USE_SSH" = true ] && [ -f "$remote_file" ] && [ -s "$remote_file" ]; then
        if diff -q "$local_file" "$remote_file" &>/dev/null; then
            MATCH_EC2=$((MATCH_EC2 + 1))
            echo "  ✅ $script: EC2 matches local"
        else
            ec2_mtime=$(get_ec2_mtime "$script")
            if [ -n "$ec2_mtime" ] && [ "$ec2_mtime" != "0" ] && [ "$local_mtime" != "0" ]; then
                if [ "$local_mtime" -gt "$ec2_mtime" ]; then
                    NEWER_LOCAL_EC2=$((NEWER_LOCAL_EC2 + 1))
                    local_date=$(format_timestamp "$local_mtime")
                    ec2_date=$(format_timestamp "$ec2_mtime")
                    echo "  🆕 $script: LOCAL is newer (Local: $local_date, EC2: $ec2_date)"
                elif [ "$ec2_mtime" -gt "$local_mtime" ]; then
                    NEWER_EC2_LOCAL=$((NEWER_EC2_LOCAL + 1))
                    local_date=$(format_timestamp "$local_mtime")
                    ec2_date=$(format_timestamp "$ec2_mtime")
                    echo "  🆕 $script: EC2 is newer (Local: $local_date, EC2: $ec2_date)"
                else
                    echo "  ⚠️  $script: EC2 differs from local (same timestamp but content differs)"
                fi
            else
                echo "  ⚠️  $script: EC2 differs from local (could not compare timestamps)"
            fi
        fi
    fi
    
    # Check S3
    if [ -f "$s3_file" ] && [ -s "$s3_file" ]; then
        if diff -q "$local_file" "$s3_file" &>/dev/null; then
            MATCH_S3=$((MATCH_S3 + 1))
            echo "  ✅ $script: S3 matches local"
        else
            s3_mtime=$(get_s3_mtime "$script")
            if [ -n "$s3_mtime" ] && [ "$s3_mtime" != "0" ] && [ "$local_mtime" != "0" ]; then
                if [ "$local_mtime" -gt "$s3_mtime" ]; then
                    NEWER_LOCAL_S3=$((NEWER_LOCAL_S3 + 1))
                    local_date=$(format_timestamp "$local_mtime")
                    s3_date=$(format_timestamp "$s3_mtime")
                    echo "  🆕 $script: LOCAL is newer (Local: $local_date, S3: $s3_date)"
                elif [ "$s3_mtime" -gt "$local_mtime" ]; then
                    NEWER_S3_LOCAL=$((NEWER_S3_LOCAL + 1))
                    local_date=$(format_timestamp "$local_mtime")
                    s3_date=$(format_timestamp "$s3_mtime")
                    echo "  🆕 $script: S3 is newer (Local: $local_date, S3: $s3_date)"
                else
                    echo "  ⚠️  $script: S3 differs from local (same timestamp but content differs)"
                fi
            else
                echo "  ⚠️  $script: S3 differs from local (could not compare timestamps)"
            fi
        fi
    fi
done

echo ""
echo "📈 Statistics:"
echo "  Local scripts checked: $TOTAL"
if [ "$USE_SSH" = true ]; then
    echo "  EC2 matches: $MATCH_EC2/$TOTAL"
    if [ $NEWER_LOCAL_EC2 -gt 0 ] || [ $NEWER_EC2_LOCAL -gt 0 ]; then
        echo "  Local newer than EC2: $NEWER_LOCAL_EC2 files"
        echo "  EC2 newer than Local: $NEWER_EC2_LOCAL files"
    fi
fi
echo "  S3 matches: $MATCH_S3/$TOTAL"
if [ $NEWER_LOCAL_S3 -gt 0 ] || [ $NEWER_S3_LOCAL -gt 0 ]; then
    echo "  Local newer than S3: $NEWER_LOCAL_S3 files"
    echo "  S3 newer than Local: $NEWER_S3_LOCAL files"
fi
echo ""

# List all files on EC2
if [ "$USE_SSH" = true ]; then
    echo "📁 Files on EC2 instance ($EC2_SCRIPT_DIR):"
    ssh -i "$EC2_SSH_KEY" -o StrictHostKeyChecking=no "$EC2_USER@$EC2_INSTANCE_IP" "ls -lh $EC2_SCRIPT_DIR 2>/dev/null || echo 'Directory not found'" | sed 's/^/   /' || echo "   Could not list files"
    echo ""
fi

# List all files in S3
echo "📁 Files in S3 (s3://$S3_BUCKET/$S3_SCRIPT_DIR/):"
aws s3 ls "s3://$S3_BUCKET/$S3_SCRIPT_DIR/" --region "$REGION" 2>/dev/null | sed 's/^/   /' || echo "   Could not list files"
echo ""

# Recommendations
echo "💡 Recommendations"
echo "=================="

if [ "$USE_SSH" = true ] && [ $NEWER_LOCAL_EC2 -gt 0 ]; then
    echo "🆕 $NEWER_LOCAL_EC2 local file(s) are newer than EC2 versions."
    echo "   Action: Upload local versions to EC2 to update remote scripts."
    echo "   Command: ./sync_scripts_to_ec2.sh"
    echo ""
fi

if [ "$USE_SSH" = true ] && [ $NEWER_EC2_LOCAL -gt 0 ]; then
    echo "🆕 $NEWER_EC2_LOCAL EC2 file(s) are newer than local versions."
    echo "   Action: Download from EC2 to update local scripts:"
    echo "   ssh -i $EC2_SSH_KEY $EC2_USER@$EC2_INSTANCE_IP \"cd $EC2_SCRIPT_DIR && cat script_name\" > script_name"
    echo ""
fi

if [ $NEWER_LOCAL_S3 -gt 0 ]; then
    echo "🆕 $NEWER_LOCAL_S3 local file(s) are newer than S3 versions."
    echo "   Action: Upload local versions to S3 to update remote scripts."
    echo "   Command: ./sync_scripts_to_ec2.sh"
    echo ""
fi

if [ $NEWER_S3_LOCAL -gt 0 ]; then
    echo "🆕 $NEWER_S3_LOCAL S3 file(s) are newer than local versions."
    echo "   Action: Download from S3 to update local scripts:"
    echo "   aws s3 cp s3://$S3_BUCKET/$S3_SCRIPT_DIR/script_name ./script_name --region $REGION"
    echo ""
fi

if [ "$USE_SSH" = true ] && [ $MATCH_EC2 -lt $TOTAL ] && [ $NEWER_LOCAL_EC2 -eq 0 ] && [ $NEWER_EC2_LOCAL -eq 0 ]; then
    echo "⚠️  Some scripts on EC2 differ from local versions (same timestamp or couldn't determine age)."
    echo "   To sync EC2 with local:"
    echo "   ./sync_scripts_to_ec2.sh"
    echo ""
fi

if [ $MATCH_S3 -lt $TOTAL ] && [ $NEWER_LOCAL_S3 -eq 0 ] && [ $NEWER_S3_LOCAL -eq 0 ]; then
    echo "⚠️  Some scripts in S3 differ from local versions (same timestamp or couldn't determine age)."
    echo "   To sync S3 with local:"
    echo "   ./sync_scripts_to_ec2.sh"
    echo ""
fi

if [ "$USE_SSH" = true ] && [ $MATCH_EC2 -eq $TOTAL ] && [ $MATCH_S3 -eq $TOTAL ]; then
    echo "✅ All scripts are in sync!"
    if [ $NEWER_LOCAL_EC2 -eq 0 ] && [ $NEWER_EC2_LOCAL -eq 0 ] && [ $NEWER_LOCAL_S3 -eq 0 ] && [ $NEWER_S3_LOCAL -eq 0 ]; then
        echo "   All versions match and timestamps are consistent."
    fi
fi

echo ""

# List saved diff files for review
DIFF_FILES=$(ls -1 "$TMP_DIR"/diff_*.patch 2>/dev/null | wc -l | tr -d ' ')
if [ "$DIFF_FILES" -gt 0 ]; then
    echo "📁 Saved Diff Files (for detailed review):"
    echo "=========================================="
    ls -lh "$TMP_DIR"/diff_*.patch 2>/dev/null | awk '{print "   " $9 " (" $5 ")"}' || true
    echo ""
    echo "💡 To view a diff file:"
    echo "   cat $TMP_DIR/diff_<filename>_<location>.patch"
    echo ""
    echo "💡 To see all changes in detail:"
    echo "   for f in $TMP_DIR/diff_*.patch; do echo \"=== \$f ===\"; cat \"\$f\"; done"
    echo ""
    echo "Note: Diff files are saved in temporary directory and will be cleaned up."
    echo "To keep them, copy them before the script exits:"
    echo "   cp $TMP_DIR/diff_*.patch ./diffs/"
    echo ""
fi

