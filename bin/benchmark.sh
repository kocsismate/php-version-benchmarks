#!/usr/bin/env bash
set -e

print_result_header () {
    printf "Benchmark\tMetric\tResult\tStdDev\tDescription\n" >> "$result_file_tsv"

    now="$(date +'%Y-%m-%d %H:%M')"
cat << EOF >> "$result_file_md"
### $PHP_ID (opcache: $PHP_OPCACHE, preloading: $PHP_PRELOADING, JIT: $PHP_JIT)

|  Benchmark   |    Metric    |   Median    |    StdDev   | Description |
|--------------|--------------|-------------|-------------|-------------|
EOF
}

print_result_value () {
    printf "%s\t%s\t%.4f\t%.4f\t%s\n" "$1" "$2" "$3" "$4" "$5" >> "$result_file_tsv"
    printf "|%s|%s|%.4f|%.4f|%s|\n" "$1" "$2" "$3" "$4" "$5" >> "$result_file_md"
}

print_result_footer () {
    var="PHP_COMMITS_$PHP_ID"
    commit_hash="${!var}"
    url="${PHP_REPO//.git/}/commit/$commit_hash"

    printf "\n##### Generated: $now based on commit [$commit_hash]($url)\n" >> "$result_file_md"
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
    if [[ "$INFRA_PROVISIONER" == "host" ]]; then
        if [ "$PHP_OPCACHE" = "1" ]; then
            opcache="-d zend_extension=$php_source_path/modules/opcache.so"
        else
            opcache=""
        fi

        export REQUEST_URI="$5"
        export APP_ENV="$6"
        export APP_DEBUG=false
        export SESSION_DRIVER=cookie
        export LOG_LEVEL=warning

        if [ "$1" = "quiet" ]; then
            taskset 4 $php_source_path/sapi/cgi/php-cgi $opcache -T "$2,$3" "$PROJECT_ROOT/$4" > /dev/null
        else
            taskset 4 $php_source_path/sapi/cgi/php-cgi $opcache -q -T "$2,$3" "$PROJECT_ROOT/$4"
        fi
    elif [[ "$INFRA_PROVISIONER" == "docker" ]]; then
        if [[ "$INFRA_ENVIRONMENT" == "local" ]]; then
            run_as=""
            repository="$INFRA_DOCKER_REPOSITORY"
        elif [[ "$INFRA_ENVIRONMENT" == "aws" ]]; then
            run_as="sudo"
            repository="$INFRA_DOCKER_REGISTRY/$INFRA_DOCKER_REPOSITORY"
        fi

        $run_as docker run --rm --log-driver=none --env-file "$PHP_CONFIG_FILE" \
            --volume "$PROJECT_ROOT/build:/code/build:delegated" --volume "$PROJECT_ROOT/app:/code/app:delegated" \
            "$repository:$PHP_ID-latest" /code/build/container/php-cgi/run.sh "$1" "$2,$3" "$4" "$5" "$6"
    fi
}

run_real_benchmark () {
    echo "---------------------------------------------------------------------------------------"
    echo "Benchmarking $TEST_NAME: $PHP_NAME (opcache: $PHP_OPCACHE, preloading: $PHP_PRELOADING, JIT: $PHP_JIT)"
    echo "---------------------------------------------------------------------------------------"

    # Benchmark
    run_cgi "quiet" "$TEST_WARMUP" "$TEST_REQUESTS" "$1" "$2" "$3" > /dev/null 2>&1
    for b in $(seq $TEST_ITERATIONS); do
        run_cgi "quiet" "$TEST_WARMUP" "$TEST_REQUESTS" "$1" "$2" "$3" 2>&1 | tee -a "$log_path/${TEST_NUMBER}_$TEST_ID.log"
    done

    # Collect results
    results="$(grep "Elapsed time" "$log_path/${TEST_NUMBER}_$TEST_ID.log" | cut -c 14- | cut -d ' ' -f 2)"
    print_result_value "$TEST_NAME" "time (sec)" "$(median $results)" "$(std_deviation "$results")" "$TEST_ITERATIONS consecutive runs, $TEST_REQUESTS requests"
}

run_micro_benchmark () {
    echo "---------------------------------------------------------------------------------------"
    echo "Benchmarking $TEST_NAME : $PHP_NAME (opcache: $PHP_OPCACHE, preloading: $PHP_PRELOADING, JIT: $PHP_JIT)"
    echo "---------------------------------------------------------------------------------------"

    # Benchmark
    run_cgi "quiet" "$TEST_WARMUP" "$TEST_ITERATIONS" "$1" "" "" > /dev/null 2>&1
    run_cgi "verbose" "$TEST_WARMUP" "$TEST_ITERATIONS" "$1" "" "" 2>&1 | tee -a "$log_path/${TEST_NUMBER}_$TEST_ID.log"

    # Calculate
    results="$(grep "Total" "$log_path/${TEST_NUMBER}_$TEST_ID.log" | tail -n +6 | cut -c 20- | tr -s '\n' ' ')"
    print_result_value "$TEST_NAME" "time (sec)" "$(median $results)" "$(std_deviation "$results")" "$TEST_ITERATIONS consecutive runs"
}

run_benchmark () {

    sleep 4

    print_result_header

    TEST_NUMBER=0
    for test_config in $PROJECT_ROOT/config/test/*.ini; do
        source $test_config
        ((TEST_NUMBER=TEST_NUMBER+1))

        case "$TEST_ID" in

            laravel)
                run_real_benchmark "app/laravel/public/index.php" "" "production"
                ;;

            symfony_main)
                run_real_benchmark "app/symfony/public/index.php" "/" "prod"
                ;;

            symfony_blog)
                run_real_benchmark "app/symfony/public/index.php" "/en/blog/" "prod"
                ;;

            bench)
                run_micro_benchmark "app/zend/bench.php"
                ;;

            micro_bench)
                run_micro_benchmark "app/zend/micro_bench.php"
                ;;

            concat)
                run_micro_benchmark "app/zend/concat.php"
                ;;

            *)
                echo "Invalid test ID!"
                ;;
        esac
    done

    print_result_footer
}

result_path="$PROJECT_ROOT/result/$RESULT_ROOT_DIR/$RUN"

for PHP_CONFIG_FILE in $PROJECT_ROOT/config/php/*.ini; do
    source $PHP_CONFIG_FILE
    export PHP_CONFIG_FILE
    php_source_path="$PROJECT_ROOT/tmp/$PHP_ID"

    log_path="$result_path/$PHP_ID"
    result_file_tsv="$result_path/$PHP_ID.tsv"
    result_file_md="$result_path/$PHP_ID.md"

    rm -rf "$log_path"
    mkdir -p "$log_path"

    touch "$result_file_tsv"
    touch "$result_file_md"

    echo "---------------------------------------------------------------------------------------"
    echo "$RUN/$N - $INFRA_NAME - $PHP_NAME (opcache: $PHP_OPCACHE, preloading: $PHP_PRELOADING, JIT: $PHP_JIT)"
    echo "---------------------------------------------------------------------------------------"

    run_benchmark
done
