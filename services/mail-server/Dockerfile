FROM alpine:3.18

# Install required packages
RUN apk add --no-cache \
    postfix \
    postfix-pcre \
    ca-certificates \
    cyrus-sasl \
    cyrus-sasl-login \
    mailx \
    openssl \
    tzdata \
    bash \
    coreutils

# Create temporary minimal configuration to use postalias
RUN echo "myhostname = localhost" > /etc/postfix/main.cf

# Create required directories
RUN mkdir -p /etc/postfix/sasl /var/spool/postfix /var/mail /var/log/mail

# Create and process alias file
RUN echo "# Basic system aliases" > /etc/aliases && \
    echo "mailer-daemon: root" >> /etc/aliases && \
    echo "postmaster: root" >> /etc/aliases && \
    echo "nobody: root" >> /etc/aliases && \
    echo "hostmaster: root" >> /etc/aliases && \
    echo "webmaster: root" >> /etc/aliases && \
    echo "www: root" >> /etc/aliases && \
    echo "root: root" >> /etc/aliases && \
    postalias /etc/aliases

# Copy configuration files
COPY postfix-main.cf /etc/postfix/main.cf.template
COPY start.sh /start.sh

# Set permissions
RUN chmod 755 /start.sh && \
    chmod -R 644 /etc/postfix/ && \
    chmod 755 /etc/postfix && \
    update-ca-certificates

# Create volume for mail storage and logs
VOLUME ["/var/mail", "/var/log/mail"]

# Expose ports
EXPOSE 25 587

# Set command
CMD ["/start.sh"] 