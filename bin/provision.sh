#!/usr/bin/env bash
set -e

if [[ "$1" == "local-docker" ]]; then

    $PROJECT_ROOT/build/script/php_source.sh "$1"

    cp "$PROJECT_ROOT/.dockerignore" "$GIT_PATH/.dockerignore"
    docker build -f "$PROJECT_ROOT/Dockerfile" -t "php-benchmark-fpm:$NAME-latest" "$GIT_PATH"

    docker network create php-benchmark || true

    docker stop $BENCHMARK_NGINX_ADDR $BENCHMARK_FPM_ADDR || true
    docker rm $BENCHMARK_NGINX_ADDR $BENCHMARK_FPM_ADDR || true

    docker run --rm --detach --network=php-benchmark --log-driver=none --env-file $PROJECT_ROOT/.env --env-file $CONFIG_FILE \
            --volume "$PROJECT_ROOT/build:/code/build:delegated" --volume "$PROJECT_ROOT/app:/code/app:delegated" \
            --name="$BENCHMARK_FPM_ADDR" "php-benchmark-fpm:$NAME-latest" /code/build/container/fpm/run.sh

    sleep 3

    docker run --rm --detach --network=php-benchmark --log-driver=none --env-file $PROJECT_ROOT/.env \
            --volume "$PROJECT_ROOT/build:/code/build:delegated" --volume "$PROJECT_ROOT/app:/code/app:delegated" \
            --name="$BENCHMARK_NGINX_ADDR" -p 8888:80 -p 8889:81 -p 8890:82 nginx:1.20 /code/build/container/nginx/run.sh

elif [[ "$1" == "aws-docker" ]]; then

    $PROJECT_ROOT/build/script/php_source.sh "$1"

    sudo docker stop $BENCHMARK_NGINX_ADDR $BENCHMARK_FPM_ADDR || true
    sudo docker rm $BENCHMARK_NGINX_ADDR $BENCHMARK_FPM_ADDR || true

    sudo docker network create php-benchmark || true

    sudo docker run --rm --detach --network=php-benchmark --log-driver=none --env-file "$PROJECT_ROOT/.env" --env-file "$CONFIG_FILE" \
            --volume "$PROJECT_ROOT/build:/code/build:delegated" --volume "$PROJECT_ROOT/app:/code/app:delegated" \
            --name="$BENCHMARK_FPM_ADDR" "$ECR_REGISTRY_ID/$ECR_REPOSITORY_NAME:$NAME-latest" /code/build/container/fpm/run.sh

    sudo docker run --rm --detach --network=php-benchmark --log-driver=none --env-file "$PROJECT_ROOT/.env" \
            --volume "$PROJECT_ROOT/build:/code/build:delegated" --volume "$PROJECT_ROOT/app:/code/app:delegated" \
            --name="$BENCHMARK_NGINX_ADDR" -p 80:80 -p 8888:80 -p 8889:81 -p 8890:82 nginx:1.20 /code/build/container/nginx/run.sh

else

    echo 'Available options: "local-docker", "aws-docker"!'
    exit 1

fi
