# environments/prod/terraform.tfvars
# NEVER commit sensitive values — use Harness secrets or AWS Secrets Manager

project         = "retailco"
environment     = "prod"
aws_region      = "ap-south-1"
certificate_arn = "arn:aws:acm:ap-south-1:123456789012:certificate/xxxx-xxxx"
db_name         = "retailco_prod"
db_username     = "retailco_admin"
# db_password   → injected at runtime via Harness secret: <+secrets.getValue("prod_db_password")>
