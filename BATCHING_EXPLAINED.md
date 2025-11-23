# How Batching Works - Automatic vs Manual

## Short Answer

✅ **The script automatically batches emails to 50 at a time!**

You **do NOT need** to manually split your CSV file. You can provide one large CSV file with all 4000 emails, and the script will automatically split it into batches of 50.

---

## How It Works

### Automatic Batching

When you run:
```bash
./ec2_send_campaign.sh recipients.csv
# OR
python3 ses_emailer.py --recipients-file recipients.csv ...
```

**What happens:**
1. Script loads **entire CSV file** (all 4000 emails)
2. Script **automatically splits** into batches of 50
3. Script sends batches sequentially with rate limiting
4. You don't need to do anything!

**Example:**
```
Input: recipients.csv (4000 emails)
↓
Script automatically creates:
- Batch 1: emails 1-50
- Batch 2: emails 51-100
- Batch 3: emails 101-150
...
- Batch 80: emails 3951-4000
↓
Sends each batch with 0.1s delay between batches
```

---

## You Have Two Options

### Option 1: One Large File (Easiest)

**Use one CSV file with all emails:**
```bash
# Upload one large file
aws s3 cp recipients_all_4000.csv s3://amaze-aws-emailer/recipients/ --region us-west-2

# Send - script handles batching automatically
./ec2_send_custom.sh recipients_all_4000.csv email_template
```

**Benefits:**
- ✅ One file to manage
- ✅ Script handles everything
- ✅ No manual splitting needed

### Option 2: Pre-Split Files (What You Have Now)

**Use your existing batch files:**
```bash
# You already have:
# - recipients_batch_01.csv (150 emails)
# - recipients_batch_02.csv (150 emails)
# - recipients_batch_03.csv (150 emails)
# - recipients_batch_04.csv (12 emails)

# Send each batch
./ec2_send_campaign.sh 01  # Sends batch 01
./ec2_send_campaign.sh 02  # Sends batch 02
```

**Benefits:**
- ✅ More control over timing
- ✅ Can send batches on different days
- ✅ Easier to track which batch was sent
- ✅ Can pause/resume between batches

---

## How Automatic Batching Works

### Code Flow:

1. **Load entire file:**
   ```python
   recipients = load_recipients_from_file("recipients.csv")
   # Returns: [email1, email2, ..., email4000]
   ```

2. **Calculate batches:**
   ```python
   total_batches = (4000 + 50 - 1) // 50  # = 80 batches
   ```

3. **Split into batches:**
   ```python
   for batch_num in range(80):
       start_idx = batch_num * 50
       end_idx = min(start_idx + 50, 4000)
       batch_recipients = recipients[start_idx:end_idx]
       # Send this batch
   ```

4. **Send with rate limiting:**
   - Sends batch 1 (50 emails)
   - Waits 0.1 seconds
   - Sends batch 2 (50 emails)
   - Waits 0.1 seconds
   - ... and so on

---

## Current Settings

**Default batch size:** 50 emails per batch
**Rate limit:** 0.1 seconds between batches
**BCC enabled:** Yes (individual sends)

**For 4000 emails:**
- Automatically creates 80 batches
- Each batch: 50 emails
- Total time: ~13-15 minutes

---

## Can You Change Batch Size?

**Yes!** You can customize:

```bash
# Smaller batches (safer, slower)
python3 ses_emailer.py \
  --recipients-file recipients.csv \
  --batch-size 25 \
  --rate-limit 0.2 \
  ...

# Larger batches (faster, but watch SES limits)
python3 ses_emailer.py \
  --recipients-file recipients.csv \
  --batch-size 100 \
  --rate-limit 0.05 \
  ...
```

**But default (50) is recommended!**

---

## Your Current Setup

You have **pre-split files:**
- `recipients_batch_01.csv` (150 emails)
- `recipients_batch_02.csv` (150 emails)
- `recipients_batch_03.csv` (150 emails)
- `recipients_batch_04.csv` (12 emails)

**These will ALSO be automatically batched!**

When you send `recipients_batch_01.csv`:
- Script loads all 150 emails
- Automatically splits into 3 batches of 50
- Sends with rate limiting

---

## Recommendation

### For Your 4000 Emails:

**Option A: Use pre-split files (recommended for first campaign)**
```bash
# Send over 4 days (safer)
./ec2_send_campaign.sh 01  # Day 1
./ec2_send_campaign.sh 02  # Day 2
./ec2_send_campaign.sh 03  # Day 3
./ec2_send_campaign.sh 04  # Day 4
```

**Option B: Combine into one file**
```bash
# Combine all batches
cat recipients_batch_*.csv > recipients_all.csv
# Upload to S3
aws s3 cp recipients_all.csv s3://amaze-aws-emailer/recipients/ --region us-west-2
# Send all at once (script auto-batches)
./ec2_send_custom.sh recipients_all.csv email_template
```

---

## Summary

✅ **Script automatically batches to 50 at a time**
✅ **You don't need to manually split CSV files**
✅ **You can use one large file OR pre-split files**
✅ **Pre-split files are also automatically batched**

**Your current setup (pre-split files) is fine!** The script will still batch each file internally (150 emails → 3 batches of 50).

**Or you can combine them into one file** and let the script handle all the batching automatically.

---

## Quick Test

**Test with small file:**
```bash
# Create test file with 100 emails
# Script will automatically create 2 batches of 50
./ec2_send_custom.sh test_100_emails.csv email_template
```

You'll see output like:
```
📧 Batch Sending Configuration:
  Total recipients: 100
  Batch size: 50
  Total batches: 2
  ...
📦 Batch 1/2 (50 recipients)...
📦 Batch 2/2 (50 recipients)...
```

This confirms automatic batching is working!

