# ====================================================================
# DMZ Web Server - Vulnerable PHP App with Command Injection
# Entry point untuk attack chain
# ====================================================================
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# Install base packages + Apache + PHP + tools
RUN apt-get update && apt-get install -y \
    apache2 \
    php \
    libapache2-mod-php \
    openssh-client \
    curl \
    wget \
    netcat-traditional \
    iproute2 \
    iputils-ping \
    net-tools \
    auditd \
    lsb-release \
    gnupg \
    sudo \
    vim \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install Wazuh agent
RUN curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --no-default-keyring --keyring gnupg-ring:/usr/share/keyrings/wazuh.gpg --import && \
    chmod 644 /usr/share/keyrings/wazuh.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" > /etc/apt/sources.list.d/wazuh.list && \
    apt-get update && \
    WAZUH_MANAGER="172.30.0.10" apt-get install -y wazuh-agent=4.7.5-1 && \
    rm -rf /var/lib/apt/lists/*

# Setup vulnerable PHP web app
COPY app/ /var/www/html/
RUN chown -R www-data:www-data /var/www/html

# Setup SSH key untuk lateral movement (deliberately leaked)
RUN mkdir -p /home/webapp/.ssh && \
    useradd -m -s /bin/bash webapp 2>/dev/null || true

# Copy SSH private key untuk pivot ke internal-app
COPY ssh_keys/id_rsa /home/webapp/.ssh/id_rsa
RUN chmod 600 /home/webapp/.ssh/id_rsa && \
    chown -R webapp:webapp /home/webapp/.ssh

# Make key accessible by www-data juga (simulating misconfig)
RUN cp /home/webapp/.ssh/id_rsa /var/www/html/.maintenance_key && \
    chown www-data:www-data /var/www/html/.maintenance_key && \
    chmod 644 /var/www/html/.maintenance_key

# Setup auditd rules
COPY audit.rules /etc/audit/rules.d/cyber-range.rules

# Wazuh agent config
COPY ossec.conf /var/ossec/etc/ossec.conf

# Apache config
RUN a2enmod rewrite

# Entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 80

ENTRYPOINT ["/entrypoint.sh"]
