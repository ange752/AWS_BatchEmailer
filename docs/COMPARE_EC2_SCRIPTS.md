# Compare and Sync EC2 Scripts

This guide explains how to check if scripts on your EC2 instance match your local versions, and how to sync them if needed.

## Quick Start

### Compare Scripts

```bash
./compare_ec2_scripts.sh
```

This will:
- Connect to your EC2 instance via SSH
- Download scripts from EC2 and S3
- Compare them with your local versions
- Show differences if any
- List all files on EC2 and in S3

### Sync Scripts

If scripts differ, sync them:

```bash
./sync_scripts_to_ec2.sh
```

This will:
- Upload local scripts to S3
- Upload local scripts to EC2 instance
- Make scripts executable on EC2

## Configuration

Both scripts use these default values (from `ec2_setup_instructions.txt`):

- **EC2 Instance IP**: `54.189.152.124`
- **SSH Key**: `oasis-dev-20220131.pem`
- **EC2 User**: `ec2-user`
- **EC2 Script Directory**: `~/emailer`
- **S3 Bucket**: `amaze-aws-emailer`
- **S3 Script Directory**: `scripts`
- **Region**: `us-west-2`

### Override Defaults

You can override defaults using environment variables:

```bash
# Custom EC2 instance
EC2_INSTANCE_IP="1.2.3.4" \
EC2_SSH_KEY="my-key.pem" \
./compare_ec2_scripts.sh

# Custom S3 location
S3_BUCKET="my-bucket" \
S3_SCRIPT_DIR="my-scripts" \
./compare_ec2_scripts.sh
```

## What Gets Compared

The scripts compare these files:

- `ses_emailer.py` - Main email sending script
- `ec2_send_campaign.sh` - Campaign sender script
- `ec2_send_custom.sh` - Custom campaign sender
- `ec2_send_all_batches.sh` - Batch sender script
- `lambda_handler.py` - Lambda function handler

## Example Output

```
🔍 Comparing Local Scripts with EC2 Instance
=============================================

Configuration:
  EC2 Instance: ec2-user@54.189.152.124
  SSH Key: oasis-dev-20220131.pem
  EC2 Script Directory: ~/emailer
  Local Directory: /Users/angela/Dev/AWS_BatchEmailer
  S3 Bucket: s3://amaze-aws-emailer/scripts/

📋 Scripts to Compare:
  - ses_emailer.py
  - ec2_send_campaign.sh
  - ec2_send_custom.sh
  - ec2_send_all_batches.sh
  - lambda_handler.py

📥 Downloading scripts from EC2 instance...
  ✅ Downloaded ses_emailer.py from EC2
  ✅ Downloaded ec2_send_campaign.sh from EC2
  ...

📥 Downloading scripts from S3...
  ✅ Downloaded ses_emailer.py from S3
  ...

🔍 Comparing Files...
====================

📄 ses_emailer.py
==========================================
   Local: ✅ 1242 lines, 45K
          📅 Modified: 2025-01-15 14:30:22
   EC2:   ❌ DIFFERENT (1240 lines)
          📅 Modified: 2025-01-15 10:15:30
          🆕 Local is newer by 4h 14m
          📊 Change Summary vs EC2:
            + 15 lines added
            - 13 lines removed
            📈 Net: +2 lines (file grew)
          🔍 Key Changes:
            ➕ Added: def send_email_with_attachments(
            ➖ Removed: # Old function comment
          ⚙️  Configuration changes:
               + REGION="${REGION:-us-west-2}"
               - REGION="us-west-2"
          📝 Sample Code Changes (unified diff):
            + def send_email_with_attachments(self,
            +     sender: str,
            +     recipients: List[str],
            - # Old function removed
          📍 Change locations:
            @@ -100,5 +120,15 @@
          💾 Full diff saved: /tmp/diff_ses_emailer_py_EC2.patch

📄 ec2_send_campaign.sh
==========================================
   Local: ✅ 67 lines, 2.1K
          📅 Modified: 2025-01-15 12:00:00
   EC2:   ✅ MATCH (67 lines)
          📅 Modified: 2025-01-15 12:00:00
          ⏰ Same timestamp
   S3:    ✅ MATCH (67 lines)
          📅 Modified: 2025-01-15 12:00:00
          ⏰ Same timestamp

📊 Summary
==========
📋 Version Comparison Summary:
  🆕 ses_emailer.py: LOCAL is newer (Local: 2025-01-15 14:30:22, EC2: 2025-01-15 10:15:30)
  ✅ ec2_send_campaign.sh: EC2 matches local
  ✅ ec2_send_custom.sh: S3 matches local

📈 Statistics:
  Local scripts checked: 5
  EC2 matches: 4/5
  Local newer than EC2: 1 files
  S3 matches: 5/5

📁 Saved Diff Files (for detailed review):
==========================================
   /tmp/diff_ses_emailer_py_EC2.patch (2.5K)
   /tmp/diff_ec2_send_custom_sh_S3.patch (1.2K)
```

## Troubleshooting

### SSH Connection Failed

If you can't connect via SSH:

1. **Check instance is running:**
   ```bash
   aws ec2 describe-instances --instance-ids i-0462951dc6f221468 --region us-west-2
   ```

2. **Check SSH key permissions:**
   ```bash
   chmod 400 oasis-dev-20220131.pem
   ```

3. **Test SSH manually:**
   ```bash
   ssh -i oasis-dev-20220131.pem ec2-user@54.189.152.124
   ```

### Scripts Not Found on EC2

If scripts aren't found on EC2:

1. **Check if directory exists:**
   ```bash
   ssh -i oasis-dev-20220131.pem ec2-user@54.189.152.124 "ls -la ~/emailer"
   ```

2. **Download from S3:**
   ```bash
   ssh -i oasis-dev-20220131.pem ec2-user@54.189.152.124
   cd ~/emailer
   aws s3 sync s3://amaze-aws-emailer/scripts/ . --region us-west-2
   ```

### AWS CLI Not Configured

If you get AWS CLI errors:

1. **Configure AWS CLI:**
   ```bash
   aws configure
   ```

2. **Or use IAM role on EC2** (no credentials needed)

## Workflow

### Regular Check

```bash
# 1. Compare scripts
./compare_ec2_scripts.sh

# 2. If differences found, sync
./sync_scripts_to_ec2.sh

# 3. Verify sync
./compare_ec2_scripts.sh
```

### After Making Changes

```bash
# 1. Make changes to local scripts
# ... edit files ...

# 2. Sync to EC2 and S3
./sync_scripts_to_ec2.sh

# 3. Test on EC2
ssh -i oasis-dev-20220131.pem ec2-user@54.189.152.124
cd ~/emailer
./ec2_send_campaign.sh
```

## Alternative: Manual Comparison

If you prefer to compare manually:

### Check Files on EC2

```bash
ssh -i oasis-dev-20220131.pem ec2-user@54.189.152.124 "ls -lh ~/emailer"
```

### Download from EC2

```bash
scp -i oasis-dev-20220131.pem ec2-user@54.189.152.124:~/emailer/ses_emailer.py ./ses_emailer.py.ec2
diff ses_emailer.py ses_emailer.py.ec2
```

### Check Files in S3

```bash
aws s3 ls s3://amaze-aws-emailer/scripts/ --region us-west-2
```

### Download from S3

```bash
aws s3 cp s3://amaze-aws-emailer/scripts/ses_emailer.py ./ses_emailer.py.s3 --region us-west-2
diff ses_emailer.py ses_emailer.py.s3
```

## Tips

1. **Always compare before syncing** - Make sure you want to overwrite remote versions
2. **Backup remote scripts** - If you're unsure, download remote versions first
3. **Test after syncing** - Verify scripts work on EC2 after syncing
4. **Use version control** - Keep scripts in Git for better tracking

## Related Scripts

- `compare_ec2_scripts.sh` - Compare local vs remote scripts
- `sync_scripts_to_ec2.sh` - Sync local scripts to remote
- `setup_ec2.sh` - Initial EC2 setup
- `test_ec2_setup.sh` - Test EC2 setup

