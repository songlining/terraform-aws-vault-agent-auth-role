output "vault_server_public_ip" {
  description = "Public IP address of the Vault server"
  value       = aws_instance.server_a.public_ip
}

output "vault_server_public_dns" {
  description = "Public DNS name of the Vault server"
  value       = aws_instance.server_a.public_dns
}

output "vault_server_private_ip" {
  description = "Private IP address of the Vault server"
  value       = aws_instance.server_a.private_ip
}

output "vault_agent_public_ip" {
  description = "Public IP address of the Vault agent"
  value       = aws_instance.server_b.public_ip
}

output "server_a_key_name" {
  description = "Name of the key pair for server-a"
  value       = module.server_a_key_pair.key_pair_name
}

output "server_b_key_name" {
  description = "Name of the key pair for server-b"
  value       = module.server_b_key_pair.key_pair_name
}

output "server_a_key_file" {
  description = "Path to the private key file for server-a"
  value       = local_file.server_a_private_key.filename
}

output "server_b_key_file" {
  description = "Path to the private key file for server-b"
  value       = local_file.server_b_private_key.filename
}