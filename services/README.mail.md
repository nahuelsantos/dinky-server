# Self-Hosted Mail Service for Contact Forms

This service provides a simple self-hosted email solution specifically designed for handling contact form submissions from your websites.

## Components

1. **Postfix Mail Server**: A lightweight SMTP server for sending emails (in services/mail-server)
2. **Go Mail API**: A simple HTTP API that your web applications can use to send emails (in apis/mail-api)

## Setup Instructions

1. Navigate to the services directory:
   ```
   cd services
   ```

2. Set up firewall rules (requires sudo):
   ```
   sudo ./mail-server/ufw-setup.sh
   ```

3. Start the services:
   ```
   docker-compose -f docker-compose.mail.yml up -d
   ```

4. The mail API will be available at `http://mail-api.dinky.local` through Traefik

## Network Configuration

- **SMTP Server**: Exposed on ports 25 and 587
- **Mail API**: Exposed via Traefik at `mail-api.dinky.local`

### DNS Configuration

Add the following to your local hosts file or DNS server:
```
127.0.0.1 mail-api.dinky.local
```

## Project Structure

```
dinky-server/
├── services/
│   ├── mail-server/        # Postfix SMTP server
│   │   └── ufw-setup.sh    # Firewall configuration script
│   └── docker-compose.mail.yml  # Combined Docker Compose file
├── apis/
│   └── mail-api/           # Go API for sending emails
```

## API Usage

To send an email from your web applications, make a POST request to the mail API:

```
POST http://mail-api.dinky.local/send

{
  "to": "recipient@example.com",
  "subject": "Contact Form Submission",
  "body": "Name: John Doe\nEmail: john@example.com\nMessage: Hello, I'd like to inquire about your services.",
  "html": false
}
```

### API Fields

- `to`: (Required) Email address of the recipient
- `from`: (Optional) Email address of the sender (defaults to noreply@dinky.local)
- `subject`: (Required) Subject of the email
- `body`: (Required) Content of the email
- `html`: (Optional) Set to true if the body contains HTML content

## Example Integration with a Website Contact Form

Here's how you might integrate this with a contact form on your website:

### JavaScript Example

```javascript
document.getElementById('contact-form').addEventListener('submit', async function(e) {
  e.preventDefault();
  
  const name = document.getElementById('name').value;
  const email = document.getElementById('email').value;
  const message = document.getElementById('message').value;
  
  const formData = {
    to: "your-email@example.com",
    subject: "New Contact Form Submission",
    body: `Name: ${name}\nEmail: ${email}\nMessage: ${message}`,
    html: false
  };
  
  try {
    const response = await fetch('http://mail-api.dinky.local/send', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(formData)
    });
    
    const result = await response.json();
    
    if (result.success) {
      alert('Your message has been sent successfully!');
    } else {
      alert('Failed to send message: ' + result.message);
    }
  } catch (error) {
    alert('Error sending message: ' + error.message);
  }
});
```

## Maintenance

- Mail logs are stored in the `mail-logs` volume
- Sent emails are stored in the `mail-data` volume

To check the mail server logs:

```
docker logs mail-server
```

To check the API logs:

```
docker logs mail-api
```

## Troubleshooting

### Checking SMTP Connectivity

To test if your SMTP server is reachable:
```
telnet localhost 25
```

You should see a connection and a greeting message from the mail server.

### Testing Email Sending

To test if emails can be sent through the mail server:
```
echo "Subject: Test Email" | sendmail -v recipient@example.com
```

### Checking Firewall Rules

To verify the firewall is configured correctly:
```
sudo ufw status | grep -E '25|587'
```

You should see rules allowing traffic on ports 25 and 587. 