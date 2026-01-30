#!/bin/bash
# AWS CLI Installation and Configuration Script
# Run this script to install and configure AWS CLI

set -e

echo "🔧 AWS CLI Installation and Configuration"
echo "=========================================="
echo ""

# Check if AWS CLI is already installed
if command -v aws &> /dev/null; then
    echo "✅ AWS CLI is already installed"
    aws --version
    echo ""
    
    # Check if already configured
    if [ -f ~/.aws/credentials ] || [ -f ~/.aws/config ]; then
        echo "📋 Current AWS configuration:"
        echo ""
        if [ -f ~/.aws/config ]; then
            echo "Config file (~/.aws/config):"
            cat ~/.aws/config
            echo ""
        fi
        if [ -f ~/.aws/credentials ]; then
            echo "Credentials file (~/.aws/credentials):"
            # Don't show full credentials, just indicate they exist
            echo "  [Credentials file exists - contains access keys]"
            echo ""
        fi
        
        read -p "Do you want to reconfigure AWS CLI? (y/n) " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "✅ Keeping existing configuration"
            exit 0
        fi
    fi
else
    echo "📦 Installing AWS CLI..."
    echo ""
    
    # Detect OS
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        echo "Detected macOS"
        
        # Try Homebrew first
        if command -v brew &> /dev/null; then
            echo "Installing via Homebrew..."
            brew install awscli
        else
            echo "Homebrew not found. Installing via official installer..."
            echo ""
            echo "Please download and install AWS CLI from:"
            echo "https://awscli.amazonaws.com/AWSCLIV2.pkg"
            echo ""
            echo "Or install Homebrew first:"
            echo "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
            echo ""
            read -p "Press Enter after installing AWS CLI..."
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        echo "Detected Linux"
        echo "Installing via pip..."
        pip3 install awscli --user
        
        # Add to PATH if needed
        if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
            echo ""
            echo "⚠️  Add to your ~/.bashrc or ~/.zshrc:"
            echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
        fi
    else
        echo "⚠️  Unsupported OS. Please install AWS CLI manually:"
        echo "https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
        exit 1
    fi
    
    # Verify installation
    if command -v aws &> /dev/null; then
        echo "✅ AWS CLI installed successfully"
        aws --version
    else
        echo "❌ AWS CLI installation failed or not in PATH"
        echo "Please install manually and ensure it's in your PATH"
        exit 1
    fi
    echo ""
fi

# Configure AWS CLI
echo "⚙️  Configuring AWS CLI..."
echo ""
echo "You'll need:"
echo "  - AWS Access Key ID"
echo "  - AWS Secret Access Key"
echo "  - Default region (e.g., us-west-2)"
echo "  - Default output format (json, text, or table)"
echo ""

# Check if credentials are provided as environment variables
if [ -n "$AWS_ACCESS_KEY_ID" ] && [ -n "$AWS_SECRET_ACCESS_KEY" ]; then
    echo "📝 Found AWS credentials in environment variables"
    read -p "Use these credentials? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        AWS_ACCESS_KEY_ID_VALUE="$AWS_ACCESS_KEY_ID"
        AWS_SECRET_ACCESS_KEY_VALUE="$AWS_SECRET_ACCESS_KEY"
    fi
fi

# Get credentials interactively
if [ -z "$AWS_ACCESS_KEY_ID_VALUE" ]; then
    read -p "AWS Access Key ID: " AWS_ACCESS_KEY_ID_VALUE
    read -sp "AWS Secret Access Key: " AWS_SECRET_ACCESS_KEY_VALUE
    echo ""
fi

read -p "Default region name [us-west-2]: " AWS_DEFAULT_REGION
AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION:-us-west-2}

read -p "Default output format [json]: " AWS_DEFAULT_OUTPUT
AWS_DEFAULT_OUTPUT=${AWS_DEFAULT_OUTPUT:-json}

# Create AWS directory if it doesn't exist
mkdir -p ~/.aws

# Configure AWS CLI
echo ""
echo "📝 Writing configuration..."
aws configure set aws_access_key_id "$AWS_ACCESS_KEY_ID_VALUE"
aws configure set aws_secret_access_key "$AWS_SECRET_ACCESS_KEY_VALUE"
aws configure set default.region "$AWS_DEFAULT_REGION"
aws configure set default.output "$AWS_DEFAULT_OUTPUT"

echo ""
echo "✅ AWS CLI configured successfully!"
echo ""
echo "📋 Configuration summary:"
aws configure list
echo ""

# Test configuration
echo "🧪 Testing AWS CLI connection..."
if aws sts get-caller-identity &> /dev/null; then
    echo "✅ Connection successful!"
    echo ""
    echo "Your AWS Account ID:"
    aws sts get-caller-identity --query Account --output text
    echo ""
    echo "Your AWS User/Role:"
    aws sts get-caller-identity --query Arn --output text
else
    echo "❌ Connection failed. Please check your credentials."
    exit 1
fi

echo ""
echo "🎉 AWS CLI is ready to use!"
echo ""
echo "Next steps:"
echo "  1. Check S3 buckets: aws s3 ls"
echo "  2. List templates: aws s3 ls s3://amaze-aws-emailer/templates/"
echo "  3. List recipients: aws s3 ls s3://amaze-aws-emailer/recipients/"

