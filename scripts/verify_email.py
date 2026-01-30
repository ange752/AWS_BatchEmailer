#!/usr/bin/env python3
"""
Simple script to verify an email address in AWS SES
"""

import boto3
import sys
from botocore.exceptions import ClientError


def verify_email(email_address: str, region: str = 'us-west-2'):
    """
    Verify an email address with AWS SES
    
    Args:
        email_address: Email address to verify
        region: AWS region name
    """
    try:
        ses_client = boto3.client('ses', region_name=region)
        
        print(f"Requesting verification for {email_address}...")
        response = ses_client.verify_email_identity(EmailAddress=email_address)
        
        print(f"✓ Verification email sent successfully!")
        print(f"\nNext steps:")
        print(f"1. Check the inbox for {email_address}")
        print(f"2. Look for an email from AWS (noreply-aws@amazon.com)")
        print(f"3. Click the verification link in the email")
        print(f"4. Once verified, you can use this email to send messages via SES")
        
        return True
        
    except ClientError as e:
        error_code = e.response['Error']['Code']
        error_message = e.response['Error']['Message']
        
        print(f"✗ Error: {error_code}")
        print(f"  {error_message}")
        
        if error_code == 'InvalidParameterValue':
            print("\n  Make sure the email address is in a valid format")
        elif error_code == 'LimitExceeded':
            print("\n  You've reached the limit for verification requests. Please wait before trying again.")
        
        return False
    except Exception as e:
        print(f"✗ Unexpected error: {e}")
        return False


def check_verification_status(email_address: str, region: str = 'us-west-2'):
    """
    Check the verification status of an email address
    
    Args:
        email_address: Email address to check
        region: AWS region name
    """
    try:
        ses_client = boto3.client('ses', region_name=region)
        
        response = ses_client.get_identity_verification_attributes(
            Identities=[email_address]
        )
        
        attributes = response.get('VerificationAttributes', {})
        
        if email_address in attributes:
            status = attributes[email_address]['VerificationStatus']
            print(f"Verification status for {email_address}: {status}")
            
            if status == 'Success':
                print("✓ Email is verified and ready to use!")
            elif status == 'Pending':
                print("⏳ Email verification is pending. Check your inbox for the verification link.")
            elif status == 'Failed':
                print("✗ Email verification failed. You may need to request verification again.")
            else:
                print(f"Status: {status}")
        else:
            print(f"No verification found for {email_address}")
            print("You may need to request verification first.")
            
    except ClientError as e:
        print(f"Error checking status: {e}")


if __name__ == '__main__':
    import argparse
    
    parser = argparse.ArgumentParser(
        description='Verify an email address in AWS SES',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Request verification
  python verify_email.py your-email@example.com
  
  # Check verification status
  python verify_email.py your-email@example.com --check
  
  # Specify AWS region (if different from default)
  python verify_email.py your-email@example.com --region us-east-1
        """
    )
    
    parser.add_argument('email', help='Email address to verify')
    parser.add_argument('--region', default='us-west-2', help='AWS region (default: us-west-2)')
    parser.add_argument('--check', action='store_true', help='Check verification status instead of requesting verification')
    
    args = parser.parse_args()
    
    if args.check:
        check_verification_status(args.email, args.region)
    else:
        verify_email(args.email, args.region)

