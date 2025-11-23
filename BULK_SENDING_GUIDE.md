# Bulk Sending Guide - 630 Emails

## Current Situation

Your `recipients.csv` has **630 email addresses**. Here's what you need to know:

## ⚠️ Important Issues with Current Script

The current script sends **all recipients in one API call**, which means:

1. **Privacy Issue**: All 630 recipients will see each other's email addresses in the "To:" field
2. **Rate Limiting**: AWS SES has rate limits that could cause failures
3. **No Error Recovery**: If one email fails, you lose track of which ones succeeded

## AWS SES Limits

### Sandbox Mode:
- **Daily limit**: 200 emails/day
- **Rate limit**: 1 email/second
- **For 630 emails**: Would take ~10.5 minutes minimum, but you'd hit daily limit

### Production Mode:
- **Daily limit**: 50,000 emails/day (default, can be increased)
- **Rate limit**: 14 emails/second (default, can be increased)
- **For 630 emails**: Would take ~45 seconds at max rate

## Recommended Approach: Send in Batches

### Option 1: Use BCC (Best for Privacy)

Send in batches of 50-100 with BCC to hide recipient emails:

```bash
# This would require modifying the script to use BCC
# Better to use Option 2 or 3
```

### Option 2: Send All at Once (If in Production Mode)

**If you're in production mode** and have sufficient limits:

```bash
python3 ses_emailer.py \
  --sender your-email@example.com \
  --recipients-file recipients.csv \
  --subject "Important update: Amaze Studio will shut down December 15th, 2025" \
  --body-file email_template.txt \
  --body-html-file email_template.html
```

**Pros:**
- Fast (one API call)
- Simple

**Cons:**
- All recipients see each other's emails (privacy issue)
- If rate limited, entire batch may fail
- Hard to track individual failures

### Option 3: Send in Batches (Recommended)

I can modify the script to:
- Send in batches (e.g., 50-100 at a time)
- Use BCC to protect privacy
- Handle rate limiting automatically
- Track successes/failures per batch
- Resume from where it left off if interrupted

## My Recommendation

**For 630 emails, I recommend:**

1. **If in Sandbox Mode**: 
   - You can only send 200/day
   - Split into 3-4 batches over multiple days
   - Or request production access first

2. **If in Production Mode**:
   - Send in batches of 50-100 emails
   - Use BCC to protect recipient privacy
   - Add rate limiting to respect AWS limits
   - Track progress

## Next Steps

Would you like me to:
1. **Modify the script** to send in batches with BCC and rate limiting?
2. **Create a batch script** that splits your CSV and sends in chunks?
3. **Check your SES status** to see if you're in sandbox or production mode?

Let me know which approach you prefer!

