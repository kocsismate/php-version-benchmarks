#!/usr/bin/env bash
set -e

run_benchmark () {
    echo "---------------------------------------------------------------------------------------"
    echo "Benchmarking Laravel demo app: $NAME (OPCACHE: $PHP_OPCACHE, PRELOADING: $PHP_PRELOADING, JIT: $PHP_JIT)"
    echo "---------------------------------------------------------------------------------------"
    # Warmup
    docker run --rm jordi/ab -n 5 -c 1 http://$host_ip:8888/ > /dev/null
    # Benchmark
    (docker run --rm jordi/ab -n $AB_REQUESTS -c $AB_CONCURRENCY -S -d -q http://$host_ip:8888/)

    echo "---------------------------------------------------------------------------------------"
    echo "Benchmarking Symfony demo app: $NAME (OPCACHE: $PHP_OPCACHE, PRELOADING: $PHP_PRELOADING, JIT: $PHP_JIT)"
    echo "---------------------------------------------------------------------------------------"
    # Warmup
    docker run --rm jordi/ab -n 5 -c 1 http://$host_ip:8889/ > /dev/null
    # Benchmark
    (docker run jordi/ab -n $AB_REQUESTS -c $AB_CONCURRENCY -S -d -q http://$host_ip:8889/)

    echo "---------------------------------------------------------------------------------------"
    echo "Benchmarking Zend bench      : $NAME (OPCACHE: $PHP_OPCACHE, PRELOADING: $PHP_PRELOADING, JIT: $PHP_JIT)"
    echo "---------------------------------------------------------------------------------------"
    # Warmup
    docker run --rm jordi/ab -n 5 -c 1 http://$host_ip:8889/bench.php > /dev/null
    # Benchmark
    (docker run --rm curlimages/curl -s http://$host_ip:8890/bench.php)

    echo "---------------------------------------------------------------------------------------"
    echo "Benchmarking Zend micro bench: $NAME (OPCACHE: $PHP_OPCACHE, PRELOADING: $PHP_PRELOADING, JIT: $PHP_JIT)"
    echo "---------------------------------------------------------------------------------------"

    # Warmup
    docker run --rm jordi/ab -n 5 -c 1 -S -d http://$host_ip:8889/micro_bench.php > /dev/null
    # Benchmark
    (docker run curlimages/curl -s http://$host_ip:8890/micro_bench.php)
}

if [[ "$1" == "local-docker" ]]; then

    host_ip=`docker network inspect bridge -f '{{range.IPAM.Config}}{{.Gateway}}{{end}}'`
    result_file="$PROJECT_ROOT/tmp/result/$NAME.txt"

    touch "$result_file"

    run_benchmark | tee -a $result_file

elif [[ "$1" == "aws-docker" ]]; then

    echo "aws-docker"

elif [[ "$1" == "aws-host" ]]; then

    echo "aws-host"

else

    echo 'Available options: "local-docker", "aws-docker", "aws-host"!'
    exit 1

fi
