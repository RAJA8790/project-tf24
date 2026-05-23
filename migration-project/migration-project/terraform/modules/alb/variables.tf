# modules/alb/variables.tf

variable "project"           { type = string }
variable "environment"       { type = string }
variable "vpc_id"            { type = string }
variable "alb_sg_id"         { type = string }
variable "public_subnet_ids" { type = list(string) }

variable "app_port" {
  type    = number
  default = 3000
}

variable "health_check_path" {
  type    = string
  default = "/health"
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS. Leave empty for HTTP-only (dev)."
  type        = string
  default     = ""
}

variable "access_logs_bucket" {
  description = "S3 bucket for ALB access logs. Leave empty to disable."
  type        = string
  default     = ""
}

variable "common_tags" {
  type    = map(string)
  default = {}
}

# modules/alb/outputs.tf
