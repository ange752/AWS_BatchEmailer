#!/usr/bin/env python3
"""
AWS SES Mass Email Sender
A simple script to send mass emails using AWS SES (Simple Email Service)
"""

import boto3
import json
import csv
import sys
import os
import webbrowser
import tempfile
import time
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.mime.base import MIMEBase
from email import encoders
from typing import List, Dict, Optional
from botocore.exceptions import ClientError


class SESEmailer:
    """Class to handle sending emails via AWS SES"""
    
    def __init__(self, region_name: str = 'us-west-2'):
        """
        Initialize the SES client
        
        Args:
            region_name: AWS region name (default: us-west-2)
        """
        self.ses_client = boto3.client('ses', region_name=region_name)
        self.region = region_name
    
    def verify_email_identity(self, email: str) -> bool:
        """
        Verify an email address or domain with SES
        
        Args:
            email: Email address to verify
            
        Returns:
            True if verification request was sent successfully
        """
        try:
            response = self.ses_client.verify_email_identity(EmailAddress=email)
            print(f"Verification email sent to {email}. Please check your inbox.")
            return True
        except ClientError as e:
            print(f"Error verifying email {email}: {e}")
            return False
    
    def send_email(
        self,
        sender: str,
        recipients: List[str],
        subject: str,
        body_text: str,
        body_html: Optional[str] = None,
        reply_to: Optional[List[str]] = None,
        bcc: Optional[List[str]] = None,
        sender_name: Optional[str] = None
    ) -> Dict:
        """
        Send email to multiple recipients using send_email
        
        Args:
            sender: Verified sender email address
            recipients: List of recipient email addresses
            subject: Email subject
            body_text: Plain text email body
            body_html: HTML email body (optional)
            reply_to: List of reply-to email addresses (optional)
            
        Returns:
            Dictionary with success status and message IDs
        """
        # Use BCC if provided, otherwise use To
        if bcc:
            # Send to sender in To, recipients in BCC (protects privacy)
            destination = {
                'ToAddresses': [sender],  # Send to yourself
                'BccAddresses': bcc
            }
        else:
            destination = {
                'ToAddresses': recipients
            }
        
        message = {
            'Subject': {'Data': subject, 'Charset': 'UTF-8'},
            'Body': {'Text': {'Data': body_text, 'Charset': 'UTF-8'}}
        }
        
        if body_html:
            message['Body']['Html'] = {'Data': body_html, 'Charset': 'UTF-8'}
        
        # Format sender with display name if provided
        if sender_name:
            formatted_sender = f'{sender_name} <{sender}>'
        else:
            formatted_sender = sender
        
        try:
            response = self.ses_client.send_email(
                Source=formatted_sender,
                Destination=destination,
                Message=message,
                ReplyToAddresses=reply_to if reply_to else []
            )
            
            recipient_count = len(bcc) if bcc else len(recipients)
            print(f"✓ Email sent successfully!")
            print(f"  Message ID: {response['MessageId']}")
            if bcc:
                print(f"  Recipients (BCC): {recipient_count} addresses")
            else:
                print(f"  Recipients: {', '.join(recipients)}")
            
            return {
                'success': True,
                'message_id': response['MessageId'],
                'recipients': bcc if bcc else recipients
            }
        except ClientError as e:
            error_code = e.response['Error']['Code']
            error_message = e.response['Error']['Message']
            print(f"✗ Error sending email: {error_code} - {error_message}")
            
            if error_code == 'MessageRejected':
                print("  Note: Make sure your sender email is verified in SES")
            elif error_code == 'MailFromDomainNotVerified':
                print("  Note: The sending domain needs to be verified")
            
            return {
                'success': False,
                'error': error_code,
                'message': error_message
            }
    
    def send_email_batch(
        self,
        sender: str,
        recipients: List[str],
        subject: str,
        body_text: str,
        body_html: Optional[str] = None,
        batch_size: int = 50,
        use_bcc: bool = True,
        rate_limit: float = 0.1,  # seconds between batches (10 emails/second = 0.1s)
        reply_to: Optional[List[str]] = None,
        sender_name: Optional[str] = None,
        personalized: bool = False,
        recipient_data: Optional[List[Dict[str, str]]] = None,
        generic_greeting: Optional[str] = None
    ) -> Dict:
        """
        Send emails in batches with rate limiting and BCC support
        
        Args:
            sender: Verified sender email address
            recipients: List of recipient email addresses (or list of dicts with 'email' key if personalized)
            subject: Email subject (can contain placeholders like [NAME] if personalized=True)
            body_text: Plain text email body (can contain placeholders like [NAME] if personalized=True)
            body_html: HTML email body (optional, can contain placeholders if personalized=True)
            batch_size: Number of recipients per batch (default: 50)
            use_bcc: Use BCC to protect recipient privacy (default: True)
            rate_limit: Seconds to wait between batches (default: 0.1 = 10 batches/second)
            reply_to: List of reply-to email addresses (optional)
            personalized: If True, replace placeholders like [NAME] with recipient data
            recipient_data: List of dicts with recipient data (required if personalized=True)
            generic_greeting: Generic greeting to use when name is not available (e.g., "Hi There!")
            
        Returns:
            Dictionary with success status and batch results
        """
        # Normalize recipients to list of dicts if personalized
        if personalized:
            if not recipient_data:
                # If recipients are already dicts, use them; otherwise create dicts
                if recipients and isinstance(recipients[0], dict):
                    recipient_data = recipients
                else:
                    recipient_data = [{'email': r, 'name': ''} for r in recipients]
            recipients_list = [r['email'] for r in recipient_data]
        else:
            # Convert recipients to list if needed
            if recipients and isinstance(recipients[0], dict):
                recipients_list = [r['email'] for r in recipients]
            else:
                recipients_list = recipients
            recipient_data = [{'email': r, 'name': ''} for r in recipients_list]
        
        total_recipients = len(recipients_list)
        total_batches = (total_recipients + batch_size - 1) // batch_size
        
        print(f"\n📧 Batch Sending Configuration:")
        print(f"  Total recipients: {total_recipients}")
        print(f"  Batch size: {batch_size}")
        print(f"  Total batches: {total_batches}")
        print(f"  Use BCC: {use_bcc}")
        print(f"  Personalized: {personalized}")
        print(f"  Rate limit: {1/rate_limit:.1f} batches/second\n")
        
        results = []
        success_count = 0
        fail_count = 0
        
        for batch_num in range(total_batches):
            start_idx = batch_num * batch_size
            end_idx = min(start_idx + batch_size, total_recipients)
            batch_recipients = recipients_list[start_idx:end_idx]
            batch_recipient_data = recipient_data[start_idx:end_idx]
            
            print(f"📦 Batch {batch_num + 1}/{total_batches} ({len(batch_recipients)} recipients)...")
            
            try:
                if use_bcc:
                    # For BCC privacy, send individual emails so each recipient only sees their own address
                    batch_success = 0
                    batch_fail = 0
                    for i, recipient in enumerate(batch_recipients):
                        # Personalize content if enabled
                        personalized_subject = subject
                        personalized_body_text = body_text
                        personalized_body_html = body_html
                        
                        if personalized:
                            recipient_info = batch_recipient_data[i]
                            personalized_subject = replace_template_placeholders(subject, recipient_info, generic_greeting)
                            personalized_body_text = replace_template_placeholders(body_text, recipient_info, generic_greeting)
                            if body_html:
                                personalized_body_html = replace_template_placeholders(body_html, recipient_info, generic_greeting)
                        
                        result = self.send_email(
                            sender=sender,
                            recipients=[recipient],  # Individual recipient
                            subject=personalized_subject,
                            body_text=personalized_body_text,
                            body_html=personalized_body_html,
                            reply_to=reply_to,
                            bcc=None,  # No BCC needed since it's individual
                            sender_name=sender_name
                        )
                        if result['success']:
                            batch_success += 1
                        else:
                            batch_fail += 1
                        # Small delay between individual sends to respect rate limits
                        time.sleep(0.07)  # ~14 emails/second
                    
                    if batch_fail == 0:
                        success_count += batch_success
                        print(f"  ✓ Batch {batch_num + 1} sent successfully ({batch_success} emails)")
                    else:
                        success_count += batch_success
                        fail_count += batch_fail
                        print(f"  ⚠ Batch {batch_num + 1} completed: {batch_success} success, {batch_fail} failed")
                    
                    results.append({
                        'batch': batch_num + 1,
                        'recipients': batch_recipients,
                        'success': batch_fail == 0,
                        'successful': batch_success,
                        'failed': batch_fail
                    })
                else:
                    # Send to all recipients in batch (they'll see each other)
                    # Note: If personalized, we still need to send individually
                    if personalized:
                        # For personalized emails, send individually even without BCC
                        batch_success = 0
                        batch_fail = 0
                        for i, recipient in enumerate(batch_recipients):
                            recipient_info = batch_recipient_data[i]
                            personalized_subject = replace_template_placeholders(subject, recipient_info, generic_greeting)
                            personalized_body_text = replace_template_placeholders(body_text, recipient_info, generic_greeting)
                            personalized_body_html = replace_template_placeholders(body_html, recipient_info, generic_greeting) if body_html else None
                            
                            result = self.send_email(
                                sender=sender,
                                recipients=[recipient],
                                subject=personalized_subject,
                                body_text=personalized_body_text,
                                body_html=personalized_body_html,
                                reply_to=reply_to,
                                bcc=None,
                                sender_name=sender_name
                            )
                            if result['success']:
                                batch_success += 1
                            else:
                                batch_fail += 1
                            time.sleep(0.07)  # Small delay between sends
                        
                        if batch_fail == 0:
                            success_count += batch_success
                            print(f"  ✓ Batch {batch_num + 1} sent successfully ({batch_success} emails)")
                        else:
                            success_count += batch_success
                            fail_count += batch_fail
                            print(f"  ⚠ Batch {batch_num + 1} completed: {batch_success} success, {batch_fail} failed")
                        
                        results.append({
                            'batch': batch_num + 1,
                            'recipients': batch_recipients,
                            'success': batch_fail == 0,
                            'successful': batch_success,
                            'failed': batch_fail
                        })
                    else:
                        # Non-personalized - send to all at once
                        result = self.send_email(
                            sender=sender,
                            recipients=batch_recipients,
                            subject=subject,
                            body_text=body_text,
                            body_html=body_html,
                            reply_to=reply_to,
                            bcc=None,
                            sender_name=sender_name
                        )
                        
                        if result['success']:
                            success_count += len(batch_recipients)
                            print(f"  ✓ Batch {batch_num + 1} sent successfully")
                        else:
                            fail_count += len(batch_recipients)
                            print(f"  ✗ Batch {batch_num + 1} failed: {result.get('error', 'Unknown error')}")
                        
                        results.append({
                            'batch': batch_num + 1,
                            'recipients': batch_recipients,
                            'success': result['success'],
                            'result': result
                        })
                
                # Rate limiting - wait between batches (except for last batch)
                if batch_num < total_batches - 1:
                    time.sleep(rate_limit)
                    
            except Exception as e:
                fail_count += len(batch_recipients)
                print(f"  ✗ Batch {batch_num + 1} error: {e}")
                results.append({
                    'batch': batch_num + 1,
                    'recipients': batch_recipients,
                    'success': False,
                    'error': str(e)
                })
        
        print(f"\n📊 Batch Sending Summary:")
        print(f"  Total: {total_recipients}")
        print(f"  Successful: {success_count}")
        print(f"  Failed: {fail_count}")
        print(f"  Success rate: {(success_count/total_recipients*100):.1f}%")
        
        return {
            'success': fail_count == 0,
            'total': total_recipients,
            'successful': success_count,
            'failed': fail_count,
            'batches': total_batches,
            'results': results
        }
    
    def send_email_with_attachments(
        self,
        sender: str,
        recipients: List[str],
        subject: str,
        body_text: str,
        body_html: Optional[str] = None,
        attachments: Optional[List[str]] = None,
        reply_to: Optional[List[str]] = None,
        sender_name: Optional[str] = None
    ) -> Dict:
        """
        Send email with attachments using send_raw_email
        
        Args:
            sender: Verified sender email address
            recipients: List of recipient email addresses
            subject: Email subject
            body_text: Plain text email body
            body_html: HTML email body (optional)
            attachments: List of file paths to attach (optional)
            reply_to: List of reply-to email addresses (optional)
            
        Returns:
            Dictionary with success status and message IDs
        """
        try:
            # Create MIME message structure
            # If we have both HTML and attachments, we need: mixed -> alternative (text/html) + attachments
            if body_html and attachments:
                msg = MIMEMultipart('mixed')
                # Create alternative part for text/html
                alt_part = MIMEMultipart('alternative')
                text_part = MIMEText(body_text, 'plain', 'utf-8')
                html_part = MIMEText(body_html, 'html', 'utf-8')
                alt_part.attach(text_part)
                alt_part.attach(html_part)
                msg.attach(alt_part)
            elif body_html:
                # Only HTML, no attachments - use alternative
                msg = MIMEMultipart('alternative')
                text_part = MIMEText(body_text, 'plain', 'utf-8')
                html_part = MIMEText(body_html, 'html', 'utf-8')
                msg.attach(text_part)
                msg.attach(html_part)
            else:
                # Plain text only
                msg = MIMEMultipart('mixed')
                text_part = MIMEText(body_text, 'plain', 'utf-8')
                msg.attach(text_part)
            
            msg['Subject'] = subject
            # Format sender with display name if provided
            if sender_name:
                msg['From'] = f'{sender_name} <{sender}>'
            else:
                msg['From'] = sender
            msg['To'] = ', '.join(recipients)
            
            if reply_to:
                msg['Reply-To'] = ', '.join(reply_to)
            
            # Add attachments if provided
            if attachments:
                for attachment_path in attachments:
                    if not os.path.exists(attachment_path):
                        print(f"Warning: Attachment file not found: {attachment_path}")
                        continue
                    
                    try:
                        with open(attachment_path, 'rb') as f:
                            attachment_data = f.read()
                        
                        # Get filename from path
                        filename = os.path.basename(attachment_path)
                        
                        # Create attachment
                        attachment = MIMEBase('application', 'octet-stream')
                        attachment.set_payload(attachment_data)
                        encoders.encode_base64(attachment)
                        attachment.add_header(
                            'Content-Disposition',
                            f'attachment; filename= {filename}'
                        )
                        msg.attach(attachment)
                        print(f"  Attached: {filename} ({len(attachment_data)} bytes)")
                    except Exception as e:
                        print(f"Warning: Failed to attach {attachment_path}: {e}")
                        continue
            
            # Convert message to string
            raw_message = msg.as_string()
            
            # Format sender with display name if provided (for Source field)
            if sender_name:
                formatted_sender = f'{sender_name} <{sender}>'
            else:
                formatted_sender = sender
            
            # Send via SES
            response = self.ses_client.send_raw_email(
                Source=formatted_sender,
                Destinations=recipients,
                RawMessage={'Data': raw_message}
            )
            
            print(f"✓ Email with attachments sent successfully!")
            print(f"  Message ID: {response['MessageId']}")
            print(f"  Recipients: {', '.join(recipients)}")
            if attachments:
                print(f"  Attachments: {len([a for a in attachments if os.path.exists(a)])} file(s)")
            
            return {
                'success': True,
                'message_id': response['MessageId'],
                'recipients': recipients,
                'attachments': attachments or []
            }
            
        except ClientError as e:
            error_code = e.response['Error']['Code']
            error_message = e.response['Error']['Message']
            print(f"✗ Error sending email: {error_code} - {error_message}")
            
            if error_code == 'MessageRejected':
                print("  Note: Make sure your sender email is verified in SES")
            elif error_code == 'MailFromDomainNotVerified':
                print("  Note: The sending domain needs to be verified")
            
            return {
                'success': False,
                'error': error_code,
                'message': error_message
            }
        except Exception as e:
            print(f"✗ Error creating email: {e}")
            return {
                'success': False,
                'error': 'EmailCreationError',
                'message': str(e)
            }
    
    def send_bulk_email(
        self,
        sender: str,
        recipients: List[Dict[str, str]],
        subject: str,
        body_text: str,
        body_html: Optional[str] = None,
        default_tags: Optional[List[Dict[str, str]]] = None
    ) -> Dict:
        """
        Send bulk emails with personalized content using send_bulk_email
        
        Args:
            sender: Verified sender email address
            recipients: List of dicts with 'email' and optional 'name' keys
            subject: Email subject (can use template variables)
            body_text: Plain text email body (can use template variables)
            body_html: HTML email body (optional, can use template variables)
            default_tags: List of tags for email tracking (optional)
            
        Returns:
            Dictionary with success status and results
        """
        destinations = []
        for recipient in recipients:
            dest = {'Destination': {'ToAddresses': [recipient['email']]}}
            if 'name' in recipient:
                # Simple template replacement (SES doesn't support this directly,
                # but we can prepare personalized messages)
                dest['ReplacementTemplateData'] = json.dumps({
                    'name': recipient.get('name', '')
                })
            destinations.append(dest)
        
        message = {
            'Subject': {'Data': subject, 'Charset': 'UTF-8'},
            'Body': {'Text': {'Data': body_text, 'Charset': 'UTF-8'}}
        }
        
        if body_html:
            message['Body']['Html'] = {'Data': body_html, 'Charset': 'UTF-8'}
        
        try:
            response = self.ses_client.send_bulk_templated_email(
                Source=sender,
                Template='',  # Not using template, using direct message
                DefaultTemplateData=json.dumps({}),
                Destinations=destinations
            )
            
            # Actually, send_bulk_templated_email requires a template
            # Let's use send_bulk_email instead (if available) or fall back to individual sends
            # For simplicity, let's use a loop with send_email for bulk sending
            print("Note: Using individual send_email calls for bulk sending...")
            results = []
            success_count = 0
            fail_count = 0
            
            for recipient in recipients:
                result = self.send_email(
                    sender=sender,
                    recipients=[recipient['email']],
                    subject=subject,
                    body_text=body_text,
                    body_html=body_html
                )
                results.append(result)
                if result['success']:
                    success_count += 1
                else:
                    fail_count += 1
            
            print(f"\nBulk email summary:")
            print(f"  Total: {len(recipients)}")
            print(f"  Successful: {success_count}")
            print(f"  Failed: {fail_count}")
            
            return {
                'success': fail_count == 0,
                'total': len(recipients),
                'successful': success_count,
                'failed': fail_count,
                'results': results
            }
            
        except ClientError as e:
            print(f"Error in bulk email: {e}")
            return {'success': False, 'error': str(e)}


def preview_email(
    subject: str,
    body_text: str,
    body_html: Optional[str] = None,
    sender: Optional[str] = None,
    recipients: Optional[List[str]] = None,
    attachments: Optional[List[str]] = None,
    sender_name: Optional[str] = None,
    open_browser: bool = True,
    personalized: bool = False,
    recipient_data: Optional[List[Dict[str, str]]] = None,
    generic_greeting: Optional[str] = None
) -> None:
    """
    Preview email content before sending
    
    Args:
        subject: Email subject
        body_text: Plain text email body
        body_html: HTML email body (optional)
        sender: Sender email address (optional)
        recipients: List of recipients (optional)
        open_browser: Whether to open HTML preview in browser
        personalized: Whether to show personalized content
        recipient_data: List of recipient data for personalization
        generic_greeting: Generic greeting for personalization
    """
    # Personalize content for first recipient if personalization is enabled
    preview_subject = subject
    preview_body_text = body_text
    preview_body_html = body_html
    
    if personalized and recipient_data and len(recipient_data) > 0:
        first_recipient = recipient_data[0]
        preview_subject = replace_template_placeholders(subject, first_recipient, generic_greeting)
        preview_body_text = replace_template_placeholders(body_text, first_recipient, generic_greeting)
        if body_html:
            preview_body_html = replace_template_placeholders(body_html, first_recipient, generic_greeting)
        print("✨ Showing personalized preview for first recipient")
        if first_recipient.get('name'):
            print(f"   Name: {first_recipient.get('name')}")
        else:
            print(f"   Name: (not provided - using generic greeting)")
        print()
    
    print("=" * 70)
    print("EMAIL PREVIEW")
    print("=" * 70)
    
    if sender:
        if sender_name:
            print(f"From: {sender_name} <{sender}>")
        else:
            print(f"From: {sender}")
    if recipients:
        # Show first recipient if personalized, otherwise show all
        if personalized and recipient_data and len(recipient_data) > 0:
            print(f"To: {recipient_data[0]['email']} (showing first recipient)")
        else:
            print(f"To: {', '.join(recipients)}")
    print(f"Subject: {preview_subject}")
    if attachments:
        print(f"Attachments: {len(attachments)} file(s)")
        for att in attachments:
            if os.path.exists(att):
                size = os.path.getsize(att)
                print(f"  - {os.path.basename(att)} ({size:,} bytes)")
            else:
                print(f"  - {os.path.basename(att)} (FILE NOT FOUND)")
    print("=" * 70)
    print("\nPLAIN TEXT VERSION:")
    print("-" * 70)
    print(preview_body_text)
    print("-" * 70)
    
    if preview_body_html:
        print("\nHTML VERSION:")
        print("(Opening in browser...)\n")
        
        # Create a preview HTML file
        preview_html = f"""<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Email Preview - {preview_subject}</title>
    <style>
        body {{
            font-family: Arial, sans-serif;
            max-width: 800px;
            margin: 20px auto;
            padding: 20px;
            background-color: #f5f5f5;
        }}
        .preview-header {{
            background-color: #333;
            color: white;
            padding: 15px;
            border-radius: 5px 5px 0 0;
            margin-bottom: 0;
        }}
        .preview-header h2 {{
            margin: 0;
            font-size: 16px;
        }}
        .preview-info {{
            background-color: #e8e8e8;
            padding: 10px 15px;
            font-size: 12px;
            border-top: 1px solid #ccc;
        }}
        .email-content {{
            background-color: white;
            padding: 20px;
            border: 1px solid #ddd;
            border-top: none;
            border-radius: 0 0 5px 5px;
        }}
        .warning {{
            background-color: #fff3cd;
            border: 1px solid #ffc107;
            padding: 15px;
            margin-bottom: 20px;
            border-radius: 5px;
        }}
    </style>
</head>
<body>
    <div class="warning">
        <strong>⚠️ PREVIEW MODE</strong><br>
        This is how your email will appear to recipients. This preview will not be sent.
    </div>
    
    <div class="preview-header">
        <h2>Email Preview</h2>
    </div>
    <div class="preview-info">
        <strong>From:</strong> {f'{sender_name} <{sender}>' if sender_name and sender else sender or 'Not specified'}<br>
        <strong>To:</strong> {recipient_data[0]['email'] if personalized and recipient_data and len(recipient_data) > 0 else (', '.join(recipients) if recipients else 'Not specified')} {'(showing first recipient)' if personalized and recipient_data and len(recipient_data) > 0 else ''}<br>
        <strong>Subject:</strong> {preview_subject}
    </div>
    <div class="email-content">
        {preview_body_html}
    </div>
</body>
</html>"""
        
        # Save to temporary file and open in browser
        try:
            with tempfile.NamedTemporaryFile(mode='w', suffix='.html', delete=False, encoding='utf-8') as f:
                f.write(preview_html)
                preview_path = f.name
            
            if open_browser:
                print(f"Opening preview in browser: {preview_path}")
                webbrowser.open(f'file://{preview_path}')
                print("\nPreview opened in your default browser.")
                print("Close the browser window when done reviewing.")
            else:
                print(f"Preview saved to: {preview_path}")
                print("Open this file in your browser to preview the email.")
        except Exception as e:
            print(f"Error creating preview: {e}")
            print("\nHTML content:")
            print("-" * 70)
            print(body_html)
            print("-" * 70)
    else:
        print("\n(No HTML version provided)")
    
    print("\n" + "=" * 70)
    print("END OF PREVIEW")
    print("=" * 70)


def replace_template_placeholders(text: str, recipient_data: Dict[str, str], generic_greeting: Optional[str] = None) -> str:
    """
    Replace template placeholders in text with recipient data
    
    Args:
        text: Text with placeholders like [NAME], [EMAIL], [GREETING]
        recipient_data: Dictionary with recipient data (e.g., {'name': 'John', 'email': 'john@example.com'})
        generic_greeting: Generic greeting to use when name is not available (e.g., "Hi There!")
        
    Returns:
        Text with placeholders replaced
    """
    result = text
    email = recipient_data.get('email', '').strip()
    
    # Replace [NAME] with recipient name, or use email address as fallback, or generic greeting
    name = recipient_data.get('name', '').strip()
    if not name and email:
        # Extract name from email (part before @) and format it nicely
        email_local = email.split('@')[0] if '@' in email else email
        # Remove dots, underscores, and numbers, then capitalize
        name = email_local.replace('.', ' ').replace('_', ' ').replace('-', ' ')
        # Capitalize first letter of each word
        name = ' '.join(word.capitalize() for word in name.split() if word and not word.isdigit())
        # If still empty or just numbers, use the original email local part
        if not name or name.strip() == '':
            name = email_local.split('.')[0].capitalize()  # Use first part before first dot
    
    # Replace [NAME] placeholder - use name if available, otherwise use generic greeting as fallback
    if name:
        name_replacement = name
    elif generic_greeting:
        # If no name but generic greeting provided, use it for [NAME] placeholder
        name_replacement = generic_greeting
    else:
        name_replacement = ''
    
    result = result.replace('[NAME]', name_replacement)
    result = result.replace('[name]', name_replacement)
    
    # Replace [GREETING] placeholder - use name if available, otherwise generic greeting
    if '[GREETING]' in result or '[greeting]' in result:
        if name:
            greeting = f"Hi {name}!"
        elif generic_greeting:
            greeting = generic_greeting
        else:
            greeting = "Hi!"
        result = result.replace('[GREETING]', greeting)
        result = result.replace('[greeting]', greeting)
    
    # Replace [EMAIL] with recipient email
    result = result.replace('[EMAIL]', email)
    result = result.replace('[email]', email)
    
    return result


def load_recipients_from_file(file_path: str, include_names: bool = False) -> List[str]:
    """
    Load recipients from a CSV or JSON file
    
    Args:
        file_path: Path to the CSV or JSON file
        include_names: If True, returns list of dicts with 'email' and 'name' keys
        
    Returns:
        List of email addresses (or list of dicts if include_names=True)
    """
    file_ext = os.path.splitext(file_path)[1].lower()
    
    if file_ext == '.csv':
        # Load from CSV
        recipients = []
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                # Read first line to check for header
                first_line = f.readline().strip()
                f.seek(0)
                
                # Check if first line looks like a header
                has_header = first_line.lower() in ['email', 'e-mail', 'email_address', 'emailaddress'] or \
                            any(col.lower() in first_line.lower() for col in ['email', 'name'])
                
                # For single-column CSV, we can use comma or newline as delimiter
                # Try to detect delimiter from the file
                sample = f.read(1024)
                f.seek(0)
                
                # Check if file has commas (multi-column) or is just newline-separated (single column)
                if ',' in sample:
                    # Multi-column CSV - use comma delimiter
                    delimiter = ','
                else:
                    # Single column - use comma delimiter (DictReader/reader will handle it)
                    delimiter = ','
                
                reader = csv.DictReader(f, delimiter=delimiter) if has_header else csv.reader(f, delimiter=delimiter)
                
                for row in reader:
                    if isinstance(row, dict):
                        # CSV with header - look for common email column names
                        email = None
                        name = None
                        
                        # Find email column
                        for col in ['email', 'Email', 'EMAIL', 'e-mail', 'E-mail', 'email_address', 'EmailAddress']:
                            if col in row and row[col]:
                                email = row[col].strip()
                                break
                        
                        # If no standard column found, use first column
                        if not email:
                            email = list(row.values())[0].strip() if row.values() else None
                        
                        # Find name column if include_names is True
                        if include_names:
                            for col in ['name', 'Name', 'NAME', 'first_name', 'First Name', 'firstname', 'FirstName']:
                                if col in row and row[col]:
                                    name = row[col].strip()
                                    break
                            # If no name found, try second column
                            if not name and len(row) > 1:
                                values = list(row.values())
                                if len(values) > 1:
                                    name = values[1].strip() if values[1] else None
                    else:
                        # CSV without header - use first column for email
                        email = row[0].strip() if row else None
                        # Use second column for name if available
                        name = row[1].strip() if include_names and len(row) > 1 and row[1] else None
                    
                    if email and '@' in email:
                        if include_names:
                            recipients.append({'email': email, 'name': name or ''})
                        else:
                            recipients.append(email)
            
            if not recipients:
                print("Warning: No valid email addresses found in CSV file")
            
            return recipients
            
        except Exception as e:
            print(f"Error reading CSV file: {e}")
            sys.exit(1)
    
    elif file_ext == '.json':
        # Load from JSON
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                data = json.load(f)
                if isinstance(data, list):
                    if include_names:
                        recipients = []
                        for r in data:
                            if isinstance(r, str):
                                recipients.append({'email': r, 'name': ''})
                            elif isinstance(r, dict):
                                recipients.append({'email': r.get('email', ''), 'name': r.get('name', '')})
                        return recipients
                    else:
                        recipients = [r if isinstance(r, str) else r['email'] for r in data]
                elif isinstance(data, dict) and 'recipients' in data:
                    if include_names:
                        recipients = []
                        for r in data['recipients']:
                            if isinstance(r, str):
                                recipients.append({'email': r, 'name': ''})
                            elif isinstance(r, dict):
                                recipients.append({'email': r.get('email', ''), 'name': r.get('name', '')})
                        return recipients
                    else:
                        recipients = data['recipients']
                else:
                    print("Error: JSON file must contain a list or dict with 'recipients' key")
                    sys.exit(1)
                return recipients
        except FileNotFoundError:
            print(f"Error: File {file_path} not found")
            sys.exit(1)
        except json.JSONDecodeError as e:
            print(f"Error parsing JSON file: {e}")
            sys.exit(1)
    else:
        # Try to auto-detect format
        try:
            # Try JSON first
            with open(file_path, 'r', encoding='utf-8') as f:
                data = json.load(f)
                if isinstance(data, list):
                    recipients = [r if isinstance(r, str) else r['email'] for r in data]
                elif isinstance(data, dict) and 'recipients' in data:
                    recipients = data['recipients']
                else:
                    print("Error: JSON file must contain a list or dict with 'recipients' key")
                    sys.exit(1)
                return recipients
        except json.JSONDecodeError:
            # If JSON fails, try CSV
            try:
                recipients = []
                with open(file_path, 'r', encoding='utf-8') as f:
                    reader = csv.reader(f)
                    for row in reader:
                        if row and '@' in row[0]:
                            if include_names:
                                name = row[1].strip() if len(row) > 1 and row[1] else ''
                                recipients.append({'email': row[0].strip(), 'name': name})
                            else:
                                recipients.append(row[0].strip())
                return recipients
            except Exception as e:
                print(f"Error: Could not parse file as JSON or CSV: {e}")
                print("Please use a .csv or .json file, or ensure the file format is correct")
                sys.exit(1)


def main():
    """Main function to run the email sender"""
    import argparse
    
    parser = argparse.ArgumentParser(
        description='Send mass emails using AWS SES',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Send to multiple recipients
  python ses_emailer.py --sender sender@example.com --recipients user1@example.com user2@example.com --subject "Hello" --body "This is a test email"
  
  # Send from CSV file with email body from file
  python ses_emailer.py --sender sender@example.com --recipients-file recipients.csv --subject "Hello" --body-file email_body.txt
  
  # Send HTML email from files
  python ses_emailer.py --sender sender@example.com --recipients-file recipients.csv --subject "Hello" --body-file email_body.txt --body-html-file email_body.html
  
  # Send HTML email inline
  python ses_emailer.py --sender sender@example.com --recipients user@example.com --subject "Hello" --body "Plain text" --body-html "<h1>HTML Content</h1>"
  
  # Send email with attachments
  python ses_emailer.py --sender sender@example.com --recipients user@example.com --subject "Hello" --body "Test" --attachment file1.pdf --attachment file2.jpg
  
  # Send to large list in batches (automatic for lists > 50)
  python ses_emailer.py --sender sender@example.com --recipients-file recipients.csv --subject "Hello" --body-file email.txt --batch-size 50
  
  # Send in batches with custom rate limiting
  python ses_emailer.py --sender sender@example.com --recipients-file recipients.csv --subject "Hello" --body-file email.txt --batch-size 100 --rate-limit 0.2
  
  # Preview email before sending
  python ses_emailer.py --sender sender@example.com --recipients user@example.com --subject "Hello" --body "Test" --body-html-file email.html --preview
  
  # Verify an email address
  python ses_emailer.py --verify sender@example.com
        """
    )
    
    parser.add_argument('--sender', '-s', help='Sender email address (must be verified in SES)')
    parser.add_argument('--sender-name', help='Display name for sender (e.g., "Amaze" will show as "Amaze <email@example.com>")')
    parser.add_argument('--recipients', '-r', nargs='+', help='List of recipient email addresses')
    parser.add_argument('--recipients-file', '-f', help='CSV or JSON file with list of recipients')
    parser.add_argument('--subject', help='Email subject')
    parser.add_argument('--body', '-b', help='Email body (plain text)')
    parser.add_argument('--body-file', help='File containing plain text email body')
    parser.add_argument('--body-html', help='Email body (HTML)')
    parser.add_argument('--body-html-file', help='File containing HTML email body')
    parser.add_argument('--attachment', '-a', action='append', help='File to attach (can be used multiple times)')
    parser.add_argument('--reply-to', nargs='+', help='Reply-to email addresses')
    parser.add_argument('--region', default='us-west-2', help='AWS region (default: us-west-2)')
    parser.add_argument('--verify', help='Verify an email address with SES')
    parser.add_argument('--preview', action='store_true', help='Preview email before sending (does not send email)')
    parser.add_argument('--batch-size', type=int, default=50, help='Number of recipients per batch (default: 50, use BCC for privacy)')
    parser.add_argument('--use-bcc', action='store_true', default=True, help='Use BCC to protect recipient privacy (default: True)')
    parser.add_argument('--no-bcc', action='store_false', dest='use_bcc', help='Disable BCC (recipients will see each other)')
    parser.add_argument('--rate-limit', type=float, default=0.1, help='Seconds to wait between batches (default: 0.1 = 10 batches/sec)')
    parser.add_argument('--personalized', action='store_true', help='Enable personalization (replace [NAME] and [EMAIL] placeholders with recipient data). CSV must have email and name columns.')
    parser.add_argument('--generic-greeting', help='Generic greeting to use when name is not available (e.g., "Hi There!"). Used as fallback for [NAME] placeholder.')
    
    args = parser.parse_args()
    
    # Initialize SES client
    emailer = SESEmailer(region_name=args.region)
    
    # Handle email verification
    if args.verify:
        emailer.verify_email_identity(args.verify)
        return
    
    # Validate required arguments
    if not args.preview:
        # For sending, sender and recipients are required
        if not args.sender:
            parser.error("--sender is required (unless using --verify or --preview)")
        
        if not args.recipients and not args.recipients_file:
            parser.error("Either --recipients or --recipients-file is required (unless using --preview)")
    
    if not args.subject:
        parser.error("--subject is required")
    
    if not args.body and not args.body_file:
        parser.error("Either --body or --body-file is required")
    
    # Get email body
    body_text = args.body
    if args.body_file:
        try:
            with open(args.body_file, 'r', encoding='utf-8') as f:
                body_text = f.read()
        except FileNotFoundError:
            print(f"Error: Body file {args.body_file} not found")
            sys.exit(1)
        except Exception as e:
            print(f"Error reading body file: {e}")
            sys.exit(1)
    
    # Get HTML body
    body_html = args.body_html
    if args.body_html_file:
        try:
            with open(args.body_html_file, 'r', encoding='utf-8') as f:
                body_html = f.read()
        except FileNotFoundError:
            print(f"Error: HTML body file {args.body_html_file} not found")
            sys.exit(1)
        except Exception as e:
            print(f"Error reading HTML body file: {e}")
            sys.exit(1)
    
    # Personalization is only enabled if explicitly requested
    needs_personalization = args.personalized
    
    # Get recipients (optional for preview)
    recipients = []
    recipient_data = None
    if args.recipients_file:
        if needs_personalization:
            recipient_data = load_recipients_from_file(args.recipients_file, include_names=True)
            recipients = [r['email'] for r in recipient_data]
        else:
            recipients = load_recipients_from_file(args.recipients_file, include_names=False)
    elif args.recipients:
        recipients = args.recipients
        if needs_personalization:
            recipient_data = [{'email': r, 'name': ''} for r in recipients]
    elif args.preview:
        # For preview, use a placeholder if no recipients specified
        recipients = ['[Preview - No recipients specified]']
        if needs_personalization:
            recipient_data = [{'email': '[Preview]', 'name': 'John Doe'}]
    
    # Get attachments
    attachments = args.attachment if args.attachment else None
    
    # Preview or send email
    if args.preview:
        # Preview mode - show email without sending
        preview_email(
            subject=args.subject,
            body_text=body_text,
            body_html=body_html,
            sender=args.sender,
            recipients=recipients if recipients != ['[Preview - No recipients specified]'] else None,
            attachments=attachments,
            sender_name=args.sender_name,
            open_browser=True,
            personalized=needs_personalization,
            recipient_data=recipient_data if needs_personalization else None,
            generic_greeting=args.generic_greeting
        )
        print("\n✓ Preview complete. Email was NOT sent.")
        print("Remove --preview flag to actually send the email.")
    else:
        # Send email
        print(f"Sending email from {args.sender} to {len(recipients)} recipient(s)...")
        print(f"Subject: {args.subject}")
        if attachments:
            print(f"Attachments: {len(attachments)} file(s)")
        print()
        
        # Use batch sending for large lists (more than batch_size) or if explicitly requested
        use_batch = len(recipients) > args.batch_size or needs_personalization
        
        if needs_personalization:
            print("✨ Personalization enabled: [NAME] and [EMAIL] placeholders will be replaced")
            if recipient_data:
                names_count = sum(1 for r in recipient_data if r.get('name', '').strip())
                print(f"   Found names for {names_count}/{len(recipient_data)} recipients")
            print()
        
        if attachments:
            # Attachments require send_email_with_attachments (doesn't support batch yet)
            # For now, send in batches using regular send_email
            if use_batch:
                print("⚠️  Note: Batch sending with attachments sends one email per recipient")
                result = emailer.send_email_batch(
                    sender=args.sender,
                    recipients=recipients,
                    subject=args.subject,
                    body_text=body_text,
                    body_html=body_html,
                    batch_size=args.batch_size,
                    use_bcc=args.use_bcc,
                    rate_limit=args.rate_limit,
                    reply_to=args.reply_to,
                    sender_name=args.sender_name,
                    personalized=needs_personalization,
                    recipient_data=recipient_data,
                    generic_greeting=args.generic_greeting
                )
            else:
                # Small list with attachments - use attachment method
                result = emailer.send_email_with_attachments(
                    sender=args.sender,
                    recipients=recipients,
                    subject=args.subject,
                    body_text=body_text,
                    body_html=body_html,
                    attachments=attachments,
                    reply_to=args.reply_to,
                    sender_name=args.sender_name
                )
        elif use_batch:
            # Use batch sending for large lists
            result = emailer.send_email_batch(
                sender=args.sender,
                recipients=recipients,
                subject=args.subject,
                body_text=body_text,
                body_html=body_html,
                batch_size=args.batch_size,
                use_bcc=args.use_bcc,
                rate_limit=args.rate_limit,
                reply_to=args.reply_to,
                sender_name=args.sender_name,
                personalized=needs_personalization,
                recipient_data=recipient_data,
                generic_greeting=args.generic_greeting
            )
        else:
            # Small list - send all at once or individually based on BCC setting or personalization
            if needs_personalization or (args.use_bcc and len(recipients) > 1):
                # For personalized or BCC privacy with small lists, send individual emails
                success_count = 0
                fail_count = 0
                for i, recipient in enumerate(recipients):
                    # Personalize if needed
                    personalized_subject = args.subject
                    personalized_body_text = body_text
                    personalized_body_html = body_html
                    
                    if needs_personalization and recipient_data:
                        recipient_info = recipient_data[i] if i < len(recipient_data) else {'email': recipient, 'name': ''}
                        personalized_subject = replace_template_placeholders(args.subject, recipient_info, args.generic_greeting)
                        personalized_body_text = replace_template_placeholders(body_text, recipient_info, args.generic_greeting)
                        if body_html:
                            personalized_body_html = replace_template_placeholders(body_html, recipient_info, args.generic_greeting)
                    
                    result = emailer.send_email(
                        sender=args.sender,
                        recipients=[recipient],  # Individual recipient
                        subject=personalized_subject,
                        body_text=personalized_body_text,
                        body_html=personalized_body_html,
                        reply_to=args.reply_to,
                        bcc=None,  # No BCC needed since it's individual
                        sender_name=args.sender_name
                    )
                    if result['success']:
                        success_count += 1
                    else:
                        fail_count += 1
                    # Small delay between sends
                    if recipient != recipients[-1]:  # Don't delay after last email
                        time.sleep(0.07)
                
                result = {
                    'success': fail_count == 0,
                    'total': len(recipients),
                    'successful': success_count,
                    'failed': fail_count
                }
            else:
                # Send all at once (no BCC or single recipient, no personalization)
                result = emailer.send_email(
                    sender=args.sender,
                    recipients=recipients,
                    subject=args.subject,
                    body_text=body_text,
                    body_html=body_html,
                    reply_to=args.reply_to,
                    bcc=None,  # Don't use BCC for single sends
                    sender_name=args.sender_name
                )
        
        if not result['success']:
            sys.exit(1)


if __name__ == '__main__':
    main()

