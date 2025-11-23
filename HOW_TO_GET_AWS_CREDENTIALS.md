# How to Get AWS Credentials

## Option 1: Using IAM User Access Keys (Recommended for EC2)

### Step 1: Create IAM User (if needed)

1. Go to AWS Console → IAM → Users
2. Click "Create user"
3. Enter username (e.g., `email-sender-user`)
4. Select "Provide user access to the AWS Management Console" (optional)
5. Click "Next"

### Step 2: Attach Policies

1. Select "Attach policies directly"
2. Search and select:
   - `AmazonSESFullAccess` (for sending emails)
   - `AmazonS3ReadOnlyAccess` (for reading from S3)
   - `AmazonEC2ReadOnlyAccess` (optional, for viewing EC2)
3. Click "Next" → "Create user"

### Step 3: Create Access Keys

1. Click on the user you just created
2. Go to "Security credentials" tab
3. Scroll to "Access keys"
4. Click "Create access key"
5. Select "Command Line Interface (CLI)"
6. Click "Next" → "Create access key"
7. **IMPORTANT:** Copy both:
   - **Access key ID** (starts with `AKIA...`)
   - **Secret access key** (shown only once!)

### Step 4: Configure Credentials

**On your local machine:**
```bash
aws configure
```

Enter:
- AWS Access Key ID: `[paste your access key]`
- AWS Secret Access Key: `[paste your secret key]`
- Default region: `us-west-2`
- Default output format: `json`

**On EC2 instance:**
```bash
aws configure
# Enter the same credentials
```

---

## Option 2: Using IAM Role (Recommended for EC2 - More Secure)

Instead of storing credentials on EC2, attach an IAM role to the instance.

### Step 1: Create IAM Role

```bash
# Create trust policy
cat > ec2-trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Create role
aws iam create-role \
  --role-name EmailSenderEC2Role \
  --assume-role-policy-document file://ec2-trust-policy.json

# Attach policies
aws iam attach-role-policy \
  --role-name EmailSenderEC2Role \
  --policy-arn arn:aws:iam::aws:policy/AmazonSESFullAccess

aws iam attach-role-policy \
  --role-name EmailSenderEC2Role \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess

# Create instance profile
aws iam create-instance-profile --instance-profile-name EmailSenderEC2Profile
aws iam add-role-to-instance-profile \
  --instance-profile-name EmailSenderEC2Profile \
  --role-name EmailSenderEC2Role
```

### Step 2: Attach Role to EC2 Instance

```bash
# Get your instance ID
INSTANCE_ID="i-xxxxxxxxx"  # Replace with your instance ID

# Attach role
aws ec2 associate-iam-instance-profile \
  --instance-id $INSTANCE_ID \
  --iam-instance-profile Name=EmailSenderEC2Profile \
  --region us-west-2
```

**No credentials needed!** The instance will automatically use the role.

---

## Option 3: Check Existing Credentials

### View Current Configuration

```bash
# Check if credentials are configured
aws sts get-caller-identity

# View current configuration
cat ~/.aws/credentials
cat ~/.aws/config
```

### List Access Keys for Current User

```bash
# Get your user name
aws sts get-caller-identity --query 'Arn' --output text

# List access keys (if you have permission)
aws iam list-access-keys --user-name YOUR_USERNAME
```

---

## Option 4: Using AWS SSO (If Your Organization Uses It)

If your organization uses AWS SSO:

```bash
# Login via SSO
aws sso login --profile your-profile

# Use the profile
export AWS_PROFILE=your-profile
```

---

## Security Best Practices

### ✅ DO:
- Use IAM roles for EC2 instances (no credentials stored)
- Use least privilege (only grant necessary permissions)
- Rotate access keys regularly
- Use different keys for different environments

### ❌ DON'T:
- Commit credentials to Git
- Share credentials between users
- Use root account credentials
- Store credentials in code

---

## Troubleshooting

### Error: "Unable to locate credentials"

**Solution:**
```bash
aws configure
# Enter your credentials
```

### Error: "Access Denied"

**Solution:**
- Check IAM policies are attached
- Verify you're using the correct credentials
- Check region matches

### Error: "Invalid credentials"

**Solution:**
- Verify access key ID and secret key are correct
- Check if keys are active (not disabled)
- Create new access keys if needed

---

## Quick Setup Commands

### For Local Machine:
```bash
aws configure
# Enter: Access Key ID, Secret Key, Region (us-west-2), Format (json)
```

### For EC2 (Using IAM Role - Recommended):
```bash
# No credentials needed! Just attach IAM role to instance
```

### For EC2 (Using Access Keys):
```bash
aws configure
# Enter: Access Key ID, Secret Key, Region (us-west-2), Format (json)
```

---

## Verify Credentials Work

```bash
# Test credentials
aws sts get-caller-identity

# Should return:
# {
#     "UserId": "...",
#     "Account": "730857767296",
#     "Arn": "arn:aws:iam::730857767296:user/..."
# }
```

---

## Need Help?

- **AWS Console:** https://console.aws.amazon.com/iam/
- **AWS CLI Docs:** https://docs.aws.amazon.com/cli/latest/userguide/
- **IAM Best Practices:** https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html

