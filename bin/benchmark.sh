#!/usr/bin/env bash
set -e

print_result_header () {
    printf "Benchmark\tMetric\tResult\tStdDev\tDescription\n" >> "$result_file_tsv"

    now="$(date +'%Y-%m-%d %H-%M')"
cat << EOF >> "$result_file_md"
### $NAME (opcache: $PHP_OPCACHE, preloading: $PHP_PRELOADING, JIT: $PHP_JIT)

|  Benchmark   |    Metric    |   Median    |    StdDev   | Description |
|--------------|--------------|-------------|-------------|-------------|
EOF
}

print_result_value () {
    printf "%s\t%s\t%.4f\t%.4f\t%s\n" "$1" "$2" "$3" "$4" "$5" >> "$result_file_tsv"
    printf "|%s|%s|%.4f|%.4f|%s|\n" "$1" "$2" "$3" "$4" "$5" >> "$result_file_md"
}

print_result_footer () {
    #commit="$(git -C "$GIT_PATH" rev-parse HEAD)"
    #url="${GIT_REPO//.git/}/commit/$commit"

    #printf "\n##### Generated: $now based on commit [$commit]($url)\n" >> "$result_file_md"
    printf "\n##### Generated: $now\n" >> "$result_file_md"
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

run_cgi () {
    if [[ "$mode" == "local-docker" ]]; then
        run_as=""
        repository="php-benchmark-fpm"
    elif [[ "$mode" == "aws-docker" ]]; then
        run_as="sudo"
        repository="$ECR_REGISTRY_ID/$ECR_REPOSITORY_NAME"
    fi

    $run_as docker run --rm --log-driver=none --env-file $PROJECT_ROOT/.env --env-file $CONFIG_FILE \
            --volume "$PROJECT_ROOT/build:/code/build:delegated" --volume "$PROJECT_ROOT/app:/code/app:delegated" \
            "$repository:$NAME-latest" /code/build/container/fpm/cgi.sh "$1" "$2,$3" "$4" "$5" "$6"
}

run_real_benchmark () {
    echo "---------------------------------------------------------------------------------------"
    echo "Benchmarking $1: $NAME (opcache: $PHP_OPCACHE, preloading: $PHP_PRELOADING, JIT: $PHP_JIT)"
    echo "---------------------------------------------------------------------------------------"

    # Benchmark
    for b in $(seq 10); do
        run_cgi "quiet" 10 "$AB_REQUESTS" "$3" "$4" "$5" 2>&1 | tee -a "$result_path/$2.log"
    done

    # Collect results
    results="$(grep "Elapsed time" "$result_path/$2.log" | cut -c 14- | cut -d ' ' -f 2)"
    print_result_value "$1" "time (sec)" "$(median $results)" "$(std_deviation "$results")" "$AB_REQUESTS requests, 10 consecutive runs"
}

run_micro_benchmark () {
    echo "---------------------------------------------------------------------------------------"
    echo "Benchmarking $1 : $NAME (opcache: $PHP_OPCACHE, preloading: $PHP_PRELOADING, JIT: $PHP_JIT)"
    echo "---------------------------------------------------------------------------------------"

    # Benchmark
    run_cgi "verbose" 5 10 "$3" "" "" 2>&1 | tee -a "$result_path/$2.log"

    # Calculate
    results="$(grep "Total" "$result_path/$2.log" | tail -n +6 | cut -c 20- | tr -s '\n' ' ')"
    print_result_value "$1" "time (sec)" "$(median $results)" "$(std_deviation "$results")" "10 consecutive runs"
}

run_benchmark () {

    sleep 4

    print_result_header

    run_real_benchmark "Laravel demo" "1_laravel" "/code/app/laravel/public/index.php" "" "production"

    run_real_benchmark "Symfony main" "2_symfony_main" "/code/app/symfony/public/index.php" "/" "prod"

    #run_real_benchmark "Symfony blog" "3_symfony_blog" "/code/app/symfony/public/index.php" "/en/blog/" "prod"

    run_micro_benchmark "bench.php" "4_bench" "/code/app/zend/bench.php"

    run_micro_benchmark "micro_bench.php" "5_micro_bench" "/code/app/zend/micro_bench.php"

    run_micro_benchmark "concat.php" "6_concat" "/code/app/zend/concat.php"

    print_result_footer
}

mode="$1"
result_path="$PROJECT_ROOT/result/$NOW/$RUN/$NAME"
result_file_tsv="$result_path/benchmark.tsv"
result_file_md="$result_path/benchmark.md"

rm -rf "$result_path"
mkdir -p "$result_path"

touch "$result_file_tsv"
touch "$result_file_md"

if [[ "$1" == "local-docker" ]]; then

    benchmark_uri=`docker network inspect bridge -f '{{range.IPAM.Config}}{{.Gateway}}{{end}}'`

    run_benchmark

elif [[ "$1" == "aws-docker" ]]; then

    run_benchmark

else

    echo 'Available options: "local-docker", "aws-docker"!'
    exit 1

fi
