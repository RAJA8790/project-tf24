# environments/prod/main.tf
# Production environment — composes all reusable modules

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote state in S3 (create bucket before running)
  backend "s3" {
    bucket         = "retailco-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "retailco-terraform-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

locals {
  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "Terraform"
    Team        = "Platform"
    CostCenter  = "Engineering"
  }
}

# ─── 1. VPC ───────────────────────────────────────────────────────────────────
module "vpc" {
  source = "../../modules/vpc"

  project     = var.project
  environment = var.environment

  vpc_cidr                 = "10.0.0.0/16"
  availability_zones       = ["ap-south-1a", "ap-south-1b", "ap-south-1c"]
  public_subnet_cidrs      = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_app_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
  private_db_subnet_cidrs  = ["10.0.21.0/24", "10.0.22.0/24", "10.0.23.0/24"]

  common_tags = local.common_tags
}

# ─── 2. Security Groups ───────────────────────────────────────────────────────
module "security_groups" {
  source = "../../modules/security-groups"

  project     = var.project
  environment = var.environment
  vpc_id      = module.vpc.vpc_id
  app_port    = 3000

  common_tags = local.common_tags
}

# ─── 3. Application Load Balancer ────────────────────────────────────────────
module "alb" {
  source = "../../modules/alb"

  project           = var.project
  environment       = var.environment
  vpc_id            = module.vpc.vpc_id
  alb_sg_id         = module.security_groups.alb_sg_id
  public_subnet_ids = module.vpc.public_subnet_ids
  app_port          = 3000
  health_check_path = "/health"
  certificate_arn   = var.certificate_arn   # ACM cert ARN for prod

  access_logs_bucket = "retailco-alb-logs-prod"
  common_tags        = local.common_tags
}

# ─── 4. App EC2 Auto Scaling Group ───────────────────────────────────────────
module "app_asg" {
  source = "../../modules/ec2"

  project     = var.project
  environment = var.environment
  tier        = "app"

  instance_type      = "m5.xlarge"   # 4 vCPU / 16GB — scaled down from 16 vCPU on-prem
  subnet_ids         = module.vpc.private_app_subnet_ids
  security_group_ids = [module.security_groups.app_sg_id]
  target_group_arns  = [module.alb.target_group_arn]

  min_size         = 2
  max_size         = 10
  desired_capacity = 4

  root_volume_size = 50

  user_data = templatefile("${path.module}/user_data/app.sh.tpl", {
    db_host    = module.rds.db_endpoint
    db_name    = var.db_name
    db_user    = var.db_username
    db_pass    = var.db_password
    app_env    = var.environment
  })

  common_tags = local.common_tags
}

# ─── 5. RDS PostgreSQL ────────────────────────────────────────────────────────
module "rds" {
  source = "../../modules/rds"

  project       = var.project
  environment   = var.environment
  db_subnet_ids = module.vpc.private_db_subnet_ids
  rds_sg_id     = module.security_groups.rds_sg_id

  instance_class        = "db.r6g.2xlarge"  # 8 vCPU / 64GB
  allocated_storage     = 500
  max_allocated_storage = 2000

  db_name     = var.db_name
  db_username = var.db_username
  db_password = var.db_password

  backup_retention_days = 30

  common_tags = local.common_tags
}
