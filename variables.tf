# variables.tf


variable "ssh_public_key" {
  description = "SSH public key for EC2 instances"
  type        = string
}