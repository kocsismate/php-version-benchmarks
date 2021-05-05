#!/usr/bin/env bash
set -e

if [[ "$INFRA_ENVIRONMENT" == "local" ]]; then
    $PROJECT_ROOT/bin/benchmark.sh
elif [[ "$INFRA_ENVIRONMENT" == "aws" ]]; then
    $PROJECT_ROOT/build/infrastructure/aws/generate_aws_config.sh

    cd $PROJECT_ROOT/build/infrastructure/aws/

    terraform init -backend=true -get=true

    terraform plan \
        -input=false \
        -out="$PROJECT_ROOT/build/infrastructure/aws/aws.tfplan" \
        -refresh=true \
        -var-file="$PROJECT_ROOT/build/infrastructure/config/aws.tfvars" \
        -var-file="$PROJECT_ROOT/build/infrastructure/config/custom.tfvars"

    terraform apply \
        -auto-approve \
        -input=false \
        "$PROJECT_ROOT/build/infrastructure/aws/aws.tfplan" || true

    if [[ "$N" == "1" ]]; then
        arg="-auto-approve"
    else
        arg="-auto-approve"
    fi

    terraform destroy \
        $arg \
        -var-file="$PROJECT_ROOT/build/infrastructure/config/aws.tfvars" \
        -var-file="$PROJECT_ROOT/build/infrastructure/config/custom.tfvars"

    cd $PROJECT_ROOT

fi
