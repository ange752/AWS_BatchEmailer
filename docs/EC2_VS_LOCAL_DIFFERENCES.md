# EC2 Scripts vs Local Scripts - Differences

This document explains what the scripts on the remote EC2 instance do that's different from local scripts.

## Summary

**EC2 scripts are wrapper scripts** that:
1. **Download from S3** (they don't use local files)
2. **Run on EC2** (not your local machine)
3. **Have one unique feature**: UTM parameter injection (in `ec2_send_custom.sh`)

The core functionality (`ses_emailer.py`) is **the same** - it's the same Python script on both local and EC2.

---

## Key Differences

### 1. **EC2 Scripts Download from S3 First**

**EC2 Scripts:**
```bash
# Downloads templates and recipients from S3
aws s3 cp s3://amaze-aws-emailer/recipients/$RECIPIENT_LIST /tmp/recipients.csv
aws s3 cp s3://amaze-aws-emailer/templates/${TEMPLATE_NAME}.txt /tmp/email_template.txt
aws s3 cp s3://amaze-aws-emailer/templates/${TEMPLATE_NAME}.html /tmp/email_template.html

# Then runs ses_emailer.py with downloaded files
python3 ses_emailer.py --recipients-file /tmp/recipients.csv ...
```

**Local Scripts:**
```bash
# Use local files directly
python3 ses_emailer.py --recipients-file ./recipients_batch_01.csv ...
```

### 2. **EC2 Scripts Run Remotely**

- **EC2**: Scripts run on AWS EC2 instance (remote server)
- **Local**: Scripts run on your local machine

This means:
- EC2 scripts have better network performance for large batches
- EC2 scripts can run unattended (you SSH in, start them, disconnect)
- EC2 scripts use IAM roles (no credentials needed)

### 3. **UTM Parameter Injection (Unique to EC2)**

**Only `ec2_send_custom.sh` has this feature** - it's NOT in local scripts!

```bash
# EC2 script can add UTM tracking parameters to all links
./ec2_send_custom.sh recipients.csv template "Subject" sender@email.com "Name" email newsletter campaign2025
```

This injects UTM parameters (`utm_source`, `utm_medium`, `utm_campaign`) into all links in the HTML template **on-the-fly** before sending emails.

**How it works:**
1. Downloads HTML template from S3
2. Uses Python regex to find all `href` links
3. Appends UTM parameters to each link
4. Saves modified HTML to `/tmp/`
5. Sends email with UTM-tracked links

**Local scripts do NOT do this** - you'd need to manually edit the HTML template first.

---

## Script-by-Script Comparison

### `ses_emailer.py`
- **Same on both**: This is the core Python script
- **Functionality**: Identical
- **Usage**: Same command-line arguments

### `ec2_send_campaign.sh` (EC2 Only)
**Purpose**: Simple campaign sender for EC2
- Downloads from S3
- Runs `ses_emailer.py`
- Hardcoded configuration

**Local equivalent**: You'd run `ses_emailer.py` directly with local files

### `ec2_send_custom.sh` (EC2 Only)
**Purpose**: Custom campaign sender with UTM tracking
- Downloads from S3
- **Injects UTM parameters** (UNIQUE FEATURE)
- Flexible parameters (subject, sender, template, etc.)
- Lists available templates/recipients from S3

**Local equivalent**: You'd need to manually:
1. Edit HTML template to add UTM parameters
2. Run `ses_emailer.py` with local files

### `ec2_send_all_batches.sh` (EC2 Only)
**Purpose**: Send to all batches sequentially
- Loops through batches 01-04
- Checks S3 for each batch
- Waits 30 seconds between batches
- Calls `ec2_send_campaign.sh` for each

**Local equivalent**: You'd manually run multiple commands:
```bash
python3 ses_emailer.py --recipients-file recipients_batch_01.csv ...
python3 ses_emailer.py --recipients-file recipients_batch_02.csv ...
# etc.
```

---

## Feature Comparison Table

| Feature | EC2 Scripts | Local Scripts |
|---------|-------------|---------------|
| Download from S3 | ✅ Yes | ❌ No |
| Use local files | ❌ No | ✅ Yes |
| UTM parameter injection | ✅ Yes (`ec2_send_custom.sh`) | ❌ No |
| List S3 templates/recipients | ✅ Yes | ❌ No |
| Run unattended | ✅ Yes | ❌ No |
| IAM role support | ✅ Yes | ⚠️ Requires credentials |
| Batch processing script | ✅ Yes (`ec2_send_all_batches.sh`) | ❌ No |
| Network performance | ✅ Better (AWS internal) | ⚠️ Depends on your connection |

---

## What EC2 Scripts Do Better

1. **UTM Tracking**: Automatically inject tracking parameters without editing templates
2. **S3 Integration**: Automatically discover and use templates/recipients from S3
3. **Batch Automation**: Send to multiple batches automatically with delays
4. **Better Performance**: Running on AWS means better network speed and reliability
5. **Unattended Operation**: Start a campaign and disconnect - it keeps running

---

## What Local Scripts Do Better

1. **Faster Iteration**: No need to upload to S3 first
2. **Testing**: Easier to test changes locally
3. **Development**: Edit scripts and test immediately
4. **No EC2 Costs**: Run on your machine (free)

---

## Recommendations

### Use EC2 Scripts When:
- ✅ Sending large campaigns (4000+ emails)
- ✅ Need UTM tracking parameters
- ✅ Want to run unattended
- ✅ Templates/recipients are in S3
- ✅ Need better reliability/performance

### Use Local Scripts When:
- ✅ Testing or developing
- ✅ Small batches (<1000 emails)
- ✅ Making rapid changes
- ✅ Templates/recipients are local
- ✅ Don't need UTM tracking

---

## Missing from Local Scripts

The only **unique functionality** in EC2 scripts that's NOT in local scripts is:

### 1. **UTM Parameter Injection** (`ec2_send_custom.sh`)
   - Automatically adds UTM parameters to all links in HTML
   - Uses Python regex to find and modify href attributes
   - Handles existing query strings properly
   - Skips mailto/tel/anchor links

### 2. **S3 Discovery** (`ec2_send_custom.sh`)
   - Lists available templates from S3
   - Lists available recipient lists from S3
   - Useful for discovering what's available

### 3. **Batch Automation** (`ec2_send_all_batches.sh`)
   - Automatically processes all batches
   - Handles missing batches gracefully
   - Adds delays between batches

---

## Conclusion

**EC2 scripts are mostly wrappers** that:
- Download from S3
- Run the same `ses_emailer.py`
- Add convenience features (UTM tracking, batch automation)

The core email sending functionality is **identical** - it's all `ses_emailer.py`.

The only **unique feature** you'd lose by using local scripts is **UTM parameter injection** - but you could add UTM parameters to your templates manually if needed.

