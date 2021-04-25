#!/usr/bin/env bash
set -e

if [[ "$1" == "local-docker" ]]; then

    docker stop $BENCHMARK_NGINX_ADDR $BENCHMARK_FPM_ADDR || true

    docker network rm php-benchmark || true

elif [[ "$1" == "aws-docker" ]]; then

    echo "aws-docker"

elif [[ "$1" == "aws-host" ]]; then

    echo "aws-host"

else

    echo 'Available options: "local-docker", "aws-docker", "aws-host"!'
    exit 1

fi
