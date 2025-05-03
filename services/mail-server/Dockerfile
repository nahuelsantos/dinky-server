FROM alpine:3.18

# Install packages with corrected package names that work on Alpine
RUN apk add --no-cache \
    postfix \
    postfix-pcre \
    ca-certificates \
    mailx \
    cyrus-sasl \
    cyrus-sasl-login \
    openssl \
    netcat-openbsd \
    # Ensure nc and bash are available for health checks and scripts
    bash \
    # Make sure we have all tools needed for mail server
    findutils \
    coreutils

# Ensure the postmap functionality works
RUN mkdir -p /etc/postfix/databases

# Create necessary directories
RUN mkdir -p /etc/postfix/sasl /var/spool/mail

# Copy configuration files
COPY ./postfix-main.cf /etc/postfix/main.cf
COPY ./sasl/sasl_passwd /etc/postfix/sasl/sasl_passwd
COPY ./start.sh /start.sh

# Set permissions and prepare the environment
RUN chmod +x /start.sh && \
    chmod 600 /etc/postfix/sasl/sasl_passwd && \
    touch /var/log/mail.log && \
    update-ca-certificates

# Note: postmap operation moved to start.sh to ensure it works correctly

EXPOSE 25 587

CMD ["/start.sh"] 