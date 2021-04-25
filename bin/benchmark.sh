#!/usr/bin/env bash
set -e

if [[ "$1" == "local-docker" ]]; then

    host_ip=`docker network inspect bridge -f '{{range.IPAM.Config}}{{.Gateway}}{{end}}'`

    echo "---------------------------------------------------------------------------------------"
    echo "Benchmarking Laravel demo app: $NAME (OPCACHE: $PHP_OPCACHE, PRELOADING: $PHP_PRELOADING, JIT: $PHP_JIT)"
    echo "---------------------------------------------------------------------------------------"
    docker run --rm jordi/ab -n 10 -c 10 http://$host_ip:8888/ > /dev/null
    docker run --rm jordi/ab -n $AB_REQUESTS -c $AB_CONCURRENCY -d http://$host_ip:8888/

    echo "---------------------------------------------------------------------------------------"
    echo "Benchmarking Symfony demo app: $NAME (OPCACHE: $PHP_OPCACHE, PRELOADING: $PHP_PRELOADING, JIT: $PHP_JIT)"
    echo "---------------------------------------------------------------------------------------"
    docker run --rm jordi/ab -n 10 -c 10 http://$host_ip:8889/ > /dev/null
    docker run --rm jordi/ab -n $AB_REQUESTS -c $AB_CONCURRENCY -d http://$host_ip:8889/

    echo "---------------------------------------------------------------------------------------"
    echo "Benchmarking Zend scripts   : $NAME (OPCACHE: $PHP_OPCACHE, PRELOADING: $PHP_PRELOADING, JIT: $PHP_JIT)"
    echo "---------------------------------------------------------------------------------------"
    docker run --rm curlimages/curl -s http://$host_ip:8890/bench.php
    docker run --rm curlimages/curl -s http://$host_ip:8890/micro_bench.php

elif [[ "$1" == "aws-docker" ]]; then

    echo "aws-docker"

elif [[ "$1" == "aws-host" ]]; then

    echo "aws-host"

else

    echo 'Available options: "local-docker", "aws-docker", "aws-host"!'
    exit 1

fi
