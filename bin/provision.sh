#!/usr/bin/env bash

$PROJECT_ROOT/build/infrastructure/aws/generate_aws_config.sh

cd $PROJECT_ROOT/build/infrastructure/aws/

terraform init \
    -backend=true \
    -get=true \
    -upgrade \
    -input=false \
    -backend-config="$PROJECT_ROOT/build/infrastructure/config/state.config"
if [ $? -ne 0 ]; then
  exit 1
fi

terraform destroy \
    -auto-approve \
    -input=false \
    -var-file="$PROJECT_ROOT/build/infrastructure/config/aws.tfvars" \
    -var-file="$PROJECT_ROOT/build/infrastructure/config/custom.tfvars"
if [ $? -ne 0 ]; then
  exit 1
fi

terraform apply \
    -auto-approve \
    -input=false \
    -var-file="$PROJECT_ROOT/build/infrastructure/config/aws.tfvars" \
    -var-file="$PROJECT_ROOT/build/infrastructure/config/custom.tfvars"

status_code="$?"

terraform destroy \
    -auto-approve \
    -input=false \
    -var-file="$PROJECT_ROOT/build/infrastructure/config/aws.tfvars" \
    -var-file="$PROJECT_ROOT/build/infrastructure/config/custom.tfvars"

cd $PROJECT_ROOT

exit $status_code
