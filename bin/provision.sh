#!/usr/bin/env bash
set -e

if [[ "$1" == "local-docker" ]]; then

    $PROJECT_ROOT/build/script/php_source.sh

    cp "$PROJECT_ROOT/Dockerfile" "$GIT_PATH/Dockerfile"
    cp "$PROJECT_ROOT/.dockerignore" "$GIT_PATH/.dockerignore"
    docker build -t "$BENCHMARK_FPM_ADDR-$NAME:latest" "$GIT_PATH"

    docker network create php-benchmark || true

    docker stop $BENCHMARK_NGINX_ADDR $BENCHMARK_FPM_ADDR || true
    docker rm $BENCHMARK_NGINX_ADDR $BENCHMARK_FPM_ADDR || true

    docker run --rm --detach --network=php-benchmark --log-driver=local --env-file $PROJECT_ROOT/.env --env-file $CONFIG_FILE \
            --volume $PROJECT_ROOT/build:/code/build:delegated --volume $PROJECT_ROOT/app:/code/app \
            --name=$BENCHMARK_FPM_ADDR $BENCHMARK_FPM_ADDR-$NAME /code/build/container/fpm/run.sh

    sleep 2

    docker run --rm --detach --network=php-benchmark --log-driver=none --env-file $PROJECT_ROOT/.env \
            --volume $PROJECT_ROOT/build:/code/build:delegated --volume $PROJECT_ROOT/app:/code/app \
            --name=$BENCHMARK_NGINX_ADDR -p 8888:80 -p 8889:81 -p 8890:82 nginx:1.20 /code/build/container/nginx/run.sh

elif [[ "$1" == "aws-docker" ]]; then

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

    echo 'Available options: "local-docker", "aws-docker", "aws-host"!'
    exit 1

fi
