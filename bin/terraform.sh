#!/usr/bin/env bash
set -e

$PROJECT_ROOT/build/infrastructure/aws/generate_provisioners.sh

cd $PROJECT_ROOT/build/infrastructure/aws/

terraform init -backend=true -get=true

echo "TERRAFORM PLAN:"

terraform plan \
    -input=false \
    -out="$PROJECT_ROOT/build/infrastructure/aws/aws.tfplan" \
    -refresh=true \
    -var "project_root=$PROJECT_ROOT" \
    -var-file="$PROJECT_ROOT/build/infrastructure/config/aws.tfvars"

echo "TERRAFORM APPLY:"

terraform apply \
    -auto-approve \
    -input=false \
    "$PROJECT_ROOT/build/infrastructure/aws/aws.tfplan"

BENCHMARK_URL=`terraform output dns`

echo "RUNNING BENCHMARK: $BENCHMARK_URL"

terraform destroy \
    -var "project_root=\"$PROJECT_ROOT\"" \
    -var-file="$PROJECT_ROOT/build/infrastructure/config/aws.tfvars"

cd $PROJECT_ROOT
