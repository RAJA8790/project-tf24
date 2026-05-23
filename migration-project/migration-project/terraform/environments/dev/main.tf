# environments/dev/main.tf
# Dev environment — same modules, smaller sizes, no Multi-AZ

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = { source = "hashicorp/aws"; version = "~> 5.0" }
  }

  backend "s3" {
    bucket         = "retailco-terraform-state"
    key            = "dev/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "retailco-terraform-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = "ap-south-1"
  default_tags {
    tags = {
      Project     = "retailco"
      Environment = "dev"
      ManagedBy   = "Terraform"
    }
  }
}

locals {
  project     = "retailco"
  environment = "dev"
  common_tags = { Project = "retailco", Environment = "dev", ManagedBy = "Terraform" }
}

module "vpc" {
  source = "../../modules/vpc"

  project     = local.project
  environment = local.environment

  vpc_cidr                 = "10.1.0.0/16"
  availability_zones       = ["ap-south-1a", "ap-south-1b"]
  public_subnet_cidrs      = ["10.1.1.0/24", "10.1.2.0/24"]
  private_app_subnet_cidrs = ["10.1.11.0/24", "10.1.12.0/24"]
  private_db_subnet_cidrs  = ["10.1.21.0/24", "10.1.22.0/24"]
  common_tags              = local.common_tags
}

module "security_groups" {
  source      = "../../modules/security-groups"
  project     = local.project
  environment = local.environment
  vpc_id      = module.vpc.vpc_id
  app_port    = 3000
  common_tags = local.common_tags
}

module "alb" {
  source            = "../../modules/alb"
  project           = local.project
  environment       = local.environment
  vpc_id            = module.vpc.vpc_id
  alb_sg_id         = module.security_groups.alb_sg_id
  public_subnet_ids = module.vpc.public_subnet_ids
  app_port          = 3000
  certificate_arn   = ""  # HTTP only in dev
  common_tags       = local.common_tags
}

module "app_asg" {
  source             = "../../modules/ec2"
  project            = local.project
  environment        = local.environment
  tier               = "app"
  instance_type      = "t3.medium"   # Smaller for dev
  subnet_ids         = module.vpc.private_app_subnet_ids
  security_group_ids = [module.security_groups.app_sg_id]
  target_group_arns  = [module.alb.target_group_arn]
  min_size           = 1
  max_size           = 2
  desired_capacity   = 1
  common_tags        = local.common_tags
}

module "rds" {
  source        = "../../modules/rds"
  project       = local.project
  environment   = local.environment
  db_subnet_ids = module.vpc.private_db_subnet_ids
  rds_sg_id     = module.security_groups.rds_sg_id
  instance_class = "db.t3.medium"  # Smaller for dev
  allocated_storage     = 20
  max_allocated_storage = 100
  db_name     = "retailco_dev"
  db_username = "retailco_admin"
  db_password = var.db_password
  backup_retention_days = 3
  common_tags  = local.common_tags
}

variable "db_password" { type = string; sensitive = true }

output "alb_dns" { value = module.alb.alb_dns_name }
output "db_endpoint" { value = module.rds.db_endpoint }
