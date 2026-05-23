#!/bin/bash
# scripts/bootstrap.sh
# Run ONCE before the first pipeline execution.
# Creates the S3 state bucket, DynamoDB lock table, and IAM roles.

set -euo pipefail

AWS_REGION="ap-south-1"
STATE_BUCKET="retailco-terraform-state"
LOCK_TABLE="retailco-terraform-locks"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "═══════════════════════════════════════════════════════"
echo " RetailCo Migration — Bootstrap Setup"
echo " Account: $AWS_ACCOUNT_ID | Region: $AWS_REGION"
echo "═══════════════════════════════════════════════════════"

# ─── 1. S3 State Bucket ───────────────────────────────────────────────────────
echo ""
echo "▶ Creating S3 state bucket: $STATE_BUCKET"
aws s3api create-bucket \
  --bucket "$STATE_BUCKET" \
  --region "$AWS_REGION" \
  --create-bucket-configuration LocationConstraint="$AWS_REGION"

aws s3api put-bucket-versioning \
  --bucket "$STATE_BUCKET" \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
  --bucket "$STATE_BUCKET" \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}
    }]
  }'

aws s3api put-public-access-block \
  --bucket "$STATE_BUCKET" \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

echo "✅ S3 bucket ready: $STATE_BUCKET"

# ─── 2. DynamoDB Lock Table ───────────────────────────────────────────────────
echo ""
echo "▶ Creating DynamoDB lock table: $LOCK_TABLE"
aws dynamodb create-table \
  --table-name "$LOCK_TABLE" \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region "$AWS_REGION"

echo "✅ DynamoDB table ready: $LOCK_TABLE"

# ─── 3. Terraform IAM Role (used by Harness connector) ───────────────────────
echo ""
echo "▶ Creating Terraform deployer IAM role"

TRUST_POLICY=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "AWS": "arn:aws:iam::$AWS_ACCOUNT_ID:root"
    },
    "Action": "sts:AssumeRole",
    "Condition": {
      "StringEquals": {
        "sts:ExternalId": "harness-retailco-migration"
      }
    }
  }]
}
EOF
)

aws iam create-role \
  --role-name retailco-terraform-deployer \
  --assume-role-policy-document "$TRUST_POLICY" \
  --description "Role assumed by Harness for Terraform deployments"

# Attach managed policies (customize for least-privilege in production)
aws iam attach-role-policy \
  --role-name retailco-terraform-deployer \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess

aws iam attach-role-policy \
  --role-name retailco-terraform-deployer \
  --policy-arn arn:aws:iam::aws:policy/AmazonRDSFullAccess

aws iam attach-role-policy \
  --role-name retailco-terraform-deployer \
  --policy-arn arn:aws:iam::aws:policy/AmazonVPCFullAccess

aws iam attach-role-policy \
  --role-name retailco-terraform-deployer \
  --policy-arn arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess

echo "✅ IAM role created: retailco-terraform-deployer"

# ─── Done ─────────────────────────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════════"
echo " ✅ Bootstrap complete!"
echo ""
echo " Next steps:"
echo "  1. Store AWS credentials in Harness Secrets Manager"
echo "  2. Create GitHub connector in Harness"
echo "  3. Deploy Harness Delegate in each AWS account"
echo "  4. Import pipeline YAML from harness/pipelines/"
echo "═══════════════════════════════════════════════════════"
