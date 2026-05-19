# ====================================================================
# Internal App Server - SSH pivot point dengan DB credential di config
# Lateral target untuk attacker setelah dapat shell di DMZ
# ====================================================================
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# Install dependencies
RUN apt-get update && apt-get install -y \
    openssh-server \
    mysql-client \
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

# Setup SSH server
RUN mkdir -p /run/sshd /var/run/sshd
RUN echo 'PermitRootLogin no' >> /etc/ssh/sshd_config && \
    echo 'PasswordAuthentication no' >> /etc/ssh/sshd_config && \
    echo 'PubkeyAuthentication yes' >> /etc/ssh/sshd_config

# Create webapp user (target buat SSH dari dmz-web)
RUN useradd -m -s /bin/bash webapp && \
    mkdir -p /home/webapp/.ssh && \
    chown webapp:webapp /home/webapp/.ssh && \
    chmod 700 /home/webapp/.ssh

# Copy authorized_keys (matching public key dari dmz-web private key)
COPY ssh_keys/id_rsa.pub /home/webapp/.ssh/authorized_keys
RUN chown webapp:webapp /home/webapp/.ssh/authorized_keys && \
    chmod 600 /home/webapp/.ssh/authorized_keys

# Plant DB credentials - intentional bad practice for lab
RUN mkdir -p /home/webapp/app/config
COPY app_config/database.yml /home/webapp/app/config/database.yml
COPY app_config/.env /home/webapp/app/.env
RUN chown -R webapp:webapp /home/webapp/app

# Bash history dengan command-command sebelumnya
COPY app_config/bash_history /home/webapp/.bash_history
RUN chown webapp:webapp /home/webapp/.bash_history && \
    chmod 600 /home/webapp/.bash_history

# Auditd rules
COPY audit.rules /etc/audit/rules.d/cyber-range.rules

# Wazuh agent config
COPY ossec.conf /var/ossec/etc/ossec.conf

# Entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 22

ENTRYPOINT ["/entrypoint.sh"]
