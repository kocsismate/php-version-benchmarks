#!/usr/bin/env bash
set -e

median() {
  arr=($(printf '%f\n' "${@}" | sort -n))
  nel=${#arr[@]}
  if (( $nel % 2 == 1 )); then
    val="${arr[ $(($nel/2)) ]}"
  else
    (( j=nel/2 ))
    (( k=j-1 ))
    val=$(echo "scale=4;(${arr[j]}" + "${arr[k]})"/2|bc -l)
  fi
  echo $val
}

std_deviation() {
    echo "$1" | tr -s ' ' '\n' | awk '{sum+=$1; sumsq+=$1*$1}END{print sqrt(sumsq/NR - (sum/NR)**2)}'
}

run_ab () {
    docker run --rm jordi/ab -n "$1" -c "$2" -q "$3"
}

run_curl () {
    for i in $(seq "$1"); do
        docker run --rm curlimages/curl -s "$2"
    done
}

run_benchmark () {
    printf "Benchmark\tMedian\tStdDev\n" >> "$result_file"

    echo "---------------------------------------------------------------------------------------"
    echo "Benchmarking Laravel demo app : $NAME (opcache: $PHP_OPCACHE, preloading: $PHP_PRELOADING, JIT: $PHP_JIT)"
    echo "---------------------------------------------------------------------------------------"
    # Warmup
    run_ab 8 1 http://$host_ip:8888/ > /dev/null
    # Benchmark
    run_ab "$AB_REQUESTS" "$AB_CONCURRENCY" http://$host_ip:8888/ | tee -a "$result_path/1_laravel.log"

    echo "---------------------------------------------------------------------------------------"
    echo "Benchmarking Symfony demo app : $NAME (opcache: $PHP_OPCACHE, preloading: $PHP_PRELOADING, JIT: $PHP_JIT)"
    echo "---------------------------------------------------------------------------------------"
    # Warmup
    run_ab 8 1 http://$host_ip:8889/ > /dev/null
    # Benchmark
    run_ab "$AB_REQUESTS" "$AB_CONCURRENCY" http://$host_ip:8889/ | tee -a "$result_path/2_symfony_main.log"

    echo "---------------------------------------------------------------------------------------"
    echo "Benchmarking Symfony demo blog: $NAME (opcache: $PHP_OPCACHE, preloading: $PHP_PRELOADING, JIT: $PHP_JIT)"
    echo "---------------------------------------------------------------------------------------"
    # Warmup
    run_ab 8 1 http://$host_ip:8889/en/blog/ > /dev/null
    # Benchmark
    run_ab "$AB_REQUESTS" "$AB_CONCURRENCY" http://$host_ip:8889/ | tee -a "$result_path/3_symfony_blog.log"

    echo "---------------------------------------------------------------------------------------"
    echo "Benchmarking Zend bench       : $NAME (opcache: $PHP_OPCACHE, preloading: $PHP_PRELOADING, JIT: $PHP_JIT)"
    echo "---------------------------------------------------------------------------------------"
    # Warmup
    run_ab 8 1 http://$host_ip:8889/bench.php > /dev/null
    # Benchmark
    run_curl 10 http://$host_ip:8890/bench.php | tee -a "$result_path/4_bench.log"
    # Calculate
    results="$(grep "Total" "$result_path/4_bench.log" | cut -c 20- | tr -s '\n' ' ')"
    printf "Bench:\t%.4f\t%.4f\n" "$(median $results)" "$(std_deviation "$results")" >> "$result_file"

    echo "---------------------------------------------------------------------------------------"
    echo "Benchmarking Zend micro bench: $NAME (opcache: $PHP_OPCACHE, preloading: $PHP_PRELOADING, JIT: $PHP_JIT)"
    echo "---------------------------------------------------------------------------------------"
    # Warmup
    run_ab 8 1 http://$host_ip:8889/micro_bench.php > /dev/null
    # Benchmark
    run_curl 10 http://$host_ip:8890/micro_bench.php | tee -a "$result_path/5_micro_bench.log"
    # Calculate
    results="$(grep "Total" "$result_path/5_micro_bench.log" | cut -c 20- | tr -s '\n' ' ')"
    printf "Micro bench:\t%.4f\t%.4f\n" "$(median $results)" "$(std_deviation "$results")" >> "$result_file"
}

result_path="$PROJECT_ROOT/tmp/result/$NAME"
log_file="$result_path/benchmark.log"
result_file="$result_path/benchmark.txt"

rm -rf "$result_path"
mkdir -p "$result_path"

touch "$log_file"
touch "$result_file"

if [[ "$1" == "local-docker" ]]; then

    host_ip=`docker network inspect bridge -f '{{range.IPAM.Config}}{{.Gateway}}{{end}}'`

    run_benchmark | tee -a $log_file

elif [[ "$1" == "aws-docker" ]]; then

    run_benchmark | tee -a $log_file

else

    echo 'Available options: "local-docker", "aws-docker"!'
    exit 1

fi
