#!/usr/bin/env bash

$PROJECT_ROOT/build/infrastructure/aws/generate_aws_config.sh

cd $PROJECT_ROOT/build/infrastructure/aws/

terraform init -backend=true -get=true -upgrade
if [ $? -ne 0 ]; then
  exit 1
fi

terraform plan \
    -input=false \
    -out="$PROJECT_ROOT/build/infrastructure/aws/aws.tfplan" \
    -refresh=true \
    -var-file="$PROJECT_ROOT/build/infrastructure/config/aws.tfvars" \
    -var-file="$PROJECT_ROOT/build/infrastructure/config/custom.tfvars"
if [ $? -ne 0 ]; then
  exit 1
fi

terraform apply \
    -auto-approve \
    -input=false \
    "$PROJECT_ROOT/build/infrastructure/aws/aws.tfplan"

status_code="$?"

terraform destroy \
    -auto-approve \
    -var-file="$PROJECT_ROOT/build/infrastructure/config/aws.tfvars" \
    -var-file="$PROJECT_ROOT/build/infrastructure/config/custom.tfvars"

cd $PROJECT_ROOT

exit $status_code
