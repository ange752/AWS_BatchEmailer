# EC2 Email Sender - Usage Examples

## Specifying Template and Recipient List

The EC2 send scripts now support specifying template names and recipient lists.

---

## Script 1: `ec2_send_campaign.sh` (Batch-based)

**Basic usage (uses defaults):**
```bash
./ec2_send_campaign.sh
# Uses: batch 01, email_template, recipients_batch_01.csv
```

**Specify batch number:**
```bash
./ec2_send_campaign.sh 02
# Uses: batch 02, email_template, recipients_batch_02.csv
```

**Specify batch and template:**
```bash
./ec2_send_campaign.sh 01 newsletter_template
# Uses: batch 01, newsletter_template, recipients_batch_01.csv
```

**Specify batch, template, and recipient list:**
```bash
./ec2_send_campaign.sh 01 newsletter_template custom_recipients.csv
# Uses: batch 01, newsletter_template, custom_recipients.csv
```

---

## Script 2: `ec2_send_custom.sh` (Flexible)

**Specify recipient list only:**
```bash
./ec2_send_custom.sh recipients_batch_01.csv
# Uses: email_template (default)
```

**Specify recipient list and template:**
```bash
./ec2_send_custom.sh recipients_batch_01.csv newsletter_template
# Uses: newsletter_template
```

**Specify recipient list, template, and subject:**
```bash
./ec2_send_custom.sh recipients_batch_01.csv newsletter_template "Special Offer!"
# Uses: newsletter_template with custom subject
```

**List available options:**
```bash
./ec2_send_custom.sh
# Shows usage and lists available templates/recipients in S3
```

---

## Examples

### Example 1: Send to batch 1 with default template
```bash
./ec2_send_campaign.sh 01
```

### Example 2: Send to custom list with newsletter template
```bash
./ec2_send_custom.sh my_custom_list.csv newsletter_template
```

### Example 3: Send to batch 2 with different template
```bash
./ec2_send_campaign.sh 02 announcement_template
```

### Example 4: Send with custom subject
```bash
./ec2_send_custom.sh recipients_batch_01.csv email_template "Important Update!"
```

---

## File Naming Convention

**Templates in S3:**
- `s3://amaze-aws-emailer/templates/{template_name}.txt`
- `s3://amaze-aws-emailer/templates/{template_name}.html`

**Recipient Lists in S3:**
- `s3://amaze-aws-emailer/recipients/{recipient_list}.csv`

**Examples:**
- Template: `email_template` → `email_template.txt` and `email_template.html`
- Template: `newsletter` → `newsletter.txt` and `newsletter.html`
- Recipients: `recipients_batch_01.csv`
- Recipients: `custom_list.csv`

---

## Quick Reference

| Script | Usage | When to Use |
|--------|-------|-------------|
| `ec2_send_campaign.sh` | `./ec2_send_campaign.sh [batch] [template] [recipients]` | Batch-based campaigns |
| `ec2_send_custom.sh` | `./ec2_send_custom.sh <recipients> [template] [subject]` | Custom/flexible campaigns |

---

## Notes

- All files must exist in S3 before running
- Template names should not include `.txt` or `.html` extension
- Recipient list names should include `.csv` extension
- Scripts will download files from S3 automatically

