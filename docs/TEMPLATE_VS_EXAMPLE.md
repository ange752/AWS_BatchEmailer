# Email Template vs Email Body Example - What's the Difference?

## Quick Answer

- **`email_template.*`** = **Working files** - Edit these and use them to send your actual emails
- **`email_body_example.*`** = **Reference files** - Examples showing formatting techniques (for learning/reference)

## Detailed Comparison

### `email_template.txt` and `email_template.html`

**Purpose:** Ready-to-use templates that you customize for your actual emails

**Characteristics:**
- ✅ **Meant to be edited** - Contains placeholder text and instructions
- ✅ **Use for sending** - These are the files you'll actually use with the script
- ✅ **Simple structure** - Easy to customize with your content
- ✅ **Practical** - Includes placeholders like "Your Name", "Your Company"

**Content:**
- Plain text version has instructions on what to customize
- HTML version has a clean, professional design ready for your content
- Both are designed to be modified before sending

**Usage:**
```bash
# Edit email_template.txt and email_template.html with your content
# Then send:
python ses_emailer.py \
  --body-file email_template.txt \
  --body-html-file email_template.html \
  --subject "Your Subject" \
  --recipients-file test_recipients.csv
```

---

### `email_body_example.txt` and `email_body_example.html`

**Purpose:** Reference examples demonstrating formatting best practices

**Characteristics:**
- 📚 **For learning** - Shows formatting techniques and best practices
- 📚 **Reference material** - Use to understand how to format emails
- 📚 **More detailed** - Includes formatting tips and examples
- 📚 **Not meant for direct use** - More of a guide/reference

**Content:**
- Plain text version includes formatting tips and examples
- HTML version shows advanced styling options
- Both demonstrate best practices

**Usage:**
- Read these files to learn formatting techniques
- Copy formatting ideas into your `email_template.*` files
- Use as a reference when creating your own emails

---

## Which Should You Use?

### For Sending Emails:
✅ **Use `email_template.*` files**
- Edit them with your actual content
- Use them with the script to send emails

### For Learning Formatting:
📚 **Refer to `email_body_example.*` files**
- Study the formatting techniques
- Copy useful patterns into your templates

## Workflow Recommendation

1. **Start with `email_template.*`** - These are your working files
2. **Reference `email_body_example.*`** - If you need formatting ideas
3. **Edit `email_template.*`** - Customize with your content
4. **Preview** - Use `--preview` flag to see how it looks
5. **Send** - Remove `--preview` and send your email

## File Summary

| File | Purpose | Edit? | Use for Sending? |
|------|---------|-------|------------------|
| `email_template.txt` | Working template | ✅ Yes | ✅ Yes |
| `email_template.html` | Working template | ✅ Yes | ✅ Yes |
| `email_body_example.txt` | Reference/example | ❌ No | ❌ No |
| `email_body_example.html` | Reference/example | ❌ No | ❌ No |

## Quick Tip

Think of it this way:
- **`email_template.*`** = Your blank document (edit and use)
- **`email_body_example.*`** = A style guide (read and learn from)

