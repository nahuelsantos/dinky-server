# Using Gmail SMTP Relay

This guide explains how to configure Gmail SMTP relay for improved email deliverability with your Dinky Server mail services.

## Why Use Gmail SMTP Relay?

There are several important benefits to using Gmail as an SMTP relay:

1. **Improved Deliverability**: Emails sent through Gmail are less likely to be marked as spam
2. **Bypass ISP Restrictions**: Many ISPs and cloud providers block outgoing port 25, making direct mail delivery unreliable
3. **Better Reputation**: Gmail has a good sending reputation, which helps your emails reach recipients' inboxes
4. **Reliable Delivery**: Gmail's infrastructure is highly reliable for email delivery

## Prerequisites

Before setting up Gmail SMTP relay, you need:

- A Google account (preferably a Gmail account dedicated to your server)
- 2-Step Verification enabled on your Google account
- Access to your Dinky Server mail service configuration

## Step 1: Enable 2-Step Verification

If you haven't already enabled 2-Step Verification:

1. Go to your [Google Account Security](https://myaccount.google.com/security) page
2. Scroll to the "Signing in to Google" section
3. Click on "2-Step Verification"
4. Follow the on-screen instructions to enable it

## Step 2: Generate an App Password

1. Go to [App Passwords](https://myaccount.google.com/apppasswords) in your Google Account
2. You may need to sign in again
3. At the bottom, select "Mail" as the app
4. Select "Other (Custom name)" for the device
5. Enter "Dinky Server" or another recognizable name
6. Click "Generate"
7. Google will display a 16-character password - **copy this password immediately** as it will only be shown once

## Step 3: Configure Dinky Server Mail Services

1. Edit your mail service environment file:

   ```bash
   nano /path/to/dinky-server/services/.env.mail.prod
   ```

2. Add or update the following SMTP relay settings:

   ```
   # Gmail SMTP Relay Configuration
   SMTP_RELAY_HOST=smtp.gmail.com
   SMTP_RELAY_PORT=587
   SMTP_RELAY_USERNAME=your-gmail-address@gmail.com
   SMTP_RELAY_PASSWORD=your-16-character-app-password
   USE_TLS=yes
   TLS_VERIFY=yes
   ```

3. Save the file and exit the editor

## Step 4: Restart Mail Services

Restart the mail services to apply the new configuration:

```bash
cd /path/to/dinky-server
docker-compose -f services/docker-compose.mail.prod.yml --env-file services/.env.mail.prod down
docker-compose -f services/docker-compose.mail.prod.yml --env-file services/.env.mail.prod up -d
```

## Step 5: Verify the Configuration

1. Check the mail server logs to verify that the SMTP relay is configured:

   ```bash
   docker logs mail-server
   ```

2. Look for output similar to:

   ```
   Mail server configuration:
   -------------------------
   Hostname: mail.yourdomain.com
   Domain: yourdomain.com
   Default From: noreply@yourdomain.com
   Relay: smtp.gmail.com:587
   Relay User: your-gmail-address@gmail.com
   -------------------------
   ```

3. Send a test email:

   ```bash
   docker exec mail-server echo "This is a test" | mail -s "Test Email" your-test-email@example.com
   ```

4. Check the mail server logs again to see if the email was relayed successfully:

   ```bash
   docker logs mail-server | grep relay=
   ```

   You should see a line indicating successful relay through Gmail.

## Troubleshooting

### Authentication Failures

If you see authentication failures in the logs:

1. Verify that you've entered the correct Gmail address
2. Confirm that you're using the App Password, not your regular Google account password
3. Make sure 2-Step Verification is enabled
4. Try generating a new App Password

### TLS/SSL Errors

If you encounter TLS/SSL errors:

1. Verify that `USE_TLS=yes` is set in your configuration
2. Check that port 587 is being used (not 465)
3. Ensure that your server has current CA certificates installed

### Rate Limiting

Gmail has sending limits:

- Personal Gmail accounts: 500 emails per day
- Google Workspace accounts: Higher limits depending on your plan

If you're sending high volumes of email, consider a Google Workspace account or a dedicated email service provider.

## Security Considerations

1. **Dedicated Account**: Consider using a dedicated Gmail account for your server
2. **Regular Monitoring**: Check the logs regularly for any issues
3. **Password Rotation**: Update your App Password periodically
4. **Limited Scope**: The App Password only grants access to the specific service (mail), not your entire Google account

## Next Steps

- Return to the [Mail Service Setup Guide](setup.md)
- Check the [Troubleshooting Guide](troubleshooting.md) if you encounter issues 