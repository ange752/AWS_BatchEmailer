# Avoiding Blacklisting with 4000+ Emails

## How the System Protects You

### 1. **Batch Processing**
- Automatically splits 4000 emails into batches of 50
- Sends batches sequentially (not all at once)
- Prevents overwhelming recipient servers

### 2. **Rate Limiting**
- Default: 0.1 seconds between batches (10 batches/second)
- For 4000 emails: ~80 batches × 0.1s = 8 seconds minimum delay
- Actual time: ~10-15 minutes total (respects SES limits)

### 3. **BCC Privacy**
- Each recipient gets individual email
- Recipients can't see each other
- Reduces spam complaints

### 4. **AWS SES Built-in Protection**
- SES has built-in rate limiting
- Respects AWS sending quotas
- Monitors bounce/complaint rates

---

## Current Settings

### Batch Configuration
- **Batch size:** 50 emails per batch
- **Rate limit:** 0.1 seconds between batches
- **BCC enabled:** Yes (individual sends)
- **Total batches for 4000 emails:** 80 batches

### Timing Calculation
```
4000 emails ÷ 50 per batch = 80 batches
80 batches × 0.1s delay = 8 seconds (just delays)
80 batches × ~10 seconds per batch = ~13 minutes total
```

---

## AWS SES Limits

### Sandbox Mode
- **Sending rate:** 1 email/second
- **Daily limit:** 200 emails
- **⚠️ Not suitable for 4000 emails**

### Production Mode (Request Access)
- **Sending rate:** 14 emails/second (default, can request increase)
- **Daily limit:** Based on your sending quota
- **✅ Suitable for 4000 emails**

**For 4000 emails, you MUST be in production mode!**

---

## Best Practices to Avoid Blacklisting

### 1. **Warm Up Your Sending Reputation**

**First campaign:**
- Start with small batches (100-200 emails)
- Monitor bounce/complaint rates
- Gradually increase volume

**Recommended progression:**
- Week 1: 200 emails/day
- Week 2: 500 emails/day
- Week 3: 1000 emails/day
- Week 4: 2000+ emails/day

### 2. **Monitor Metrics**

**Check regularly:**
```bash
# Check bounce rate
aws ses get-send-statistics --region us-west-2

# Check complaint rate
aws ses get-account-sending-enabled --region us-west-2
```

**Target metrics:**
- Bounce rate: < 5%
- Complaint rate: < 0.1%
- If higher, reduce sending volume

### 3. **Use BCC (Already Enabled)**

✅ **Current setting:** `--use-bcc` (default)
- Each recipient gets individual email
- Protects recipient privacy
- Reduces spam complaints

### 4. **Verify Sender Email**

✅ **Required:** Sender email must be verified in SES
```bash
# Verify sender
aws ses verify-email-identity --email-address studio_support@amaze.co --region us-west-2
```

### 5. **Clean Recipient Lists**

- Remove invalid email addresses
- Remove bounced emails
- Remove unsubscribed emails
- Use `recipients.valids.csv` (already filtered)

### 6. **Include Unsubscribe Link**

✅ **Already in templates:** Unsubscribe links should be in your email templates

### 7. **Respect Sending Windows**

- Avoid sending during off-hours (2-6 AM recipient time)
- Spread sends across multiple days if possible
- Don't send all 4000 at once

---

## Recommended Approach for 4000 Emails

### Option 1: Spread Over Multiple Days (Safest)

**Day 1:**
```bash
./ec2_send_campaign.sh 01  # 150 emails
./ec2_send_campaign.sh 02  # 150 emails
```

**Day 2:**
```bash
./ec2_send_campaign.sh 03  # 150 emails
./ec2_send_campaign.sh 04  # 12 emails
```

**Benefits:**
- Gradual reputation building
- Lower risk of blacklisting
- Better deliverability

### Option 2: Send All at Once (Faster)

**Single command:**
```bash
./ec2_send_all_batches.sh
```

**Timeline:**
- 80 batches × ~10 seconds = ~13 minutes
- All emails sent in one session
- Higher risk if reputation is new

**Use this if:**
- You have established sending reputation
- You've sent successfully before
- Bounce/complaint rates are low

---

## Adjusting Rate Limits

### For Slower Sending (Safer)

```bash
# Edit ec2_send_campaign.sh or use ses_emailer.py directly
python3 ses_emailer.py \
  --sender studio_support@amaze.co \
  --recipients-file recipients.csv \
  --subject "Campaign" \
  --body-file email_template.txt \
  --batch-size 25 \        # Smaller batches
  --rate-limit 0.5 \       # Slower (2 batches/second)
  --use-bcc
```

### For Faster Sending (If Reputation is Good)

```bash
python3 ses_emailer.py \
  --batch-size 100 \       # Larger batches
  --rate-limit 0.05 \     # Faster (20 batches/second)
  --use-bcc
```

**⚠️ Don't exceed AWS SES limits!**

---

## Monitoring and Alerts

### Set Up CloudWatch Alarms

```bash
# Monitor bounce rate
aws cloudwatch put-metric-alarm \
  --alarm-name ses-bounce-rate \
  --alarm-description "Alert if bounce rate > 5%" \
  --metric-name Bounce \
  --namespace AWS/SES \
  --statistic Sum \
  --period 300 \
  --threshold 5 \
  --comparison-operator GreaterThanThreshold

# Monitor complaint rate
aws cloudwatch put-metric-alarm \
  --alarm-name ses-complaint-rate \
  --alarm-description "Alert if complaint rate > 0.1%" \
  --metric-name Complaint \
  --namespace AWS/SES \
  --statistic Sum \
  --period 300 \
  --threshold 0.1 \
  --comparison-operator GreaterThanThreshold
```

---

## What Happens If You Get Blacklisted?

### Signs of Blacklisting:
- High bounce rates (> 10%)
- High complaint rates (> 0.5%)
- Emails not being delivered
- SES account in danger of suspension

### Recovery Steps:
1. **Stop sending immediately**
2. **Review and clean recipient list**
3. **Remove bounced/complained emails**
4. **Wait 24-48 hours**
5. **Resume with smaller volume**
6. **Monitor closely**

---

## Recommended Settings for 4000 Emails

### Safe Configuration:
```bash
--batch-size 50          # Standard batch size
--rate-limit 0.1        # 10 batches/second
--use-bcc               # Privacy protection
```

### Timeline:
- **Batches:** 80 batches
- **Delay time:** 8 seconds
- **Send time:** ~13 minutes
- **Total time:** ~13-15 minutes

### Spread Over Days (Safest):
- **Day 1:** Batches 1-2 (300 emails)
- **Day 2:** Batches 3-4 (162 emails)
- **Or:** 2 batches per day for 4 days

---

## Checklist Before Sending 4000 Emails

- [ ] ✅ AWS SES in production mode (not sandbox)
- [ ] ✅ Sender email verified
- [ ] ✅ Recipient list cleaned (valid emails only)
- [ ] ✅ BCC enabled (privacy protection)
- [ ] ✅ Unsubscribe link in email template
- [ ] ✅ Tested with small batch first
- [ ] ✅ Monitoring bounce/complaint rates
- [ ] ✅ Rate limiting configured (0.1s default)
- [ ] ✅ Batch size appropriate (50 default)

---

## Summary

**Current system handles 4000 emails by:**
1. ✅ Splitting into 80 batches of 50
2. ✅ Rate limiting (0.1s between batches)
3. ✅ Using BCC for privacy
4. ✅ Respecting AWS SES limits
5. ✅ Individual sends (not bulk)

**To avoid blacklisting:**
1. ✅ Use production SES mode
2. ✅ Clean recipient lists
3. ✅ Monitor metrics
4. ✅ Start small, scale up
5. ✅ Include unsubscribe links
6. ✅ Spread sends over time (optional)

**For 4000 emails:**
- Current settings are safe
- Takes ~13-15 minutes
- Consider spreading over 2-4 days for first campaign
- Monitor bounce/complaint rates

---

## Quick Commands

**Check SES status:**
```bash
aws ses get-account-sending-enabled --region us-west-2
aws ses get-send-quota --region us-west-2
```

**Check sending statistics:**
```bash
aws ses get-send-statistics --region us-west-2
```

**Send with current safe settings:**
```bash
./ec2_send_all_batches.sh  # All at once
# OR
./ec2_send_campaign.sh 01   # One batch at a time
```

