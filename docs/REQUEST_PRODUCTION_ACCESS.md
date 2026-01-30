# How to Request Production Access (Disable Sandbox Mode)

## Step-by-Step Guide

### Step 1: Log into AWS Console
1. Go to https://console.aws.amazon.com/
2. Sign in with your AWS account

### Step 2: Navigate to SES Console
1. In the AWS Console, search for "SES" or "Simple Email Service"
2. Click on **Simple Email Service**
3. Make sure you're in the correct region (e.g., `us-east-1`, `us-west-2`, etc.)

### Step 3: Go to Account Dashboard
1. In the left sidebar, click on **Account dashboard**
2. You'll see your current account status

### Step 4: Request Production Access
1. Look for a section that says **"Account status"** or **"Sending limits"**
2. You should see a button or link that says:
   - **"Request production access"**
   - **"Move out of the Amazon SES sandbox"**
   - **"Request sending quota increase"**
3. Click on that button/link

### Step 5: Fill Out the Request Form

You'll need to provide:

1. **Mail Type** (choose one):
   - Transactional
   - Marketing
   - Both

2. **Website URL**:
   - Your website URL (if applicable)
   - For Amaze Studio, you might use: `amaze.co` or your company website

3. **Use Case Description**:
   - Explain what you'll be using SES for
   - Example: "Sending important service notifications to users about platform changes and updates"

4. **How you plan to handle bounces and complaints**:
   - Example: "We will monitor bounce and complaint rates through AWS SES metrics and SNS notifications. We will remove invalid email addresses from our list and investigate any complaints promptly."

5. **Expected sending volume**:
   - Daily sending volume (e.g., "100-500 emails per day")
   - Monthly sending volume (e.g., "5,000-10,000 emails per month")

6. **Compliance**:
   - Confirm you'll comply with AWS SES terms
   - Confirm you'll follow email best practices

### Step 6: Submit and Wait
1. Review all information
2. Click **"Submit"** or **"Submit request"**
3. You'll receive a confirmation email
4. **Wait time**: Usually 24-48 hours, but can take up to a few days

## What Happens After Approval

Once approved:
- ✅ You can send to **any email address** (no recipient verification needed)
- ✅ Higher sending limits (default is usually 50,000 emails/day)
- ✅ Can request further increases if needed
- ✅ Still need to verify your **sender email address**

## Tips for Faster Approval

1. **Be specific** in your use case description
2. **Provide a real website URL** if you have one
3. **Be realistic** about sending volumes
4. **Explain your bounce/complaint handling** clearly
5. **Use a business email** for your AWS account if possible

## Example Request Details

**Use Case Description:**
```
We are sending important service notifications to our users about 
Amaze Studio platform changes. This includes notifications about 
service shutdowns, migration guides, and important updates that 
users need to be aware of to preserve their work.
```

**Bounce/Complaint Handling:**
```
We will monitor bounce and complaint rates through AWS SES console 
and SNS notifications. Invalid email addresses will be removed from 
our mailing list immediately. We will investigate all complaints and 
take appropriate action to maintain good sending practices.
```

**Expected Volume:**
```
Daily: 50-200 emails
Monthly: 1,500-5,000 emails
```

## Alternative: Using AWS CLI

You can also check your status and submit requests via AWS CLI:

```bash
# Check current sending quota
aws ses get-account-sending-enabled

# Check sending limits
aws ses get-send-quota
```

However, production access requests must be submitted through the AWS Console.

## Troubleshooting

### Can't find "Request production access" button?
- Make sure you're in the correct region
- Check if you're already in production mode
- Try refreshing the page
- Some accounts may need to verify their identity first

### Request was denied?
- Review AWS's feedback
- Address any concerns they mentioned
- Resubmit with more details
- Make sure your use case is legitimate

### Still in sandbox after approval?
- Wait a few minutes for changes to propagate
- Check you're in the same region where you requested access
- Verify your sender email is still verified

## Quick Checklist

Before requesting:
- [ ] Sender email is verified
- [ ] You have a clear use case
- [ ] You understand bounce/complaint handling
- [ ] You have realistic sending volume estimates
- [ ] You have a website URL (if applicable)

## Need Help?

If you're having trouble:
1. Check AWS SES documentation: https://docs.aws.amazon.com/ses/
2. Contact AWS Support
3. Check AWS SES forums for similar use cases

