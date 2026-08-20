#!/usr/bin/env bash

create_infra () {
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
}

destroy_infra () {
    set -e

    terraform destroy \
        -auto-approve \
        -input=false \
        -var-file="$PROJECT_ROOT/build/infrastructure/config/aws.tfvars" \
        -var-file="$PROJECT_ROOT/build/infrastructure/config/custom.tfvars"

    set +e
}

$PROJECT_ROOT/build/infrastructure/aws/generate_aws_config.sh

cd "$PROJECT_ROOT/build/infrastructure/aws/"

subcommand="$1"
status_code="0"

case "$subcommand" in
    "create")
        create_infra
        status_code="$?"
        ;;

    "create_destroy")
        create_infra
        status_code="$?"
        destroy_infra
        ;;

    "destroy")
        destroy_infra
        ;;

    *)
        echo "Invalid subcommand $subcommand" >&2
        exit 1
esac

cd "$PROJECT_ROOT"

exit "$status_code"
