# environments/prod/variables.tf

variable "project"     { type = string; default = "retailco" }
variable "environment" { type = string; default = "prod" }
variable "aws_region"  { type = string; default = "ap-south-1" }

variable "certificate_arn" {
  description = "ACM TLS certificate ARN"
  type        = string
}

variable "db_name"     { type = string }
variable "db_username" { type = string }
variable "db_password" {
  type      = string
  sensitive = true
}
