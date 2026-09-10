variable "aws_region" {
  description = "AWS region for the Nexus infrastructure"
  type        = string
  default     = "eu-central-1"
}

variable "admin_ip" {
  description = "Public IP address of the administrator (CIDR format)"
  type        = string
  default     = "212.93.150.80/32"
}

variable "ssh_public_key_path" {
  description = "Path to the local SSH public key"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "ssh_private_key_path" {
  description = "Path to the local SSH private key (for inventory.ini)"
  type        = string
  default     = "~/.ssh/id_rsa"
}
