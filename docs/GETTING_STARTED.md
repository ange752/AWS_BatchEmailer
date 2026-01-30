# Getting Started - Making Your Email Sender Live

Follow these steps to send emails using AWS SES.

## Step 1: Set Up AWS Account & Credentials

### 1.1 Install AWS CLI (if not already installed)
```bash
# On macOS
brew install awscli

# Or download from: https://aws.amazon.com/cli/
```

### 1.2 Configure AWS Credentials
```bash
aws configure
```

You'll be prompted for:
- **AWS Access Key ID**: Get this from AWS IAM Console
- **AWS Secret Access Key**: Get this from AWS IAM Console
- **Default region**: e.g., `us-east-1` (must match where you verify emails)
- **Default output format**: `json` (recommended)

**Where to get AWS credentials:**
1. Go to AWS Console → IAM → Users
2. Create a new user or select existing user
3. Go to "Security credentials" tab
4. Create "Access key" → Choose "Application running outside AWS"
5. Copy the Access Key ID and Secret Access Key

**Important:** The IAM user needs SES permissions. Attach the `AmazonSESFullAccess` policy or create a custom policy with SES send permissions.

## Step 2: Verify Your Email Address in AWS SES

### 2.1 Go to AWS SES Console
1. Log into AWS Console
2. Navigate to **Simple Email Service (SES)**
3. Make sure you're in the correct region (e.g., `us-east-1`)

### 2.2 Verify Your Sender Email
**Option A: Using the Script**
```bash
python ses_emailer.py --verify your-email@example.com --region us-east-1
```

**Option B: Using AWS Console**
1. In SES Console, click "Verified identities"
2. Click "Create identity"
3. Choose "Email address"
4. Enter your email address
5. Click "Create identity"
6. Check your email inbox for verification email
7. Click the verification link

### 2.3 Check Your SES Account Status
- **Sandbox Mode**: You can only send to verified email addresses (200 emails/day limit)
- **Production Mode**: You can send to any email address (higher limits)

**To request production access:**
1. In SES Console → Account dashboard
2. Click "Request production access"
3. Fill out the form explaining your use case
4. Wait for approval (usually 24-48 hours)

## Step 3: Prepare Your Email Files

Your templates are ready:
- ✅ `email_template.txt` - Plain text version
- ✅ `email_template.html` - HTML version
- ✅ `test_recipients.csv` - Test recipients (ange752@gmail.com, islington73@gmail.com)

## Step 4: Test with Preview (Recommended)

Before sending, preview your email:
```bash
python ses_emailer.py \
  --sender your-verified-email@example.com \
  --recipients-file test_recipients.csv \
  --subject "Important update: Amaze Studio will shut down December 15th, 2025" \
  --body-file email_template.txt \
  --body-html-file email_template.html \
  --preview
```

This shows you how the email will look **without sending it**.

## Step 5: Send Your First Email

### Test Email (Send to Yourself First)
```bash
python ses_emailer.py \
  --sender your-verified-email@example.com \
  --recipients your-email@example.com \
  --subject "Important update: Amaze Studio will shut down December 15th, 2025" \
  --body-file email_template.txt \
  --body-html-file email_template.html
```

### Send to Your Test Recipients
```bash
python ses_emailer.py \
  --sender your-verified-email@example.com \
  --recipients-file test_recipients.csv \
  --subject "Important update: Amaze Studio will shut down December 15th, 2025" \
  --body-file email_template.txt \
  --body-html-file email_template.html
```

## Step 6: Send to Full List

Once you've tested successfully, send to your full recipient list:

```bash
python ses_emailer.py \
  --sender your-verified-email@example.com \
  --recipients-file your-full-list.csv \
  --subject "Important update: Amaze Studio will shut down December 15th, 2025" \
  --body-file email_template.txt \
  --body-html-file email_template.html
```

## Troubleshooting

### Error: "MessageRejected"
- **Solution**: Your sender email is not verified. Verify it in SES Console.

### Error: "MailFromDomainNotVerified"
- **Solution**: If using a custom domain, verify the domain in SES.

### Error: "AccountSendingPaused"
- **Solution**: Your account is in sandbox mode or paused. Check SES Console.

### Error: "Throttling"
- **Solution**: You're sending too fast. AWS SES has rate limits. Wait a bit and try again.

### Error: "Access Denied" or Credentials Error
- **Solution**: 
  1. Check your AWS credentials: `aws configure list`
  2. Verify IAM user has SES permissions
  3. Make sure you're using the correct region

## Quick Checklist

Before sending:
- [ ] AWS credentials configured (`aws configure`)
- [ ] Sender email verified in SES
- [ ] Recipients verified (if in sandbox mode)
- [ ] Email templates ready (`email_template.txt` and `email_template.html`)
- [ ] Tested with preview (`--preview` flag)
- [ ] Sent test email to yourself first
- [ ] Subject line finalized

## Next Steps

1. **Monitor sending**: Check SES Console → Sending statistics
2. **Handle bounces**: Set up SNS notifications for bounces/complaints
3. **Request production access**: If you need to send to unverified addresses
4. **Scale up**: Request sending limit increases if needed

## Example Full Command

```bash
python ses_emailer.py \
  --sender your-email@example.com \
  --recipients-file test_recipients.csv \
  --subject "Important update: Amaze Studio will shut down December 15th, 2025" \
  --body-file email_template.txt \
  --body-html-file email_template.html \
  --region us-east-1
```

Replace `your-email@example.com` with your verified sender email address.

