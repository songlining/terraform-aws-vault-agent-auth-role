#!/bin/bash

#set -e

# Update system packages
yum update -y

# Install necessary packages
yum install -y jq unzip openssl

# Download and install Vault
VAULT_VERSION="${vault_version}"
curl -O "https://releases.hashicorp.com/vault/$${VAULT_VERSION}/vault_$${VAULT_VERSION}_linux_arm64.zip"
unzip "vault_$${VAULT_VERSION}_linux_arm64.zip"
mv vault /usr/local/bin/
chmod +x /usr/local/bin/vault

# Create Vault directories
mkdir -p /etc/vault.d
mkdir -p /opt/vault/data
mkdir -p /opt/vault/tls

# Get the public DNS name of this EC2 instance
export TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
PUBLIC_DNS=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/public-hostname)
echo "Public DNS: $PUBLIC_DNS"

# Generate SSL certificate and private key
openssl req -x509 -newkey rsa:4096 -keyout /opt/vault/tls/vault-key.pem -out /opt/vault/tls/vault-cert.pem -days 365 -nodes -subj "/CN=$PUBLIC_DNS" -addext "subjectAltName=DNS:$PUBLIC_DNS,DNS:localhost,IP:127.0.0.1"

# Set proper permissions on certificate files
chmod 600 /opt/vault/tls/vault-key.pem
chmod 644 /opt/vault/tls/vault-cert.pem
chown root:root /opt/vault/tls/*

# Create Vault server configuration with HTTPS
cat > /etc/vault.d/vault.hcl << EOF
ui = true

storage "file" {
  path = "/opt/vault/data"
}

listener "tcp" {
  address       = "0.0.0.0:8200"
  tls_cert_file = "/opt/vault/tls/vault-cert.pem"
  tls_key_file  = "/opt/vault/tls/vault-key.pem"
}

api_addr = "https://$PUBLIC_DNS:8200"
cluster_addr = "https://$PUBLIC_DNS:8201"

log_level = "debug"
EOF

# Create Vault systemd service
cat > /etc/systemd/system/vault.service << EOF
[Unit]
Description=Vault Service
Requires=network-online.target
After=network-online.target

[Service]
Type=simple
User=root
Group=root
ExecStart=/usr/local/bin/vault server -config=/etc/vault.d/vault.hcl
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

# Start and enable Vault service
systemctl daemon-reload
systemctl enable vault
systemctl start vault

# Wait for Vault to start
sleep 10

# Initialize Vault with HTTPS
export VAULT_ADDR=https://127.0.0.1:8200
export VAULT_SKIP_VERIFY=true  # Skip TLS verification for self-signed cert
vault operator init -format=json > /root/vault-init.json

# Unseal Vault
for i in {0..2}; do
  UNSEAL_KEY=$(jq -r ".unseal_keys_b64[$i]" /root/vault-init.json)
  vault operator unseal $UNSEAL_KEY
done

# Set root token for further operations
export VAULT_TOKEN=$(jq -r .root_token /root/vault-init.json)

# Enable audit logging
vault audit enable file file_path=/var/log/vault_audit.log

# Enable required secret engines
vault secrets enable database
vault secrets enable pki
vault secrets enable ssh

# Enable and configure AWS auth method for Vault agent authentication
vault auth enable aws

# Create KV policy
cat > /etc/vault.d/kv-policy.hcl << EOF
path "secret/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
EOF

# Write the policy to Vault
vault policy write kv-access /etc/vault.d/kv-policy.hcl

# Configure AWS auth role for the Vault agent
vault write auth/aws/role/vault-agent \
  auth_type=iam \
  bound_iam_principal_arn="arn:aws:iam::${aws_account_id}:role/vault-agent-role" \
  policies=default,kv-access \
  ttl=24h

# the following is for github jwt integration
# 1. Enable JWT auth method
vault auth enable jwt

# 2. Configure JWT auth method for GitHub
vault write auth/jwt/config \
  bound_issuer="https://token.actions.githubusercontent.com" \
  oidc_discovery_url="https://token.actions.githubusercontent.com"

# 3. Create a policy for your secrets
vault policy write myproject-policy - <<EOF
# Read-only permission on your secret path
path "kv-v2/data/myapp" {
  capabilities = [ "read" ]
}
EOF

# 4. Create a role that binds to your GitHub repository
#    update to match your environemnt
# subject claim: "repo:songlining/github-action-vault-demo:environment:dev"
vault write auth/jwt/role/myproject-github-role-dev -<<EOF
{
  "role_type": "jwt",
  "user_claim": "sub",
  "bound_audiences": ["https://github.com/songlining/github-action-vault-demo"],
  "bound_claims": {
    "repository": "songlining/github-action-vault-demo",
    "environment": "dev"
  },
  "policies": ["myproject-policy"],
  "ttl": "10m"
}
EOF

vault secrets enable kv-v2
vault kv put kv-v2/myapp username=larry password=123 # used by the github action

echo "Vault server setup complete with HTTPS enabled!"
echo "Vault is accessible at: https://$PUBLIC_DNS:8200"
echo "Certificate details saved in /opt/vault/tls/"

cat >> /home/ec2-user/.bashrc << EOF
export VAULT_ADDR=https://localhost:8200
export VAULT_TOKEN=$VAULT_TOKEN
export VAULT_SKIP_VERIFY=true
EOF