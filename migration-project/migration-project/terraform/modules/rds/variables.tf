# modules/rds/variables.tf

variable "project"       { type = string }
variable "environment"   { type = string }
variable "db_subnet_ids" { type = list(string) }
variable "rds_sg_id"     { type = string }

variable "engine_version" {
  type    = string
  default = "15.4"
}

variable "instance_class" {
  type    = string
  default = "db.t3.medium"
}

variable "allocated_storage" {
  type    = number
  default = 100
}

variable "max_allocated_storage" {
  description = "Enables storage autoscaling up to this value"
  type        = number
  default     = 500
}

variable "db_name"     { type = string }
variable "db_username" { type = string }
variable "db_password" {
  type      = string
  sensitive = true
}

variable "backup_retention_days" {
  type    = number
  default = 7
}

variable "kms_key_arn" {
  description = "KMS key ARN for storage encryption. Leave empty for AWS-managed key."
  type        = string
  default     = ""
}

variable "common_tags" {
  type    = map(string)
  default = {}
}

# ─────────────────────────────────────────────────────────────────────────────
# modules/rds/outputs.tf

output "db_endpoint" {
  description = "RDS connection endpoint"
  value       = aws_db_instance.main.endpoint
}

output "db_name" {
  value = aws_db_instance.main.db_name
}

output "db_port" {
  value = aws_db_instance.main.port
}

output "db_instance_id" {
  value = aws_db_instance.main.id
}
