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

2. Copy the environment file and edit it:
   ```
   cp .env.mail .env.mail.prod
   nano .env.mail.prod  # or use your preferred editor
   ```

3. Set up firewall rules (requires sudo):
   ```
   sudo ./mail-server/ufw-setup.sh
   ```

4. Start the services:
   ```
   docker-compose -f docker-compose.mail.prod.yml --env-file .env.mail.prod up -d
   ```

5. The mail API will be available at `http://mail-api.dinky.local` through Traefik

## Using Gmail as SMTP Relay (Recommended)

Direct mail delivery is often blocked by ISPs and cloud providers. Using Gmail as an SMTP relay significantly improves deliverability.

### Why use Gmail SMTP relay?

- **Improved Deliverability**: Emails sent through Gmail are less likely to be marked as spam
- **ISP Port Blocking**: Many ISPs and cloud providers block outgoing port 25, making direct mail delivery unreliable
- **Reputation**: Gmail has a good sending reputation, which helps your emails reach inboxes

### Setting up Gmail SMTP Relay

1. **Create an App Password in Gmail**:
   - Go to https://myaccount.google.com/security
   - Enable 2-Step Verification if not already enabled
   - Go to https://myaccount.google.com/apppasswords
   - Select "Mail" and "Other (Custom name)" - enter "Dinky Server"
   - Copy the 16-character password

2. **Configure your .env.mail.prod file**:
   ```
   RELAY_HOST=smtp.gmail.com
   RELAY_PORT=587
   RELAY_USER=your-gmail-address@gmail.com
   RELAY_PASSWORD=your-16-character-app-password
   ```

3. **Restart the mail services**:
   ```
   docker-compose -f docker-compose.mail.prod.yml --env-file .env.mail.prod down
   docker-compose -f docker-compose.mail.prod.yml --env-file .env.mail.prod up -d
   ```

4. **Verify SMTP Relay Configuration**:
   ```
   docker logs mail-server
   ```
   Look for messages containing "relay=smtp.gmail.com"

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

### Troubleshooting Gmail SMTP Relay

If you're having issues with Gmail SMTP relay:

1. **Check Authentication**: Verify your Gmail username and App Password:
   ```
   docker exec -it mail-server cat /etc/postfix/sasl/sasl_passwd
   ```

2. **Check Gmail Settings**: Make sure:
   - 2-Step Verification is enabled
   - The App Password was generated correctly (for "Mail" app)
   - Your account doesn't have any security blocks (check Gmail security alerts)

3. **Test Authentication**: Try manually connecting to Gmail SMTP:
   ```
   docker exec -it mail-server openssl s_client -starttls smtp -crlf -connect smtp.gmail.com:587
   ```
   Then enter these commands one by one:
   ```
   EHLO localhost
   AUTH LOGIN
   [enter base64-encoded username]
   [enter base64-encoded password]
   ```
   You should get a "235 2.7.0 Authentication successful" message.

4. **View Detailed Logs**: Enable verbose logging and check for authentication errors:
   ```
   docker exec -it mail-server postconf -e "debug_peer_list=smtp.gmail.com"
   docker exec -it mail-server postfix reload
   docker logs mail-server
   ```

5. **Common Error Messages**:
   - "530 5.7.0 Authentication Required": Gmail requires authentication
   - "535 5.7.8 Authentication failed": Wrong username or password
   - "454 4.7.0 Too many login attempts": Too many failed logins, try again later

### Checking Firewall Rules

To verify the firewall is configured correctly:
```
sudo ufw status | grep -E '25|587'
```

You should see rules allowing traffic on ports 25 and 587. 