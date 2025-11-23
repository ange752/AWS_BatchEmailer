# How Batch Mode Works

## Overview

Batch mode automatically splits large recipient lists into smaller chunks and sends them with rate limiting to respect AWS SES limits and protect recipient privacy.

## When Batch Mode Activates

Batch mode is **automatically enabled** when:
- You have **more than 50 recipients** (default batch size)
- Or you explicitly set a smaller `--batch-size`

**Example:**
- 630 recipients → Automatically uses batch mode (13 batches of 50)
- 2 recipients → Uses individual sending (not batch mode)
- 100 recipients → Automatically uses batch mode (2 batches of 50)

## How It Works

### Step 1: Split Recipients into Batches

If you have 630 recipients with batch size 50:
- **Batch 1**: Recipients 1-50
- **Batch 2**: Recipients 51-100
- **Batch 3**: Recipients 101-150
- ... and so on
- **Batch 13**: Recipients 601-630 (last batch has 30 recipients)

### Step 2: Send Each Batch

For each batch, the script:

#### If BCC is Enabled (Default):
- Sends **individual emails** to each recipient in the batch
- Each recipient sees only their own email in the "To" field
- Rate limited to ~14 emails/second (0.07 seconds between emails)
- **Example**: Batch of 50 recipients = 50 separate API calls

#### If BCC is Disabled (`--no-bcc`):
- Sends **one email** to all recipients in the batch
- All recipients in that batch see each other's emails
- **Example**: Batch of 50 recipients = 1 API call

### Step 3: Rate Limiting Between Batches

After each batch completes:
- Waits `--rate-limit` seconds (default: 0.1 seconds)
- This prevents hitting AWS SES rate limits
- Default: 10 batches/second maximum

### Step 4: Progress Tracking

Shows real-time progress:
```
📦 Batch 1/13 (50 recipients)...
  ✓ Batch 1 sent successfully (50 emails)
📦 Batch 2/13 (50 recipients)...
  ✓ Batch 2 sent successfully (50 emails)
...
📊 Batch Sending Summary:
  Total: 630
  Successful: 630
  Failed: 0
  Success rate: 100.0%
```

## Example: Sending 630 Emails

### With Default Settings (BCC Enabled):

```bash
python3 ses_emailer.py \
  --sender studio_support@amaze.co \
  --sender-name "Amaze Software" \
  --recipients-file recipients.csv \
  --subject "Your Subject" \
  --body-file email_template.txt \
  --body-html-file email_template.html
```

**What happens:**
1. Detects 630 recipients > 50 → Activates batch mode
2. Creates 13 batches (12 batches of 50 + 1 batch of 30)
3. For each batch:
   - Sends 50 individual emails (one per recipient)
   - Each email takes ~0.07 seconds
   - Batch of 50 takes ~3.5 seconds
4. Waits 0.1 seconds between batches
5. **Total time**: ~45-50 seconds for all 630 emails

### With Custom Batch Size:

```bash
python3 ses_emailer.py \
  --sender studio_support@amaze.co \
  --sender-name "Amaze Software" \
  --recipients-file recipients.csv \
  --subject "Your Subject" \
  --body-file email_template.txt \
  --body-html-file email_template.html \
  --batch-size 100
```

**What happens:**
- Creates 7 batches (6 batches of 100 + 1 batch of 30)
- Faster overall, but larger batches

### With Slower Rate Limiting:

```bash
python3 ses_emailer.py \
  --sender studio_support@amaze.co \
  --sender-name "Amaze Software" \
  --recipients-file recipients.csv \
  --subject "Your Subject" \
  --body-file email_template.txt \
  --body-html-file email_template.html \
  --rate-limit 0.5
```

**What happens:**
- Waits 0.5 seconds between batches (slower, safer for rate limits)
- Better if you're hitting AWS SES throttling

## BCC Mode vs Non-BCC Mode

### BCC Mode (Default) - `--use-bcc`

**How it works:**
- Sends individual emails (one API call per recipient)
- Each recipient sees only their own email
- Protects privacy
- Slower (more API calls)

**Example with 50 recipients:**
- 50 separate emails sent
- Each recipient sees: `To: their-email@example.com`
- Takes ~3.5 seconds

### Non-BCC Mode - `--no-bcc`

**How it works:**
- Sends one email per batch with all recipients in To field
- All recipients in batch see each other's emails
- Faster (fewer API calls)
- Less privacy

**Example with 50 recipients:**
- 1 email sent to all 50
- Each recipient sees: `To: recipient1, recipient2, ..., recipient50`
- Takes ~0.1 seconds

## Rate Limiting Details

### Individual Email Rate (BCC Mode)
- **Delay**: 0.07 seconds between emails
- **Speed**: ~14 emails/second
- **AWS Limit**: Matches AWS SES default rate limit

### Batch Rate (Between Batches)
- **Default delay**: 0.1 seconds between batches
- **Default speed**: 10 batches/second
- **Customizable**: Use `--rate-limit` to adjust

### Example Timeline (630 emails, batch size 50, BCC mode):

```
Batch 1: 50 emails × 0.07s = 3.5 seconds
Wait: 0.1 seconds
Batch 2: 50 emails × 0.07s = 3.5 seconds
Wait: 0.1 seconds
...
Batch 13: 30 emails × 0.07s = 2.1 seconds

Total: ~45-50 seconds
```

## Benefits of Batch Mode

1. **Respects AWS Limits**: Stays within SES rate limits
2. **Error Recovery**: If one batch fails, others continue
3. **Progress Tracking**: See real-time progress
4. **Privacy Protection**: BCC mode hides recipient emails
5. **Scalable**: Handles any number of recipients

## Configuration Options

| Option | Default | Description |
|--------|---------|-------------|
| `--batch-size` | 50 | Recipients per batch |
| `--use-bcc` | True | Send individual emails for privacy |
| `--no-bcc` | - | Send to all recipients in batch (they see each other) |
| `--rate-limit` | 0.1 | Seconds to wait between batches |

## When to Adjust Settings

### Increase Batch Size (e.g., `--batch-size 100`)
- **When**: You have high SES rate limits
- **Benefit**: Faster sending
- **Trade-off**: Larger batches, more recipients see each other (if not using BCC)

### Decrease Batch Size (e.g., `--batch-size 25`)
- **When**: Hitting rate limits or want more granular control
- **Benefit**: More controlled sending
- **Trade-off**: More batches, slower overall

### Increase Rate Limit (e.g., `--rate-limit 0.5`)
- **When**: Getting throttling errors
- **Benefit**: Safer, less likely to hit limits
- **Trade-off**: Slower sending

### Decrease Rate Limit (e.g., `--rate-limit 0.05`)
- **When**: You have high SES limits and want faster sending
- **Benefit**: Faster sending
- **Trade-off**: Risk of hitting rate limits

## Summary

**Batch mode automatically:**
- Splits large lists into manageable chunks
- Sends with rate limiting
- Protects privacy (with BCC)
- Tracks progress
- Handles errors gracefully

**For your 630 emails:**
- Automatically uses batch mode
- Creates 13 batches of 50
- Sends individual emails (BCC mode)
- Takes ~45-50 seconds total
- Each recipient sees only their own email

