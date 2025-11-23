#!/bin/bash
# Send emails to all batches sequentially
# Run this on EC2 to send to all recipient batches

set -e

BUCKET="amaze-aws-emailer"
REGION="us-west-2"

echo "📧 Sending to All Batches"
echo "========================="
echo ""

for batch in 01 02 03 04; do
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📦 Batch $batch"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Check if batch file exists in S3
    if aws s3 ls s3://$BUCKET/recipients/recipients_batch_$batch.csv --region $REGION &> /dev/null; then
        ./ec2_send_campaign.sh $batch
        echo ""
        echo "⏸️  Waiting 30 seconds before next batch..."
        sleep 30
        echo ""
    else
        echo "⚠️  Batch $batch not found in S3. Skipping..."
        echo ""
    fi
done

echo "✅ All batches complete!"

