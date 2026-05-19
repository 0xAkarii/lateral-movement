# ====================================================================
# Database Server - MySQL dengan customer data (crown jewel)
# Final target untuk attack chain
# ====================================================================
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

RUN apt-get update && apt-get install -y \
    mysql-server \
    mysql-client \
    curl \
    wget \
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

# Configure MySQL
RUN mkdir -p /var/run/mysqld && \
    chown mysql:mysql /var/run/mysqld

# MySQL bind to all interfaces
RUN sed -i 's/bind-address.*/bind-address = 0.0.0.0/g' /etc/mysql/mysql.conf.d/mysqld.cnf 2>/dev/null || true

# Init scripts - dijalankan saat MySQL pertama startup
COPY init/ /docker-entrypoint-initdb.d/

# Auditd rules
COPY audit.rules /etc/audit/rules.d/cyber-range.rules

# Wazuh agent config
COPY ossec.conf /var/ossec/etc/ossec.conf

# Entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 3306

ENTRYPOINT ["/entrypoint.sh"]
