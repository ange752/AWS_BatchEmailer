# UTM Parameters Guide

## What are UTM Parameters?

UTM (Urchin Tracking Module) parameters are tags you add to URLs to track where traffic comes from in Google Analytics. They help you measure the effectiveness of your email campaigns.

---

## How to Use UTM Parameters

### Basic Usage

```bash
./ec2_send_custom.sh <recipients> [template] [subject] [sender] [sender_name] [utm_source] [utm_medium] [utm_campaign]
```

### Examples

**Example 1: Basic UTM tracking**
```bash
./ec2_send_custom.sh recipients.csv black_friday_template "Subject" support@example.com "Company" email newsletter blackfriday2025
```

This will add to all links in the email:
```
?utm_source=email&utm_medium=newsletter&utm_campaign=blackfriday2025
```

**Example 2: Partial UTM (only source and campaign)**
```bash
./ec2_send_custom.sh recipients.csv black_friday_template "Subject" "" "" email "" blackfriday2025
```

**Example 3: Full parameters**
```bash
./ec2_send_custom.sh recipients.csv black_friday_template \
  "Want us to run Black Friday ads for you (on our budget)?" \
  studio_support@amaze.co \
  "Amaze Software" \
  email \
  newsletter \
  blackfriday2025
```

---

## UTM Parameter Details

### utm_source (Required for tracking)
**What it is:** The source of your traffic  
**Examples:**
- `email`
- `newsletter`
- `campaign`
- `promotion`

### utm_medium (Recommended)
**What it is:** The marketing medium  
**Examples:**
- `email`
- `newsletter`
- `cpc` (cost-per-click)
- `social`

### utm_campaign (Recommended)
**What it is:** The name of the campaign  
**Examples:**
- `blackfriday2025`
- `holiday_sale`
- `product_launch`
- `newsletter_weekly`

---

## How It Works

When you specify UTM parameters, the script:

1. **Downloads the HTML template** from S3
2. **Finds all links** in the HTML (href attributes)
3. **Adds UTM parameters** to each link
4. **Handles existing query strings** properly (uses `&` if `?` exists, `?` if not)
5. **Skips special links** (mailto:, tel:, anchors)

### Example Transformation

**Before:**
```html
<a href="https://amaze.co/products">View Products</a>
```

**After (with UTM):**
```html
<a href="https://amaze.co/products?utm_source=email&utm_medium=newsletter&utm_campaign=blackfriday2025">View Products</a>
```

**If link already has parameters:**
```html
<!-- Before -->
<a href="https://amaze.co/products?ref=email">View Products</a>

<!-- After -->
<a href="https://amaze.co/products?ref=email&utm_source=email&utm_medium=newsletter&utm_campaign=blackfriday2025">View Products</a>
```

---

## Parameter Order

When using UTM parameters, you must provide parameters in order:

1. `recipient_list` (required)
2. `template_name` (optional)
3. `subject` (optional)
4. `sender_email` (optional)
5. `sender_name` (optional)
6. `utm_source` (optional)
7. `utm_medium` (optional)
8. `utm_campaign` (optional)

**To skip parameters but include UTM:**
```bash
# Use empty strings for parameters you want to skip
./ec2_send_custom.sh recipients.csv black_friday_template "" "" "" email newsletter blackfriday2025
```

---

## Best Practices

### 1. Use Consistent Naming
- Use lowercase
- Use underscores, not spaces
- Be descriptive but concise

### 2. Standard Values
- **utm_source:** `email` (for all email campaigns)
- **utm_medium:** `newsletter`, `promotional`, `transactional`
- **utm_campaign:** Specific campaign name (e.g., `blackfriday2025`)

### 3. Track Different Campaigns
```bash
# Black Friday campaign
./ec2_send_custom.sh ... email newsletter blackfriday2025

# Holiday campaign
./ec2_send_custom.sh ... email newsletter holiday2025

# Product launch
./ec2_send_custom.sh ... email newsletter product_launch_2025
```

---

## Viewing Results in Google Analytics

After sending emails with UTM parameters:

1. Go to Google Analytics
2. Navigate to **Acquisition** → **All Traffic** → **Source/Medium**
3. Look for entries like:
   - `email / newsletter`
   - `email / promotional`
4. Click to see campaign details

---

## Common UTM Combinations

| Campaign Type | utm_source | utm_medium | utm_campaign |
|---------------|------------|------------|--------------|
| Newsletter | `email` | `newsletter` | `weekly_newsletter` |
| Promotional | `email` | `promotional` | `blackfriday2025` |
| Transactional | `email` | `transactional` | `order_confirmation` |
| Announcement | `email` | `announcement` | `product_launch` |

---

## Troubleshooting

### UTM parameters not appearing in links

**Check:**
1. Verify parameters were provided correctly
2. Check script output for "✅ UTM parameters added"
3. Preview email to verify links have UTM parameters

### Links broken after adding UTM

**Solution:**
- Script handles existing query strings properly
- Special links (mailto:, tel:) are skipped
- If issues occur, check HTML template for malformed links

---

## Examples

### Example 1: Black Friday Campaign
```bash
./ec2_send_custom.sh recipients_batch_01.csv \
  black_friday_template \
  "Want us to run Black Friday ads for you (on our budget)?" \
  studio_support@amaze.co \
  "Amaze Software" \
  email \
  newsletter \
  blackfriday2025
```

### Example 2: Weekly Newsletter
```bash
./ec2_send_custom.sh newsletter_subscribers.csv \
  newsletter_template \
  "Weekly Newsletter - Week 47" \
  newsletter@amaze.co \
  "Amaze Newsletter" \
  email \
  newsletter \
  weekly_newsletter_47
```

### Example 3: Product Announcement
```bash
./ec2_send_custom.sh all_users.csv \
  announcement_template \
  "New Feature Launch!" \
  announcements@amaze.co \
  "Amaze Team" \
  email \
  promotional \
  product_launch_nov2025
```

---

## Summary

✅ **UTM parameters are automatically added to all links in HTML emails**  
✅ **Works with existing query strings**  
✅ **Skips special links (mailto:, tel:, anchors)**  
✅ **Easy to track campaign performance in Google Analytics**

**Quick command:**
```bash
./ec2_send_custom.sh recipients.csv template "Subject" sender@example.com "Name" email newsletter campaign_name
```

