# Architecture & Step-by-Step Implementation Guide

## Architecture Overview

```
INTERNET
    │
    ▼
┌─────────────────────────────────────────────┐
│           PUBLIC SUBNETS                    │
│  ┌──────────────────────────────────────┐   │
│  │   Application Load Balancer (ALB)   │   │
│  │   SG: 80/443 open from 0.0.0.0/0   │   │
│  └──────────────┬───────────────────────┘   │
└─────────────────│───────────────────────────┘
                  │ (port 3000)
┌─────────────────│───────────────────────────┐
│           PRIVATE APP SUBNETS               │
│  ┌───────────────────────────────────────┐  │
│  │  Auto Scaling Group — App Servers     │  │
│  │  EC2 m5.xlarge (AZ-a, AZ-b, AZ-c)   │  │
│  │  SG: 3000 from ALB SG only           │  │
│  └──────────────┬────────────────────────┘  │
└─────────────────│───────────────────────────┘
                  │ (port 5432)
┌─────────────────│───────────────────────────┐
│           PRIVATE DB SUBNETS                │
│  ┌────────────────────────────────────────┐ │
│  │  RDS PostgreSQL 15  (Multi-AZ)         │ │
│  │  db.r6g.2xlarge  |  500GB gp3          │ │
│  │  SG: 5432 from App SG only             │ │
│  └────────────────────────────────────────┘ │
└─────────────────────────────────────────────┘
```

---

## Phase-by-Phase Steps

### 🔧 Phase 0 — Setup (One-time)

**Step 1: Install tools locally**
```bash
# Terraform
brew install terraform       # macOS
# or
curl -O https://releases.hashicorp.com/terraform/1.6.6/terraform_1.6.6_linux_amd64.zip

# AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip
unzip awscliv2.zip && sudo ./aws/install

# Configure AWS credentials
aws configure
```

**Step 2: Run bootstrap script**
```bash
chmod +x scripts/bootstrap.sh
./scripts/bootstrap.sh
# Creates: S3 state bucket, DynamoDB lock table, IAM role
```

**Step 3: Push code to GitHub**
```bash
git init
git remote add origin https://github.com/your-org/migration-project
git add .
git commit -m "Initial migration infrastructure code"
git push -u origin main
```

---

### 🏗️ Phase 1 — Test Terraform Modules Locally

**Step 4: Validate each module**
```bash
# Test VPC module
cd terraform/modules/vpc
terraform init
terraform validate
terraform fmt -check

# Test the full dev environment
cd terraform/environments/dev
terraform init
terraform validate
terraform plan -var="db_password=testpassword123"
```

**Step 5: Apply to dev manually first (before Harness)**
```bash
cd terraform/environments/dev
terraform apply -var="db_password=testpassword123"

# Get outputs
terraform output alb_dns
terraform output db_endpoint
```

**Step 6: Verify dev deployment**
```bash
# Test the health endpoint
ALB_DNS=$(terraform output -raw alb_dns)
curl http://$ALB_DNS/health

# Check RDS connectivity from an EC2 instance (via SSM)
aws ssm start-session --target <instance-id>
psql -h <db-endpoint> -U retailco_admin -d retailco_dev
```

---

### ⚙️ Phase 2 — Harness Setup

**Step 7: Create a Harness account**
- Go to https://app.harness.io/auth/#/signup
- Create a new project: `platform_engineering`

**Step 8: Install Harness Delegate**
```bash
# Download delegate YAML from Harness UI
# Harness → Project Settings → Delegates → New Delegate → Kubernetes

kubectl apply -f harness-delegate.yml

# Verify delegate is connected
kubectl get pods -n harness-delegate
```

**Step 9: Create Secrets in Harness**
```
Harness UI → Project Settings → Secrets → New Secret (Text)

Create these secrets:
  - aws_access_key_dev      → IAM key for dev account
  - aws_secret_key_dev      → IAM secret for dev account
  - aws_access_key_staging  → IAM key for staging account
  - aws_secret_key_staging  → IAM secret for staging account
  - aws_access_key_prod     → IAM key for prod account
  - aws_secret_key_prod     → IAM secret for prod account
  - dev_db_password         → Database password for dev
  - staging_db_password     → Database password for staging
  - prod_db_password        → Database password for prod
  - github_pat_token        → GitHub Personal Access Token
```

**Step 10: Create GitHub Connector**
```
Harness UI → Project Settings → Connectors → New Connector → GitHub
  - URL: https://github.com/your-org/migration-project
  - Auth: Username + Token (use github_pat_token secret)
  - Test the connection
```

**Step 11: Import Pipeline**
```
Harness UI → Pipelines → Import from Git
  - Select your GitHub connector
  - Branch: main
  - File: harness/pipelines/terraform-migration-pipeline.yaml
```

---

### 🚀 Phase 3 — Run the Pipeline

**Step 12: Run Dev stage**
```
Harness UI → Pipelines → retailco_migration_pipeline → Run
  - Watch logs for each step
  - Verify plan output before apply
  - Check smoke test passes
```

**Step 13: Promote to Staging**
```
  - Staging stage runs automatically after dev passes
  - Review plan output in logs
  - Verify staging smoke test
```

**Step 14: Prod approval + deploy**
```
  - Platform leads will receive Harness approval notification
  - 2 approvers must approve with a change ticket number
  - After approval, prod deploy runs automatically
```

---

### ✂️ Phase 4 — DNS Cutover (Final Step)

**Step 15: Cutover DNS**
```bash
# Get the ALB DNS from Terraform outputs
cd terraform/environments/prod
terraform output alb_dns_name

# Update your DNS (Route53 example):
aws route53 change-resource-record-sets \
  --hosted-zone-id Z1234567890 \
  --change-batch '{
    "Changes": [{
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "app.retailco.com",
        "Type": "CNAME",
        "TTL": 60,
        "ResourceRecords": [{"Value": "<alb-dns-name>"}]
      }
    }]
  }'
```

**Step 16: Decommission on-prem servers**
```
1. Monitor for 1-2 weeks after cutover
2. Confirm no traffic on on-prem servers
3. Take final DB backup from on-prem
4. Power off / decommission VMs
```

---

## Key Things to Practice

| Topic | What to do |
|-------|-----------|
| Module reuse | Add a staging env using same modules with different sizes |
| State management | Simulate a `terraform state mv` between environments |
| Secrets | Replace hardcoded values with Harness secrets |
| Approvals | Add a Jira ticket validator to the approval gate |
| Rollback | Manually trigger the rollback step and observe behavior |
| Drift detection | Run `terraform plan` on an unchanged env and see "No changes" |
| Scaling | Update `desired_capacity` and watch instance refresh |
