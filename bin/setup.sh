#!/usr/bin/env bash
set -e

if [[ "$1" == "local-docker" ]]; then

    mkdir -p "$PROJECT_ROOT/app/symfony"
    mkdir -p "$PROJECT_ROOT/app/laravel"
    mkdir -p "$PROJECT_ROOT/app/wordpress"
    mkdir -p "$PROJECT_ROOT/app/zend"

    # Install Laravel demo app
    if [ -z "$(ls -A $PROJECT_ROOT/app/laravel)" ]; then
        docker run --rm \
            --volume $PROJECT_ROOT:/code \
            --user $(id -u):$(id -g) \
            composer create-project laravel/laravel laravel 8.5.16 --no-interaction --working-dir=/code/app
    fi

    # Install Symfony demo app
    if [ -z "$(ls -A $PROJECT_ROOT/app/symfony)" ]; then
        docker run --rm \
            --volume $PROJECT_ROOT:/code \
            --user $(id -u):$(id -g) \
            composer create-project symfony/symfony-demo symfony dev-main --no-interaction --working-dir=/code/app
    fi

    # Download bench.php
    if [ ! -f "$PROJECT_ROOT/app/zend/bench.php" ]; then
        docker run --rm \
            --volume $PROJECT_ROOT:/code \
            --user $(id -u):$(id -g) \
            curlimages/curl https://raw.githubusercontent.com/php/php-src/master/Zend/bench.php --output /code/app/zend/bench.php
    fi

    # Download micro_bench.php
    if [ ! -f "$PROJECT_ROOT/app/zend/bench.php" ]; then
        docker run --rm \
            --volume $PROJECT_ROOT:/code \
            --user $(id -u):$(id -g) \
            curlimages/curl https://raw.githubusercontent.com/php/php-src/master/Zend/micro_bench.php --output /code/app/zend/micro_bench.php
    fi

elif [[ "$1" == "aws" ]]; then

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

    $PROJECT_ROOT/bin/benchmark "$BENCHMARK_URL"

    echo "TERRAFORM DESTROY"

    terraform destroy \
        -var "project_root=\"$PROJECT_ROOT\"" \
        -var-file="$PROJECT_ROOT/build/infrastructure/config/aws.tfvars"

    cd $PROJECT_ROOT

elif [[ "$1" == "aws-host" ]]; then

    echo "aws-host"

else

    echo 'Available options: "docker", "aws-docker", "aws-host"!'
    exit 1

fi
