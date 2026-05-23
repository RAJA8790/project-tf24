# On-Prem to AWS Migration Project
## 3-Tier Web App Migration using Terraform Reusable Modules + Harness Pipelines

---

## Scenario

**Company**: RetailCo (fictional)
**Current State**: 3-tier web application running on on-prem VMware VMs
- Web Tier: 2x Nginx servers (8 vCPU, 16GB RAM)
- App Tier: 4x Node.js App servers (16 vCPU, 32GB RAM)
- DB Tier: 1x PostgreSQL primary + 1x replica (32 vCPU, 128GB RAM)

**Target State**: AWS (ap-south-1 — Mumbai)
- Web Tier → ALB + EC2 Auto Scaling Group
- App Tier → EC2 Auto Scaling Group (private subnet)
- DB Tier → Amazon RDS PostgreSQL (Multi-AZ)

---

## Project Structure

```
migration-project/
├── terraform/
│   ├── modules/               # Reusable Terraform modules
│   │   ├── vpc/               # VPC, subnets, IGW, NAT
│   │   ├── security-groups/   # SGs for each tier
│   │   ├── ec2/               # EC2 + Launch Template + ASG
│   │   ├── alb/               # Application Load Balancer
│   │   └── rds/               # RDS PostgreSQL Multi-AZ
│   └── environments/
│       ├── dev/               # Dev environment (small)
│       ├── staging/           # Staging environment (medium)
│       └── prod/              # Production environment (full)
├── harness/
│   ├── pipelines/             # Harness pipeline YAML files
│   ├── templates/             # Reusable pipeline templates
│   └── connectors/            # Connector configs
├── scripts/
│   └── bootstrap.sh           # Initial setup script
└── docs/
    └── architecture.md        # Architecture decisions
```

---

## Step-by-Step Implementation Guide

### Phase 1 — Prerequisites
1. AWS account with IAM role for Terraform
2. Harness account (free tier or SaaS)
3. S3 bucket for Terraform state
4. DynamoDB table for state locking
5. GitHub repo for the code

### Phase 2 — Terraform Modules
1. Write and test each module individually
2. Test in dev environment first
3. Promote to staging → prod

### Phase 3 — Harness Setup
1. Create GitHub connector
2. Create AWS connector
3. Create pipeline using YAML
4. Set up approvals for prod deployments

### Phase 4 — Migration Execution
1. Run Plan stage (review changes)
2. Apply to dev → validate
3. Apply to staging → validate
4. Request approval → Apply to prod
5. Cutover DNS / decommission on-prem
