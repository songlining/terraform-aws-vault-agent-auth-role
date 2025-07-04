#!/bin/bash

#set -e

# Update system packages
yum update -y

# Install necessary packages
yum install -y jq unzip

# Download and install Vault
VAULT_VERSION="${vault_version}"
curl -O "https://releases.hashicorp.com/vault/$${VAULT_VERSION}/vault_$${VAULT_VERSION}_linux_arm64.zip"
unzip "vault_$${VAULT_VERSION}_linux_arm64.zip"
mv vault /usr/local/bin/
chmod +x /usr/local/bin/vault

# Create Vault agent directories
mkdir -p /etc/vault.d
mkdir -p /opt/vault/agent-data

# Create Vault agent configuration
cat > /etc/vault.d/vault-agent.hcl << EOF
exit_after_auth = false
pid_file = "/opt/vault/agent-data/vault-agent.pid"

auto_auth {
  method "aws" {
    mount_path = "auth/aws"
    config = {
      type = "iam"
      role = "vault-agent"
    }
  }

  sink "file" {
    config = {
      path = "/opt/vault/agent-data/vault-token"
    }
  }
}

vault {
  address = "https://${vault_server_ip}:8200"
  tls_skip_verify = true
}

cache {
  use_auto_auth_token = true
}

listener "tcp" {
  address = "127.0.0.1:8100"
  tls_disable = true
}
EOF

# Create Vault agent systemd service
cat > /etc/systemd/system/vault-agent.service << EOF
[Unit]
Description=Vault Agent Service
Requires=network-online.target
After=network-online.target

[Service]
Type=simple
User=root
Group=root
ExecStart=/usr/local/bin/vault agent -config=/etc/vault.d/vault-agent.hcl
ExecReload=/bin/kill -HUP \$MAINPID
KillSignal=SIGINT
Restart=on-failure
RestartSec=5
TimeoutStopSec=30
StartLimitInterval=60
StartLimitBurst=3

[Install]
WantedBy=multi-user.target
EOF

# Start and enable Vault agent service
systemctl daemon-reload
systemctl enable vault-agent
systemctl start vault-agent

# add vault settings to root's .bashrc
cat >> /root/.bashrc << 'EOF'
export VAULT_ADDR=https://${vault_server_ip}:8200
export VAULT_TOKEN=$(cat /opt/vault/agent-data/vault-token)
export VAULT_SKIP_VERIFY=true
EOF

cat >> /home/ec2-user/.bashrc << 'EOF'
export VAULT_ADDR=https://${vault_server_ip}:8200
export VAULT_TOKEN=$(cat /opt/vault/agent-data/vault-token)
export VAULT_SKIP_VERIFY=true
EOF

echo "Vault agent setup complete!"
