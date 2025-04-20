FROM alpine:3.18

# Install packages with corrected package names that work on ARM architectures
RUN apk add --no-cache postfix postfix-pcre ca-certificates mailx cyrus-sasl cyrus-sasl-login cyrus-sasl-plain || \
    apk add --no-cache postfix postfix-pcre ca-certificates mailx cyrus-sasl cyrus-sasl-login cyrus-sasl-crammd5

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
    postmap /etc/postfix/sasl/sasl_passwd && \
    chmod 600 /etc/postfix/sasl/sasl_passwd.db || true

EXPOSE 25 587

CMD ["/start.sh"] 