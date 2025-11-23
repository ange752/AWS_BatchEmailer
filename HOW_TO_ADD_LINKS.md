# How to Add Links to Your Email Templates

## HTML Email Template (`email_template.html`)

### Basic Link

```html
<a href="https://example.com">Click here</a>
```

**Example:**
```html
<p>Visit our <a href="https://example.com">website</a> for more information.</p>
```

### Link with Custom Styling

```html
<a href="https://example.com" style="color: #4CAF50; text-decoration: underline;">Visit our site</a>
```

### Button-Style Link

Your template already has a button style defined. You can use it like this:

```html
<a href="https://example.com" class="button">Click Here</a>
```

**Example from your template:**
```html
<!-- Uncomment and customize this: -->
<a href="https://example.com" class="button">Click Here</a>
```

### Link in a Paragraph

```html
<p>
    For more details, please visit 
    <a href="https://example.com" style="color: #4CAF50;">our website</a> 
    or contact us at 
    <a href="mailto:support@example.com">support@example.com</a>.
</p>
```

### Email Link (mailto)

```html
<a href="mailto:support@example.com">Email us</a>
```

### Link Opening in New Tab

```html
<a href="https://example.com" target="_blank" rel="noopener noreferrer">Open in new tab</a>
```

**Note:** Some email clients may ignore `target="_blank`, but it's good practice to include it.

---

## Plain Text Email Template (`email_template.txt`)

In plain text emails, you can't create clickable links with styling, but you can include URLs that email clients will automatically make clickable.

### Simple URL

Just paste the full URL:
```
Visit our website at https://example.com
```

### URL with Description

```
For more information, visit: https://example.com
```

### Email Address

```
Contact us at: support@example.com
```

### Best Practice Format

```
Visit our website:
https://example.com

Or contact us:
support@example.com
```

---

## Examples for Your Templates

### HTML Template Example

```html
<div class="content">
    <h2>Hello,</h2>
    
    <p>Thank you for your interest! Here are some useful links:</p>
    
    <ul>
        <li>Visit our <a href="https://example.com">main website</a></li>
        <li>Check out our <a href="https://example.com/products">products</a></li>
        <li>Read our <a href="https://example.com/blog">blog</a></li>
    </ul>
    
    <a href="https://example.com/signup" class="button">Sign Up Now</a>
    
    <p>Questions? <a href="mailto:support@example.com">Email us</a> anytime!</p>
</div>
```

### Plain Text Template Example

```
Hello,

Thank you for your interest! Here are some useful links:

- Main website: https://example.com
- Products: https://example.com/products
- Blog: https://example.com/blog

Sign up here: https://example.com/signup

Questions? Email us at: support@example.com
```

---

## Important Tips

1. **Always use full URLs** - Include `https://` or `http://`
   - ✅ Good: `https://example.com`
   - ❌ Bad: `example.com` or `www.example.com`

2. **Test your links** - Make sure all links work before sending

3. **Email links** - Use `mailto:` for email addresses
   - Example: `<a href="mailto:support@example.com">Email us</a>`

4. **Button links** - Your template has a `.button` class already styled - just uncomment and use it!

5. **Plain text** - Email clients will auto-detect URLs, but including the full URL is best practice

---

## Quick Reference

| Type | HTML | Plain Text |
|------|------|------------|
| Website link | `<a href="https://example.com">Text</a>` | `https://example.com` |
| Email link | `<a href="mailto:email@example.com">Email</a>` | `email@example.com` |
| Button link | `<a href="https://example.com" class="button">Button</a>` | N/A (plain text only) |

