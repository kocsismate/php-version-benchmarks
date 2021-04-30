#!/usr/bin/env bash
set -e

start_docker () {
    echo ""
    $run_as docker network create php-benchmark || true
    $run_as docker volume create php-benchmark-socket || true

    $run_as docker stop $BENCHMARK_NGINX_ADDR $BENCHMARK_FPM_ADDR || true
    $run_as docker rm $BENCHMARK_NGINX_ADDR $BENCHMARK_FPM_ADDR || true

    $run_as docker run --detach --network=php-benchmark --log-driver=local --env-file $PROJECT_ROOT/.env --env-file $CONFIG_FILE \
            --volume "php-benchmark-socket:/var/run/php" --volume "$PROJECT_ROOT/build:/code/build:delegated" --volume "$PROJECT_ROOT/app:/code/app:delegated" \
            --name="$BENCHMARK_FPM_ADDR" "$repository:$NAME-latest" /code/build/container/fpm/run.sh

    $run_as docker run --detach --network=php-benchmark --log-driver=local --env-file $PROJECT_ROOT/.env \
            --volume "php-benchmark-socket:/var/run/php" --volume "$PROJECT_ROOT/build:/code/build:delegated" --volume "$PROJECT_ROOT/app:/code/app:delegated" \
            --name="$BENCHMARK_NGINX_ADDR" -p 8888:80 -p 8889:81 -p 8890:82 nginx:1.20 /code/build/container/nginx/run.sh
}

if [[ "$1" == "local-docker" ]]; then

    run_as=""
    repository="php-benchmark-fpm"

    build_docker
    start_docker

elif [[ "$1" == "aws-docker" ]]; then

    run_as="sudo"
    repository="$ECR_REGISTRY_ID/$ECR_REPOSITORY_NAME"

    start_docker

fi
