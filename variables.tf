variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  # default     = "ap-southeast-2"
}

variable "arm_ami_id" {
  description = "AMI ID for Amazon Linux 2"
  type        = string
  default     = "ami-0bc8d8ff75a022b42"  # Amazon Linux 2 ARM64 in ap-southeast-2, update as needed
}

variable "key_name" {
  description = "Name of the SSH key pair to use for the instances"
  type        = string
  default = "vault"
}

variable "vault_version" {
  description = "Version of Hashicorp Vault to install"
  type        = string
  default     = "1.19.3"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  # default     = "t4g.small"   # ARM-based instance by default
}