# How to Specify Custom Sender in ec2_send_custom.sh

## Updated Usage

The `ec2_send_custom.sh` script now supports specifying the sender email address and sender name.

### Full Syntax

```bash
./ec2_send_custom.sh <recipient_list> [template_name] [subject] [sender_email] [sender_name]
```

---

## Examples

### Example 1: Default Sender (No Change)

```bash
./ec2_send_custom.sh recipients_batch_01.csv
```

- Uses default sender: `studio_support@amaze.co`
- Uses default sender name: `Amaze Software`

### Example 2: Custom Sender Email Only

```bash
./ec2_send_custom.sh recipients_batch_01.csv email_template "Subject" support@example.com
```

- Uses: `support@example.com` as sender
- Uses default sender name: `Amaze Software`
- Shows as: `Amaze Software <support@example.com>`

### Example 3: Custom Sender Email and Name

```bash
./ec2_send_custom.sh recipients_batch_01.csv email_template "Subject" support@example.com "Example Company"
```

- Uses: `support@example.com` as sender
- Uses: `Example Company` as sender name
- Shows as: `Example Company <support@example.com>`

### Example 4: All Parameters Custom

```bash
./ec2_send_custom.sh my_list.csv newsletter_template "Special Offer" marketing@company.com "Marketing Team"
```

- Recipients: `my_list.csv`
- Template: `newsletter_template`
- Subject: `Special Offer`
- Sender: `marketing@company.com`
- Sender name: `Marketing Team`
- Shows as: `Marketing Team <marketing@company.com>`

---

## Parameter Order

1. **recipient_list** (required) - CSV file name
2. **template_name** (optional) - Template name (default: `email_template`)
3. **subject** (optional) - Email subject (default: from config)
4. **sender_email** (optional) - Sender email (default: `studio_support@amaze.co`)
5. **sender_name** (optional) - Sender display name (default: `Amaze Software`)

---

## Important Notes

### Sender Email Must Be Verified

⚠️ **The sender email address MUST be verified in AWS SES before you can send from it!**

**Verify sender:**
```bash
# From local machine or EC2
aws ses verify-email-identity --email-address support@example.com --region us-west-2
```

**Check verification status:**
```bash
aws ses get-identity-verification-attributes \
  --identities support@example.com \
  --region us-west-2
```

### Sender Name

- The sender name is just a display name
- It appears in the "From" field as: `Sender Name <email@example.com>`
- Does not need to be verified (only the email does)

---

## Common Use Cases

### Use Case 1: Different Departments

```bash
# Marketing emails
./ec2_send_custom.sh marketing_list.csv newsletter_template "Newsletter" marketing@company.com "Marketing"

# Support emails
./ec2_send_custom.sh support_list.csv email_template "Support Update" support@company.com "Support Team"
```

### Use Case 2: Different Brands

```bash
# Brand A
./ec2_send_custom.sh brand_a_list.csv brand_a_template "Update" branda@company.com "Brand A"

# Brand B
./ec2_send_custom.sh brand_b_list.csv brand_b_template "Update" brandb@company.com "Brand B"
```

### Use Case 3: Testing Different Senders

```bash
# Test with different sender
./ec2_send_custom.sh test_list.csv email_template "Test" test@company.com "Test Account"
```

---

## Quick Reference

| Command | Sender Email | Sender Name |
|---------|--------------|-------------|
| `./ec2_send_custom.sh list.csv` | `studio_support@amaze.co` (default) | `Amaze Software` (default) |
| `./ec2_send_custom.sh list.csv template "Subject" support@example.com` | `support@example.com` | `Amaze Software` (default) |
| `./ec2_send_custom.sh list.csv template "Subject" support@example.com "Company"` | `support@example.com` | `Company` |

---

## Troubleshooting

### Error: "Email address not verified"

**Solution:**
```bash
# Verify the sender email first
aws ses verify-email-identity --email-address your-email@example.com --region us-west-2

# Wait for verification email and click link
# Then check status
aws ses get-identity-verification-attributes \
  --identities your-email@example.com \
  --region us-west-2
```

### Error: "Access Denied"

**Solution:**
- Check IAM role has SES permissions
- Verify sender email is verified
- Check region matches

---

## Summary

✅ **You can now specify sender email and name in the custom script!**

**Usage:**
```bash
./ec2_send_custom.sh <recipients> [template] [subject] [sender_email] [sender_name]
```

**Remember:**
- Sender email must be verified in SES
- Sender name is just for display
- Defaults are used if not specified

