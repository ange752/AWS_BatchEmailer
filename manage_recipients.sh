#!/bin/bash
# Script to manage recipient lists - clear and upload new ones

set -e

echo "📋 Recipient List Manager"
echo "========================="
echo ""

# Check if Lambda config exists
CONFIG_FILE="lambda_config.json"
if [ -f "$CONFIG_FILE" ]; then
    S3_BUCKET=$(python3 -c "import json; c=json.load(open('$CONFIG_FILE')); print(c.get('s3_bucket') or c.get('s3_buckets', {}).get('recipients', '') or c.get('s3_buckets', {}).get('templates', ''))" 2>/dev/null || echo "")
    REGION=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['region'])" 2>/dev/null || echo "us-west-2")
    
    if [ -n "$S3_BUCKET" ]; then
        echo "✅ Lambda configuration found"
        echo "   S3 Bucket: $S3_BUCKET"
        echo ""
    fi
fi

# Function to list current recipients
list_recipients() {
    echo "📂 Current recipient files (local):"
    echo "-----------------------------------"
    local count=0
    for file in recipients*.csv; do
        if [ -f "$file" ]; then
            email_count=$(tail -n +2 "$file" 2>/dev/null | wc -l | tr -d ' ')
            echo "  📄 $file ($email_count emails)"
            ((count++))
        fi
    done
    if [ $count -eq 0 ]; then
        echo "  (no recipient files found)"
    fi
    echo ""
    
    if [ -n "$S3_BUCKET" ]; then
        echo "☁️  Current recipient files (S3):"
        echo "-----------------------------------"
        aws s3 ls "s3://$S3_BUCKET/recipients/" --region $REGION 2>/dev/null | grep -E "\.csv$" | awk '{print "  📄 " $4 " (" $3 " bytes)"}' || echo "  (no files in S3)"
        echo ""
    fi
}

# Function to clear local recipients
clear_local() {
    echo "🗑️  Clearing local recipient files..."
    read -p "This will delete all recipients*.csv files. Continue? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -f recipients*.csv
        echo "✅ Local recipient files cleared"
    else
        echo "❌ Cancelled"
    fi
    echo ""
}

# Function to clear S3 recipients
clear_s3() {
    if [ -z "$S3_BUCKET" ]; then
        echo "❌ Lambda not configured. Run ./setup_lambda.sh first."
        return
    fi
    
    echo "🗑️  Clearing S3 recipient files..."
    read -p "This will delete all files in s3://$S3_BUCKET/recipients/. Continue? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        aws s3 rm "s3://$S3_BUCKET/recipients/" --recursive --region $REGION
        echo "✅ S3 recipient files cleared"
    else
        echo "❌ Cancelled"
    fi
    echo ""
}

# Function to upload new recipient file
upload_new() {
    if [ -z "$1" ]; then
        echo "📤 Upload New Recipient File"
        echo "----------------------------"
        read -p "Enter path to recipient CSV file: " file_path
        
        if [ ! -f "$file_path" ]; then
            echo "❌ File not found: $file_path"
            return
        fi
    else
        file_path="$1"
    fi
    
    filename=$(basename "$file_path")
    
    # Copy locally
    echo "📋 Copying to local directory..."
    cp "$file_path" "./$filename"
    echo "✅ Saved as: $filename"
    
    # Upload to S3 if configured
    if [ -n "$S3_BUCKET" ]; then
        echo "☁️  Uploading to S3..."
        aws s3 cp "$file_path" "s3://$S3_BUCKET/recipients/$filename" --region $REGION
        echo "✅ Uploaded to: s3://$S3_BUCKET/recipients/$filename"
    fi
    
    # Count emails
    email_count=$(tail -n +2 "$file_path" 2>/dev/null | wc -l | tr -d ' ')
    echo "✅ File ready: $filename ($email_count emails)"
    echo ""
}

# Function to split large file into batches
split_into_batches() {
    if [ -z "$1" ]; then
        echo "📦 Split Recipient File into Batches"
        echo "------------------------------------"
        read -p "Enter path to recipient CSV file: " file_path
        read -p "Emails per batch (default 150): " batch_size
        batch_size=${batch_size:-150}
    else
        file_path="$1"
        batch_size=${2:-150}
    fi
    
    if [ ! -f "$file_path" ]; then
        echo "❌ File not found: $file_path"
        return
    fi
    
    echo "📦 Splitting $file_path into batches of $batch_size..."
    
    # Get header
    header=$(head -1 "$file_path")
    
    # Count total emails (excluding header)
    total=$(tail -n +2 "$file_path" | wc -l | tr -d ' ')
    batches=$(( (total + batch_size - 1) / batch_size ))
    
    echo "  Total emails: $total"
    echo "  Creating $batches batch files..."
    
    # Split file
    tail -n +2 "$file_path" | split -l $batch_size - recipients_batch_
    
    # Add header to each batch and rename
    batch_num=1
    for file in recipients_batch_*; do
        if [ -f "$file" ]; then
            new_name=$(printf "recipients_batch_%02d.csv" $batch_num)
            echo "$header" > "$new_name"
            cat "$file" >> "$new_name"
            rm "$file"
            count=$(tail -n +2 "$new_name" | wc -l | tr -d ' ')
            echo "  ✅ Created: $new_name ($count emails)"
            ((batch_num++))
        fi
    done
    
    echo ""
    echo "✅ Created $((batch_num - 1)) batch files"
    
    # Upload to S3 if configured
    if [ -n "$S3_BUCKET" ]; then
        echo ""
        read -p "Upload batches to S3? (y/n) " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            for file in recipients_batch_*.csv; do
                if [ -f "$file" ]; then
                    aws s3 cp "$file" "s3://$S3_BUCKET/recipients/$file" --region $REGION
                    echo "  ✅ Uploaded: $file"
                fi
            done
        fi
    fi
    echo ""
}

# Main menu
show_menu() {
    echo "What would you like to do?"
    echo ""
    echo "1) List current recipient files"
    echo "2) Clear local recipient files"
    echo "3) Clear S3 recipient files"
    echo "4) Upload new recipient file"
    echo "5) Split file into batches"
    echo "6) Clear all (local + S3)"
    echo "7) Exit"
    echo ""
    read -p "Choose option (1-7): " choice
    
    case $choice in
        1)
            list_recipients
            show_menu
            ;;
        2)
            clear_local
            show_menu
            ;;
        3)
            clear_s3
            show_menu
            ;;
        4)
            upload_new
            show_menu
            ;;
        5)
            split_into_batches
            show_menu
            ;;
        6)
            clear_local
            clear_s3
            show_menu
            ;;
        7)
            echo "👋 Goodbye!"
            exit 0
            ;;
        *)
            echo "❌ Invalid option"
            show_menu
            ;;
    esac
}

# Check for command line arguments
if [ "$1" = "clear" ]; then
    if [ "$2" = "local" ]; then
        clear_local
    elif [ "$2" = "s3" ]; then
        clear_s3
    elif [ "$2" = "all" ]; then
        clear_local
        clear_s3
    else
        echo "Usage: $0 clear [local|s3|all]"
    fi
elif [ "$1" = "upload" ]; then
    upload_new "$2"
elif [ "$1" = "split" ]; then
    split_into_batches "$2" "$3"
elif [ "$1" = "list" ]; then
    list_recipients
else
    # Show menu
    list_recipients
    show_menu
fi

