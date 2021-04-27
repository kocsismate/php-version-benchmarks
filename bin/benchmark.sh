#!/usr/bin/env bash
set -e

run_ab () {
    docker run --rm jordi/ab -n "$1" -c "$2" -S -d -q "$3"
}

run_curl () {
    docker run --rm curlimages/curl -s "$1"
}

run_benchmark () {
    echo "---------------------------------------------------------------------------------------"
    echo "Benchmarking Laravel demo app: $NAME (opcache: $PHP_OPCACHE, preloading: $PHP_PRELOADING, JIT: $PHP_JIT)"
    echo "---------------------------------------------------------------------------------------"
    # Warmup
    run_ab 5 1 http://$host_ip:8888/ > /dev/null
    # Benchmark
    run_ab "$AB_REQUESTS" "$AB_CONCURRENCY" http://$host_ip:8888/

    echo "---------------------------------------------------------------------------------------"
    echo "Benchmarking Symfony demo app: $NAME (opcache: $PHP_OPCACHE, preloading: $PHP_PRELOADING, JIT: $PHP_JIT)"
    echo "---------------------------------------------------------------------------------------"
    # Warmup
    run_ab 5 1 http://$host_ip:8889/ > /dev/null
    # Benchmark
    run_ab "$AB_REQUESTS" "$AB_CONCURRENCY" http://$host_ip:8889/

    echo "---------------------------------------------------------------------------------------"
    echo "Benchmarking Zend bench      : $NAME (opcache: $PHP_OPCACHE, preloading: $PHP_PRELOADING, JIT: $PHP_JIT)"
    echo "---------------------------------------------------------------------------------------"
    # Warmup
    run_ab 5 1 http://$host_ip:8889/bench.php > /dev/null
    # Benchmark
    run_curl http://$host_ip:8890/bench.php

    echo "---------------------------------------------------------------------------------------"
    echo "Benchmarking Zend micro bench: $NAME (opcache: $PHP_OPCACHE, preloading: $PHP_PRELOADING, JIT: $PHP_JIT)"
    echo "---------------------------------------------------------------------------------------"
    # Warmup
    run_ab 5 1 http://$host_ip:8889/micro_bench.php > /dev/null
    # Benchmark
    run_curl http://$host_ip:8890/micro_bench.php
}

mkdir -p "$PROJECT_ROOT/tmp/result"
rm -f "$PROJECT_ROOT/tmp/result/*"

result_file="$PROJECT_ROOT/tmp/result/$NAME.txt"
touch "$result_file"

if [[ "$1" == "local-docker" ]]; then

    host_ip=`docker network inspect bridge -f '{{range.IPAM.Config}}{{.Gateway}}{{end}}'`

    run_benchmark | tee -a $result_file

elif [[ "$1" == "aws-docker" ]]; then

    run_benchmark | tee -a $result_file

else

    echo 'Available options: "local-docker", "aws-docker"!'
    exit 1

fi
