#!/usr/bin/env bash
set -e

print_result_header () {
    printf "Benchmark\tMetric\tResult\tStdDev\tDescription\n" >> "$result_file_csv"

    now="$(date +'%Y-%m-%d %H-%M')"
cat << EOF >> "$result_file_md"
### $NAME (opcache: $PHP_OPCACHE, preloading: $PHP_PRELOADING, JIT: $PHP_JIT)

|  Benchmark   |    Metric    |   Result    |    StdDev   | Description |
|--------------|--------------|-------------|-------------|-------------|

EOF
}

print_result_value () {
    printf "%s\t%s\t%.4f\t%.4f\t%s\n" "$1" "$2" "$3" "$4" "$5" >> "$result_file_csv"
    printf "|%s|%s|%.4f|%.4f|%s|\n" "$1" "$2" "$3" "$4" "$5" >> "$result_file_md"
}

print_result_footer () {
    printf "##### Generated: $now\n" >> "$result_file_md"
}

median () {
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

std_deviation () {
    echo "$1" | tr -s ' ' '\n' | awk '{sum+=$1; sumsq+=$1*$1}END{print sqrt(sumsq/NR - (sum/NR)**2)}'
}

run_ab () {
    if [[ "$mode" == "local-docker" ]]; then
        docker run --rm jordi/ab -n "$1" -c "$2" -q "$3"
    elif [[ "$mode" == "aws-docker" ]]; then
        ab -n "$1" -c "$2" -q "$3"
    fi
}

run_curl () {
    for i in $(seq "$1"); do
        if [[ "$mode" == "local-docker" ]]; then
            docker run --rm curlimages/curl -s "$2"
        elif [[ "$mode" == "aws-docker" ]]; then
            curl -s "$2"
        fi
    done
}

run_ab_benchmark () {
    echo "---------------------------------------------------------------------------------------"
    echo "Benchmarking $1: $NAME (opcache: $PHP_OPCACHE, preloading: $PHP_PRELOADING, JIT: $PHP_JIT)"
    echo "---------------------------------------------------------------------------------------"

    # Warmup
    run_ab 10 2 "$3" > /dev/null

    # Benchmark
    run_ab "$AB_REQUESTS" "$AB_CONCURRENCY" "$3" | tee -a "$result_path/$2.log"

    # Reset OPCache
    run_curl 1 "http://$benchmark_uri:8890/opcache_reset.php" > /dev/null

    # Collect results
    results="$(grep "Requests per second" "$result_path/$2.log" | cut -d " " -f 7)"
    print_result_value "$1" "request/sec (mean)" "$results" "0.0000" "total: $AB_REQUESTS, concurrency: $AB_CONCURRENCY"
}

run_micro_benchmark () {
    echo "---------------------------------------------------------------------------------------"
    echo "Benchmarking $1 : $NAME (opcache: $PHP_OPCACHE, preloading: $PHP_PRELOADING, JIT: $PHP_JIT)"
    echo "---------------------------------------------------------------------------------------"

    # Warmup
    run_ab 10 2 "$3" > /dev/null

    # Benchmark
    run_curl 10 "$3" | tee -a "$result_path/$2.log"

    # Calculate
    results="$(grep "Total" "$result_path/$2.log" | cut -c 20- | tr -s '\n' ' ')"
    print_result_value "$1" "sec (median)" "$(median $results)" "$(std_deviation "$results")" "10 consecutive runs"
}

run_benchmark () {
    if [[ "$mode" == "aws-docker" ]]; then
        ping -c 3 "$benchmark_uri" | tee -a "$result_path/0_ping.log"
    fi

    sleep 10

    print_result_header

    run_ab_benchmark "Laravel demo" "1_laravel" "http://$benchmark_uri:8888/"

    run_ab_benchmark "Symfony main" "2_symfony_main" "http://$benchmark_uri:8889/"

    run_ab_benchmark "Symfony blog" "3_symfony_blog" "http://$benchmark_uri:8889/en/blog/"

    sleep 4

    run_micro_benchmark "bench.php" "4_bench" "http://$benchmark_uri:8890/bench.php"

    run_micro_benchmark "micro_bench.php" "5_micro_bench" "http://$benchmark_uri:8890/micro_bench.php"

    run_micro_benchmark "concat.php" "6_concat" "http://$benchmark_uri:8890/concat.php"

    print_result_footer
}

mode="$1"
result_path="$PROJECT_ROOT/result/$NOW/$RUN/$NAME"
log_file="$result_path/benchmark.log"
result_file_csv="$result_path/benchmark.csv"
result_file_md="$result_path/benchmark.md"

rm -rf "$result_path"
mkdir -p "$result_path"

touch "$log_file"
touch "$result_file_csv"
touch "$result_file_md"

if [[ "$1" == "local-docker" ]]; then

    benchmark_uri=`docker network inspect bridge -f '{{range.IPAM.Config}}{{.Gateway}}{{end}}'`

    run_benchmark | tee -a $log_file

elif [[ "$1" == "aws-docker" ]]; then

    run_benchmark | tee -a $log_file

else

    echo 'Available options: "local-docker", "aws-docker"!'
    exit 1

fi
