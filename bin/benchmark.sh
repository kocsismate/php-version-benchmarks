#!/usr/bin/env bash
set -e

min () {
  echo "$1" | awk 'BEGIN{a=999999}{if ($1<0+a) a=$1}END{print a}'
}

max () {
  echo "$1" | awk 'BEGIN{a=0}{if ($1>0+a) a=$1}END{print a}'
}

average () {
  echo "$1" | awk '{sum+=$1}END{print sum/NR}'
}

median () {
  arr=($(printf '%f\n' "${@}" | sort -n))
  nel=${#arr[@]}
  if (( $nel % 2 == 1 )); then
    val="${arr[ $(($nel/2)) ]}"
  else
    (( j=nel/2 ))
    (( k=j-1 ))
    val=$(echo "scale=6;(${arr[j]}" + "${arr[k]})/2"|bc -l)
  fi
  echo $val
}

std_deviation () {
    echo "$1" | awk '{sum+=$1; sumsq+=$1*$1}END{print sqrt(sumsq/NR - (sum/NR)**2)}'
}

diff () {
  awk -v t1="$1" -v t2="$2" 'BEGIN{print (1-t1/t2) * 100}'
}

print_result_header () {
    printf "Benchmark\tMin\tMax\tAverage\tAverage diff %%\tMedian\tMedian diff %%\tStd dev\tCommit hash\nCommit URL\n" >> "$1.tsv"

    description="$TEST_ITERATIONS consecutive runs"
    if [ ! -z "$TEST_REQUESTS" ]; then
        description="$description, $TEST_REQUESTS requests"
    fi

cat << EOF >> "$1.md"
### $TEST_NAME - $INFRA_NAME - $description (sec)

|     PHP     |     Min     |     Max     |    Std dev   |   Average  |  Average diff % |   Median   | Median diff % |
|-------------|-------------|-------------|--------------|------------|-----------------|------------|---------------|
EOF
}

print_result_value () {
    var="PHP_COMMITS_$PHP_ID"
    commit_hash="${!var}"
    url="${PHP_REPO//.git/}/commit/$commit_hash"

    results="$(cat "$1")"

    min="$(min "$results")"
    max="$(max "$results")"
    average="$(average "$results")"
    if [ -z "$first_average" ]; then
        first_average="$average"
    fi
    average_diff="$(diff "$first_average" "$average")"
    median="$(median $results)"
    if [ -z "$first_median" ]; then
        first_median="$median"
    fi
    median_diff="$(diff "$first_median" "$median")"
    std_dev="$(std_deviation "$results")"

    printf "%s\t%.5f\t%.5f\t%.5f\t%.5f\t%.2f\t%.5f\t%.2f\t%s\t%s\n" "$PHP_NAME" "$min" "$max" "$std_dev" "$average" "$average_diff" "$median" "$median_diff" "$commit_hash" "$url" >> "$2.tsv"
    printf "|[%s]($url)|%.5f|%.5f|%.5f|%.5f|%.2f%%|%.5f|%.2f%%|\n"  "$PHP_NAME" "$min" "$max" "$std_dev" "$average" "$average_diff" "$median" "$median_diff" >> "$2.md"
}

print_result_footer () {
    now="$(date +'%Y-%m-%d %H:%M')"

    printf "\n##### Generated: $now\n" >> "$1.md"
}

run_cgi () {
    sleep 0.25

    if [[ "$INFRA_PROVISIONER" == "host" ]]; then
        if [ "$PHP_OPCACHE" = "1" ]; then
            opcache="-d zend_extension=$php_source_path/modules/opcache.so"
        else
            opcache=""
        fi

        export CONTENT_TYPE="text/html; charset=utf-8"
        export SCRIPT_FILENAME="$PROJECT_ROOT/$4"
        export REQUEST_URI="$5"
        export APP_ENV="$6"
        export APP_DEBUG=true
        export SESSION_DRIVER=cookie
        export LOG_LEVEL=warning
        export DB_CONNECTION=sqlite
        export LOG_CHANNEL=stderr
        export BROADCAST_DRIVER=null

        cpu_count="$(nproc)"
        last_cpu="$((cpu_count-1))"

        if [ "$1" = "quiet" ]; then
            taskset -c "$last_cpu" $php_source_path/sapi/cgi/php-cgi $opcache -T "$2,$3" "$PROJECT_ROOT/$4" > /dev/null
        elif [ "$1" = "verbose" ]; then
            taskset -c "$last_cpu" $php_source_path/sapi/cgi/php-cgi $opcache -T "$2,$3" "$PROJECT_ROOT/$4"
        else
            taskset -c "$last_cpu" $php_source_path/sapi/cgi/php-cgi $opcache -q -T "$2,$3" "$PROJECT_ROOT/$4"
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
            --cpuset-cpus=0 "$repository:$PHP_ID-latest" /code/build/container/php-cgi/run.sh "$1" "$2,$3" "$4" "$5" "$6"
    fi
}

run_real_benchmark () {
    # Benchmark
    run_cgi "verbose" "0" "1" "$1" "$2" "$3"
    run_cgi "quiet" "$TEST_WARMUP" "$TEST_REQUESTS" "$1" "$2" "$3" > /dev/null 2>&1
    for b in $(seq $TEST_ITERATIONS); do
        run_cgi "quiet" "$TEST_WARMUP" "$TEST_REQUESTS" "$1" "$2" "$3" 2>&1 | tee -a "$log_file"
    done

    # Format log
    sed -i".original" "/^[[:space:]]*$/d" "$log_file"
    sed -i".original" "s/Elapsed time\: //g" "$log_file"
    sed -i".original" "s/ sec//g" "$log_file"
    rm "$log_file.original"
}

run_micro_benchmark () {
    # Benchmark
    run_cgi "normal" "$TEST_WARMUP" "$TEST_ITERATIONS" "$1" "" "" 2>&1 | tee -a "$log_file"

    # Format log
    results="$(grep "Total" "$log_file")"
    echo "$results" > "$log_file"
    sed -i".original" "s/Total              //g" "$log_file"
    sed -i".original" -e "1,${TEST_WARMUP}d" "$log_file"
    rm "$log_file.original"
}

run_test () {

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

        *)
            echo "Invalid test ID!"
            ;;
    esac

}

run_benchmark () {

    final_result_dir="$result_base_dir/${TEST_NUMBER}_${TEST_ID}"
    final_result_file="$final_result_dir/result"

    mkdir -p "$final_result_dir"
    touch "$final_result_file.tsv"
    touch "$final_result_file.md"

    result_dir="$final_result_dir/${RUN}_${INFRA_ID}"
    result_file="$result_dir/result"

    mkdir -p "$result_dir"
    touch "$result_file.tsv"
    touch "$result_file.md"

    print_result_header "$result_file"
    if [ "$RUN" -eq "1" ]; then
        print_result_header "$final_result_file"
    fi

    first_average="";
    first_median="";

    for PHP_CONFIG_FILE in $PROJECT_ROOT/config/php/*.ini; do
        source $PHP_CONFIG_FILE
        export PHP_CONFIG_FILE
        php_source_path="$PROJECT_ROOT/tmp/$PHP_ID"

        final_log_dir="$result_base_dir/${TEST_NUMBER}_${TEST_ID}"
        final_log_file="$final_log_dir/${PHP_ID}.log"
        mkdir -p "$final_log_dir"

        log_dir="$final_log_dir/${RUN}_${INFRA_ID}"
        log_file="$log_dir/${PHP_ID}.log"
        mkdir -p "$log_dir"

        echo "---------------------------------------------------------------------------------------"
        echo "$TEST_NAME - $RUN/$N - $INFRA_NAME - $PHP_NAME (opcache: $PHP_OPCACHE, preloading: $PHP_PRELOADING, JIT: $PHP_JIT)"
        echo "---------------------------------------------------------------------------------------"

        run_test

        cat "$log_file" >> "$final_log_file"

        print_result_value "$log_file" "$result_file"
        if [ "$RUN" -eq "$N" ]; then
            print_result_value "$final_log_file" "$final_result_file"
        fi
    done

    print_result_footer "$result_file"
    if [ "$RUN" -eq "$N" ]; then
        print_result_footer "$final_result_file"
    fi

}

result_base_dir="$PROJECT_ROOT/result/$RESULT_ROOT_DIR"

TEST_NUMBER=0
TEST_COUNT=$(ls 2>/dev/null -Ubad1 -- ./config/test/*.ini | wc -l)

for test_config in $PROJECT_ROOT/config/test/*.ini; do
    source $test_config
    ((TEST_NUMBER=TEST_NUMBER+1))

    sleep 3
    run_benchmark

done
