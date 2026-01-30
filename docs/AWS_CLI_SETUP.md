# AWS CLI Installation and Configuration Guide

This guide will help you install and configure AWS CLI on your macOS system.

## Quick Installation

### Option 1: Using Homebrew (Recommended)

```bash
# Install AWS CLI
brew install awscli

# Verify installation
aws --version
```

### Option 2: Using the Official Installer

1. Download the AWS CLI installer for macOS:
   ```bash
   curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
   ```

2. Install it:
   ```bash
   sudo installer -pkg AWSCLIV2.pkg -target /
   ```

3. Verify installation:
   ```bash
   aws --version
   ```

### Option 3: Using pip

```bash
pip3 install awscli --user

# Add to PATH (add to ~/.zshrc or ~/.bashrc)
export PATH="$HOME/.local/bin:$PATH"
```

## Automated Setup Script

Run the provided script for interactive installation and configuration:

```bash
./install_aws_cli.sh
```

This script will:
- Check if AWS CLI is installed
- Install it if needed (via Homebrew)
- Guide you through configuration
- Test the connection

## Manual Configuration

If you prefer to configure manually:

```bash
aws configure
```

You'll be prompted for:
1. **AWS Access Key ID**: Your access key (starts with `AKIA...`)
2. **AWS Secret Access Key**: Your secret key
3. **Default region name**: `us-west-2` (recommended)
4. **Default output format**: `json` (recommended)

### Getting AWS Credentials

If you don't have AWS credentials yet, see [HOW_TO_GET_AWS_CREDENTIALS.md](./HOW_TO_GET_AWS_CREDENTIALS.md)

## Verify Installation

Test that everything is working:

```bash
# Check AWS CLI version
aws --version

# Test credentials
aws sts get-caller-identity

# List S3 buckets
aws s3 ls

# List contents of your emailer bucket
aws s3 ls s3://amaze-aws-emailer/ --recursive
```

## Check S3 Bucket Contents

Once configured, you can check what templates and recipient lists are in your S3 buckets:

```bash
# List templates
aws s3 ls s3://amaze-aws-emailer/templates/ --region us-west-2

# List recipient lists
aws s3 ls s3://amaze-aws-emailer/recipients/ --region us-west-2

# List everything recursively
aws s3 ls s3://amaze-aws-emailer/ --recursive --region us-west-2
```

## Configuration Files

AWS CLI stores configuration in:
- **Credentials**: `~/.aws/credentials`
- **Config**: `~/.aws/config`

You can view/edit these files directly if needed:
```bash
cat ~/.aws/config
cat ~/.aws/credentials
```

## Troubleshooting

### AWS CLI not found after installation

Make sure it's in your PATH:
```bash
# Check where it's installed
which aws

# If not found, add to PATH in ~/.zshrc:
export PATH="/usr/local/bin:$PATH"  # or wherever it's installed
```

### Permission errors

If you get permission errors with Homebrew:
```bash
sudo chown -R $(whoami) /opt/homebrew/Cellar
```

### SSL/Certificate errors

If you encounter SSL errors, try:
```bash
# Update certificates (macOS)
brew install ca-certificates
```

## Next Steps

After installing and configuring AWS CLI:

1. ✅ Verify connection: `aws sts get-caller-identity`
2. ✅ Check S3 buckets: `aws s3 ls`
3. ✅ List templates: `aws s3 ls s3://amaze-aws-emailer/templates/`
4. ✅ List recipients: `aws s3 ls s3://amaze-aws-emailer/recipients/`

## Additional Resources

- [AWS CLI Documentation](https://docs.aws.amazon.com/cli/latest/userguide/)
- [AWS CLI Command Reference](https://docs.aws.amazon.com/cli/latest/reference/)
- [How to Get AWS Credentials](./HOW_TO_GET_AWS_CREDENTIALS.md)

