# modules/security-groups/variables.tf

variable "project"     { type = string }
variable "environment" { type = string }
variable "vpc_id"      { type = string }

variable "app_port" {
  description = "Port the application listens on"
  type        = number
  default     = 3000
}

variable "bastion_cidr_blocks" {
  description = "CIDR blocks allowed SSH access (e.g. bastion host IP)"
  type        = list(string)
  default     = []
}

variable "common_tags" {
  type    = map(string)
  default = {}
}
