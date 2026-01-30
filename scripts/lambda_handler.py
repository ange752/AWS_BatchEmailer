"""
AWS Lambda handler for sending emails via SES
Designed to work with S3-stored templates and recipient lists
"""

import json
import boto3
import os
import tempfile
from ses_emailer import SESEmailer, load_recipients_from_file

s3_client = boto3.client('s3')

def lambda_handler(event, context):
    """
    Lambda handler for sending mass emails
    
    Expected event structure:
    {
        "sender": "studio_support@amaze.co",
        "sender_name": "Amaze Software",
        "s3_bucket": "your-bucket-name",  # Single bucket for all files
        "recipients_key": "recipients/batch_01.csv",
        "template_text_key": "templates/email_template.txt",
        "template_html_key": "templates/email_template.html",
        "subject": "Your email subject",
        "region": "us-west-2",
        "batch_size": 50,
        "use_bcc": true
    }
    """
    
    try:
        # Get parameters from event
        sender = event.get('sender')
        sender_name = event.get('sender_name', 'Amaze Software')
        s3_bucket = event.get('s3_bucket')
        recipients_key = event.get('recipients_key')
        template_text_key = event.get('template_text_key')
        template_html_key = event.get('template_html_key')
        subject = event.get('subject')
        region = event.get('region', 'us-west-2')
        batch_size = event.get('batch_size', 50)
        use_bcc = event.get('use_bcc', True)
        
        # Validate required parameters
        if not all([sender, s3_bucket, recipients_key, template_text_key, subject]):
            return {
                'statusCode': 400,
                'body': json.dumps({
                    'error': 'Missing required parameters',
                    'required': ['sender', 's3_bucket', 'recipients_key', 'template_text_key', 'subject']
                })
            }
        
        # Create temp directory
        temp_dir = tempfile.mkdtemp()
        
        # Download files from S3
        recipients_file = os.path.join(temp_dir, 'recipients.csv')
        body_text_file = os.path.join(temp_dir, 'email_template.txt')
        body_html_file = None
        
        print(f"Downloading recipients from s3://{s3_bucket}/{recipients_key}")
        s3_client.download_file(s3_bucket, recipients_key, recipients_file)
        
        print(f"Downloading text template from s3://{s3_bucket}/{template_text_key}")
        s3_client.download_file(s3_bucket, template_text_key, body_text_file)
        
        if template_html_key:
            body_html_file = os.path.join(temp_dir, 'email_template.html')
            print(f"Downloading HTML template from s3://{s3_bucket}/{template_html_key}")
            s3_client.download_file(s3_bucket, template_html_key, body_html_file)
        
        # Load recipients
        print("Loading recipients...")
        recipients = load_recipients_from_file(recipients_file)
        print(f"Loaded {len(recipients)} recipients")
        
        # Read templates
        with open(body_text_file, 'r', encoding='utf-8') as f:
            body_text = f.read()
        
        body_html = None
        if body_html_file and os.path.exists(body_html_file):
            with open(body_html_file, 'r', encoding='utf-8') as f:
                body_html = f.read()
        
        # Initialize emailer
        emailer = SESEmailer(region_name=region)
        
        # Send emails
        print(f"Sending emails to {len(recipients)} recipients...")
        result = emailer.send_email_batch(
            sender=sender,
            recipients=recipients,
            subject=subject,
            body_text=body_text,
            body_html=body_html,
            batch_size=batch_size,
            use_bcc=use_bcc,
            rate_limit=0.1,
            sender_name=sender_name
        )
        
        # Cleanup temp files
        import shutil
        shutil.rmtree(temp_dir)
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'success': result['success'],
                'total': result['total'],
                'successful': result['successful'],
                'failed': result['failed'],
                'batches': result.get('batches', 0)
            })
        }
        
    except Exception as e:
        print(f"Error: {str(e)}")
        import traceback
        traceback.print_exc()
        
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e),
                'type': type(e).__name__
            })
        }

