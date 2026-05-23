# modules/ec2/variables.tf

variable "project"     { type = string }
variable "environment" { type = string }

variable "tier" {
  description = "Application tier label (web / app)"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "ami_id" {
  description = "Custom AMI ID. Leave empty to use latest Amazon Linux 2."
  type        = string
  default     = ""
}

variable "key_name" {
  description = "EC2 key pair name for SSH access"
  type        = string
  default     = ""
}

variable "subnet_ids" {
  description = "Subnet IDs for the ASG"
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security group IDs to attach to instances"
  type        = list(string)
}

variable "target_group_arns" {
  description = "ALB target group ARNs to register instances with"
  type        = list(string)
  default     = []
}

variable "associate_public_ip" {
  description = "Whether to assign public IP to instances"
  type        = bool
  default     = false
}

variable "min_size"         { type = number; default = 1 }
variable "max_size"         { type = number; default = 4 }
variable "desired_capacity" { type = number; default = 2 }

variable "root_volume_size" {
  description = "Root EBS volume size in GB"
  type        = number
  default     = 30
}

variable "user_data" {
  description = "User data script for EC2 instances"
  type        = string
  default     = ""
}

variable "common_tags" {
  type    = map(string)
  default = {}
}
