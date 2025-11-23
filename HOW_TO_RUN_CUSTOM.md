# How to Run Custom Campaigns

## Using ec2_send_custom.sh

The `ec2_send_custom.sh` script allows you to specify:
- Custom recipient list
- Custom template name
- Custom subject line

---

## Basic Usage

```bash
./ec2_send_custom.sh <recipient_list> [template_name] [subject]
```

---

## Examples

### Example 1: Custom Recipient List Only

```bash
./ec2_send_custom.sh my_custom_list.csv
```

- Uses: `my_custom_list.csv` as recipients
- Uses: `email_template` (default template)
- Uses: Default subject from config

---

### Example 2: Custom Recipient List + Template

```bash
./ec2_send_custom.sh my_custom_list.csv newsletter_template
```

- Uses: `my_custom_list.csv` as recipients
- Uses: `newsletter_template.txt` and `newsletter_template.html`
- Uses: Default subject from config

---

### Example 3: Custom Recipient List + Template + Subject

```bash
./ec2_send_custom.sh my_custom_list.csv newsletter_template "Special Offer - 50% Off!"
```

- Uses: `my_custom_list.csv` as recipients
- Uses: `newsletter_template.txt` and `newsletter_template.html`
- Uses: "Special Offer - 50% Off!" as subject

---

## Step-by-Step: Running Custom Campaign

### Step 1: Prepare Files in S3

**Upload recipient list:**
```bash
# From local machine
aws s3 cp my_custom_list.csv s3://amaze-aws-emailer/recipients/ --region us-west-2
```

**Upload custom template (if needed):**
```bash
# From local machine
aws s3 cp newsletter_template.txt s3://amaze-aws-emailer/templates/ --region us-west-2
aws s3 cp newsletter_template.html s3://amaze-aws-emailer/templates/ --region us-west-2
```

---

### Step 2: On EC2 Instance

**SSH into instance:**
```bash
ssh -i your-key.pem ec2-user@INSTANCE_IP
cd ~/emailer
```

**Run custom send:**
```bash
./ec2_send_custom.sh my_custom_list.csv newsletter_template "Custom Subject"
```

---

## List Available Options

To see available templates and recipient lists:

```bash
./ec2_send_custom.sh
```

This will show:
- Usage instructions
- Available templates in S3
- Available recipient lists in S3

---

## File Naming Requirements

### Templates
- Must be in S3: `s3://amaze-aws-emailer/templates/`
- Format: `{template_name}.txt` and `{template_name}.html`
- Examples:
  - `email_template.txt` / `email_template.html`
  - `newsletter_template.txt` / `newsletter_template.html`
  - `announcement.txt` / `announcement.html`

### Recipient Lists
- Must be in S3: `s3://amaze-aws-emailer/recipients/`
- Format: CSV file with `email` column
- Examples:
  - `recipients_batch_01.csv`
  - `my_custom_list.csv`
  - `vip_customers.csv`

---

## Common Use Cases

### Use Case 1: Different Template for Different Audience

```bash
# Send newsletter template to newsletter subscribers
./ec2_send_custom.sh newsletter_subscribers.csv newsletter_template

# Send announcement template to all users
./ec2_send_custom.sh all_users.csv announcement_template
```

### Use Case 2: A/B Testing

```bash
# Test variant A
./ec2_send_custom.sh test_group_a.csv email_template_variant_a "Subject A"

# Test variant B
./ec2_send_custom.sh test_group_b.csv email_template_variant_b "Subject B"
```

### Use Case 3: Time-Sensitive Campaigns

```bash
# Flash sale with custom subject
./ec2_send_custom.sh all_customers.csv sale_template "Flash Sale - Ends Today!"
```

### Use Case 4: Segmented Campaigns

```bash
# VIP customers
./ec2_send_custom.sh vip_customers.csv vip_template "Exclusive Offer"

# Regular customers
./ec2_send_custom.sh regular_customers.csv regular_template "Special Deal"
```

---

## Parameters Explained

| Parameter | Required | Description | Example |
|-----------|----------|-------------|---------|
| `recipient_list` | Yes | CSV file name in S3 | `my_list.csv` |
| `template_name` | No | Template name (no extension) | `newsletter_template` |
| `subject` | No | Email subject line | `"Special Offer!"` |

---

## What the Script Does

1. **Downloads files from S3:**
   - `s3://amaze-aws-emailer/recipients/{recipient_list}`
   - `s3://amaze-aws-emailer/templates/{template_name}.txt`
   - `s3://amaze-aws-emailer/templates/{template_name}.html`

2. **Sends emails:**
   - Uses `ses_emailer.py` to send
   - Batch size: 50
   - Uses BCC for privacy
   - Shows progress

3. **Shows results:**
   - Number of emails sent
   - Success/failure count
   - Any errors

---

## Troubleshooting

### Error: "File not found"
- Verify file exists in S3:
  ```bash
  aws s3 ls s3://amaze-aws-emailer/recipients/ --region us-west-2
  aws s3 ls s3://amaze-aws-emailer/templates/ --region us-west-2
  ```

### Error: "Template not found"
- Check template name matches exactly (case-sensitive)
- Verify both `.txt` and `.html` files exist
- Template name should NOT include extension

### Error: "Recipient list not found"
- Check file name matches exactly (case-sensitive)
- Verify file is in `recipients/` folder in S3
- File name should include `.csv` extension

---

## Quick Reference

```bash
# Basic (default template)
./ec2_send_custom.sh my_list.csv

# With custom template
./ec2_send_custom.sh my_list.csv newsletter_template

# With custom template and subject
./ec2_send_custom.sh my_list.csv newsletter_template "Custom Subject"

# List available options
./ec2_send_custom.sh
```

---

## Comparison with Other Scripts

| Script | Use Case | Flexibility |
|--------|----------|-------------|
| `ec2_send_campaign.sh` | Batch-based campaigns | Medium |
| `ec2_send_custom.sh` | Custom campaigns | High |
| `ec2_send_all_batches.sh` | Send all batches | Low |

---

## Summary

**To run custom campaign:**
1. Upload files to S3 (recipients, templates)
2. SSH into EC2 instance
3. Run: `./ec2_send_custom.sh <recipients> [template] [subject]`

**Example:**
```bash
./ec2_send_custom.sh my_list.csv newsletter_template "Special Offer!"
```

