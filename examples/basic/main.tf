module "vault_aws_auth" {
  source = "../../"
  # source = "git@github.com:songlining/terraform-aws-vault-agent-auth-role.git"
  # Using default values for simplicity
  aws_region    = "ap-southeast-2"
  instance_type = "t4g.small"
}

output "vault_server_private_ip" {
  value = module.vault_aws_auth.vault_server_private_ip
  description = "Private IP address of the Vault server"
}

output "vault_agent_public_ip" {
  value = module.vault_aws_auth.vault_agent_public_ip
  description = "Public IP address of the Vault agent"
}