#!/bin/bash
# EC2 command to send with EMAIL3 template
# Run this on EC2 instance

./ec2_send_custom.sh \
  TaxEmailList_1.csv \
  1099_TAX_EMAIL3 \
  "Action Required: Verify Your Tax Details on Spring" \
  creatorhelp@amaze.co \
  "Creator Help"
