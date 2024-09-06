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
  awk -v t1="$1" -v t2="$2" 'BEGIN{print (t1/t2-1) * 100}'
}

print_environment () {
    printf "URI\tID\tName\tEnvironment\tRunner\tInstance type\tArchitecture\tCPU\tCPU cores\tRAM\tKernel\tOS\tGCC\tDedicated instance\tDisabled deeper C-states\tDisabled turbo boost\tDisabled hyper-threading\tTime\n" > "$1.tsv"

cat << EOF > "$1.md"
### $INFRA_NAME

|  Attribute    |     Value      |
|---------------|----------------|
EOF

    instance_type=""
    if [[ "$INFRA_ENVIRONMENT" != "local" ]]; then
        instance_type="$INFRA_INSTANCE_TYPE"
        if [[ "$INFRA_DEDICATED_INSTANCE" == "1" ]]; then
            instance_type="${instance_type} (dedicated)"
        fi
        instance_type="| Instance type |$instance_type|\n"
    fi

    architecture="$(uname -m)"
    kernel="$(uname -r)"

    if [[ "$OSTYPE" == "darwin"* ]]; then
        cpu="$(sysctl -n machdep.cpu.brand_string)"
        cpu_count="$(sysctl -n hw.ncpu)"

        os_name="$(sw_vers | grep '^ProductName:')"
        os_name="${os_name/ProductName:/}"
        os_name="$(echo "$os_name" | awk '{$1=$1;print}')"
        os_version="$(sw_vers | grep '^ProductVersion:')"
        os_version="${os_version/ProductVersion:/}"
        os_version="$(echo "$os_version" | awk '{$1=$1;print}')"
        os="$os_name $os_version"

        ram_b="$(sysctl -n hw.memsize)"
        ram_gb=$(expr $ram_b / 1024 / 1024 / 1024)
        gcc_version="$(gcc -v 2>&1 | grep "Apple clang version")"
    else
        cpu=""
        #cpu_info="$(lscpu)"
        #cpu="$(echo "$cpu_info" | grep '^Model name:')"
        #cpu="${cpu/Model name:/}"
        #cpu="$(echo "$cpu" | awk '{$1=$1;print}')"
        cpu_count="$(nproc)"

        ram_kb=$(grep "MemTotal" /proc/meminfo | awk '{print $2}')
        ram_gb=$(expr $ram_kb / 1024 / 1024)

        os="$(grep '^PRETTY_NAME=' /etc/os-release)"
        os="${os/PRETTY_NAME=/}"
        os="${os//\"/}"
        os="$(echo "$os" | awk '{$1=$1;print}')"
        gcc_version="$(gcc -v 2>&1 | grep "gcc version" | awk '{print $3}')"
    fi

    cpu_settings=""
    if [[ "$INFRA_DISABLE_DEEPER_C_STATES" == "1" ]]; then
        cpu_settings="${cpu_settings}, disabled deeper C-states"
    fi

    if [[ "$INFRA_DISABLE_TURBO_BOOST" == "1" ]]; then
        cpu_settings="${cpu_settings}, disabled turbo boost"
    fi

    if [[ "$INFRA_DISABLE_HYPER_THREADING" == "1" ]]; then
        cpu_settings="${cpu_settings}, disabled hyper-threading"
    fi

    printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%d\t%d GB\t%s\t%s\t%s\t%d\t%d\t%d\t%d\t%s\n" \
        "${RESULT_ROOT_DIR}_${RUN}_${INFRA_ID}" "$INFRA_ID" "$INFRA_NAME" "$INFRA_ENVIRONMENT" "$INFRA_RUNNER" "$INFRA_INSTANCE_TYPE" "$architecture" \
        "$cpu" "$cpu_count" "$ram_gb" "$kernel" "$os" "$gcc_version" "$INFRA_DEDICATED_INSTANCE" "$INFRA_DISABLE_DEEPER_C_STATES" "$INFRA_DISABLE_TURBO_BOOST" "$INFRA_DISABLE_HYPER_THREADING" \
        "$NOW" >> "$1.tsv"

    if [[ ! -z "$cpu" ]]; then
        cpu=", "
    fi
    cpu="${cpu_count} core"
    if [ "$cpu_count" -gt "1" ]; then
        cpu="${cpu}s"
    fi

    if [[ ! -z "$cpu_settings" ]]; then
        cpu_settings="| CPU settings  |$cpu_settings|\n"
    fi

    printf "| Environment   |%s|\n| Runner        |%s|\n$instance_type| Architecture  |%s\n| CPU           |%s|\n$cpu_settings| RAM           |%d GB|\n| Kernel        |%s|\n| OS            |%s|\n| GCC           |%s|\n| Time          |%s|\n" \
        "$INFRA_ENVIRONMENT" "$INFRA_RUNNER" "$architecture" \
        "$cpu" "$ram_gb" "$kernel" "$os" "$gcc_version" "$NOW UTC" >> "$1.md"
}

print_result_tsv_header () {
    printf "Test name\tTest warmup\tTest iterations\tTest requests\tPHP\tPHP Commit hash\tPHP Commit URL\tMin\tMax\tStd dev\tAverage\tAverage diff %%\tMedian\tMedian diff %%\tInstruction count\n\tMemory usage\n" >> "$1.tsv"
}

print_result_md_header () {
    description="$TEST_ITERATIONS consecutive runs"
    if [ ! -z "$TEST_REQUESTS" ]; then
        description="$description, $TEST_REQUESTS requests"
    fi

cat << EOF >> "$1.md"
### $TEST_NAME - $description (sec)

|     PHP     |     Min     |     Max     |    Std dev   |   Average  |  Average diff % |   Median   | Median diff % |  Instr count  |     Memory    |
|-------------|-------------|-------------|--------------|------------|-----------------|------------|---------------|---------------|---------------|
EOF
}

print_result_value () {
    var="PHP_COMMITS_$PHP_ID"
    commit_hash="${!var}"
    url="${PHP_REPO//.git/}/commit/$commit_hash"

    results="$(cat "$1")"
    instruction_count="$(cat "$2")"
    memory_result="$(cat "$3")"

    min="$(min "$results")"
    max="$(max "$results")"
    average="$(average "$results")"
    if [ -z "$first_average" ]; then
        first_average="$average"
    fi
    average_diff="$(diff "$average" "$first_average")"
    median="$(median $results)"
    if [ -z "$first_median" ]; then
        first_median="$median"
    fi
    median_diff="$(diff "$median" "$first_median")"
    std_dev="$(std_deviation "$results")"
    memory_usage="$(echo "scale=3;${memory_result}/1024"|bc -l)"

    printf "%s\t%d\t%d\t%d\t%s\t%s\t%s\t%.5f\t%.5f\t%.5f\t%.5f\t%.2f\t%.5f\t%.2f\t%d\t%.2f\n" \
        "$TEST_NAME" "$TEST_WARMUP" "$TEST_ITERATIONS" "$TEST_REQUESTS" \
        "$PHP_NAME" "$commit_hash" "$url" \
        "$min" "$max" "$std_dev" "$average" "$average_diff" "$median" "$median_diff" "$instruction_count" "$memory_usage" >> "$4.tsv"

    if [ "$5" -eq "1" ]; then
        printf "|[%s]($url)|%.5f|%.5f|%.5f|%.5f|%.2f%%|%.5f|%.2f%%|%d|%.2f MB|\n" \
            "$PHP_NAME" "$min" "$max" "$std_dev" "$average" "$average_diff" "$median" "$median_diff" "$instruction_count" "$memory_usage" >> "$4.md"
    fi
}

print_result_footer () {
    now="$(TZ=UTC date +'%Y-%m-%d %H:%M:%S')"

    printf "\n##### Generated: $now UTC\n" >> "$1.md"
}

run_cgi () {
    if [[ -z "$INFRA_DISABLE_TURBO_BOOST" ]]; then
        sleep 0.25
    fi

    if [[ "$INFRA_RUNNER" == "host" ]]; then
        if [ "$PHP_OPCACHE" = "1" ]; then
            opcache="-d zend_extension=$php_source_path/modules/opcache.so"
        else
            opcache=""
        fi

        export CONTENT_TYPE="text/html; charset=utf-8"
        export SCRIPT_FILENAME="$PROJECT_ROOT/$4"
        export REQUEST_URI="$5"
        export APP_ENV="$6"
        export APP_DEBUG=false
        export SESSION_DRIVER=cookie
        export LOG_LEVEL=warning
        export DB_CONNECTION=sqlite
        export LOG_CHANNEL=stderr
        export BROADCAST_DRIVER=null

        cpu_count="$(nproc)"
        last_cpu="$((cpu_count-1))"

        if [ "$1" = "quiet" ]; then
            taskset -c "$last_cpu" \
                $php_source_path/sapi/cgi/php-cgi $opcache -T "$2,$3" "$PROJECT_ROOT/$4" > /dev/null
        elif [ "$1" = "verbose" ]; then
            taskset -c "$last_cpu" \
                $php_source_path/sapi/cgi/php-cgi $opcache -T "$2,$3" "$PROJECT_ROOT/$4"
        elif [ "$1" = "instruction_count" ]; then
            taskset -c "$last_cpu" \
                valgrind --tool=callgrind --dump-instr=no -- \
                $php_source_path/sapi/cgi/php-cgi $opcache -q -T "$2,$3" "$PROJECT_ROOT/$4" > /dev/null
        elif [ "$1" = "memory" ]; then
            /usr/bin/time -v taskset -c "$last_cpu" \
                $php_source_path/sapi/cgi/php-cgi $opcache -q -T "$2,$3" "$PROJECT_ROOT/$4" > /dev/null
        else
            taskset -c "$last_cpu" \
                $php_source_path/sapi/cgi/php-cgi $opcache -q -T "$2,$3" "$PROJECT_ROOT/$4"
        fi
    elif [[ "$INFRA_RUNNER" == "docker" ]]; then
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

format_instruction_count_log_file() {
    result="$(grep "== Collected : " "$1")"
    echo "$result" > "$1"
    sed -i".original" -E "s/==[0-9]+== Collected : //g" "$1"
    rm "$1.original"
}

format_memory_log_file() {
    result="$(grep "Maximum resident set size" "$1")"
    echo "$result" > "$1"
    sed -i".original" "s/	Maximum resident set size (kbytes): //g" "$1"
    rm "$1.original"
}

run_real_benchmark () {
    # Benchmark
    run_cgi "verbose" "0" "1" "$1" "$2" "$3"
    run_cgi "instruction_count" "10" "10" "$1" "$2" "$3" 2>&1 | tee -a "$instruction_count_log_file"
    run_cgi "memory" "$TEST_WARMUP" "$TEST_REQUESTS" "$1" "$2" "$3" 2>&1 | tee -a "$memory_log_file"
    for b in $(seq $TEST_ITERATIONS); do
        run_cgi "quiet" "$TEST_WARMUP" "$TEST_REQUESTS" "$1" "$2" "$3" 2>&1 | tee -a "$log_file"
    done

    format_instruction_count_log_file "$instruction_count_log_file"
    format_memory_log_file "$memory_log_file"

    # Format log
    sed -i".original" "/^[[:space:]]*$/d" "$log_file"
    sed -i".original" "s/Elapsed time\: //g" "$log_file"
    sed -i".original" "s/ sec//g" "$log_file"
    rm "$log_file.original"
}

run_micro_benchmark () {
    # Benchmark
    run_cgi "instruction_count" "2" "2" "$1" "" "" 2>&1 | tee -a "$instruction_count_log_file"
    run_cgi "memory" "0" "$TEST_WARMUP" "$1" "" "" 2>&1 | tee -a "$memory_log_file"
    run_cgi "normal" "$TEST_WARMUP" "$TEST_ITERATIONS" "$1" "" "" 2>&1 | tee -a "$log_file"

    format_instruction_count_log_file "$instruction_count_log_file"
    format_memory_log_file "$memory_log_file"

    # Format log
    results="$(grep "Total" "$log_file")"
    echo "$results" > "$log_file"
    sed -i".original" "s/Total              //g" "$log_file"
    sed -i".original" -e "1,${TEST_WARMUP}d" "$log_file"
    rm "$log_file.original"
}

run_test () {

    case "$TEST_ID" in

        laravel_11_1_2)
            run_real_benchmark "app/laravel/public/index.php" "" "production"
            ;;

        symfony_main_2_6_0)
            run_real_benchmark "app/symfony/public/index.php" "/" "prod"
            ;;

        symfony_blog_2_6_0)
            run_real_benchmark "app/symfony/public/index.php" "/en/blog/" "prod"
            ;;

        wordpress_6_2)
            run_real_benchmark "app/wordpress/index.php" "/" "prod"
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

    result_dir="$infra_dir/${TEST_NUMBER}_${TEST_ID}"
    result_file="$result_dir/result"

    mkdir -p "$result_dir"
    touch "$result_file.tsv"
    touch "$result_file.md"

    print_result_tsv_header "$result_file"
    print_result_md_header "$result_file"

    first_average="";
    first_median="";

    for PHP_CONFIG_FILE in $PROJECT_ROOT/config/php/*.ini; do
        source $PHP_CONFIG_FILE
        export PHP_CONFIG_FILE
        php_source_path="$PROJECT_ROOT/tmp/$PHP_ID"

        log_dir="$result_dir"
        log_file="$log_dir/${PHP_ID}.log"
        instruction_count_log_file="$log_dir/${PHP_ID}.instruction_count.log"
        memory_log_file="$log_dir/${PHP_ID}.memory.log"
        mkdir -p "$log_dir"

        echo "---------------------------------------------------------------------------------------"
        echo "$TEST_NAME - $RUN/$N - $INFRA_NAME - $PHP_NAME (opcache: $PHP_OPCACHE, JIT: $PHP_JIT)"
        echo "---------------------------------------------------------------------------------------"

        run_test

        print_result_value "$log_file" "$instruction_count_log_file" "$memory_log_file" "$result_file" "1"
        print_result_value "$log_file" "$instruction_count_log_file" "$memory_log_file" "$final_result_file" "0"
    done

    echo "" >> "$final_result_file.md"
    cat "$result_file.md" >> "$final_result_file.md"

}

result_base_dir="$PROJECT_ROOT/tmp/results/$RESULT_ROOT_DIR"

infra_dir="$result_base_dir/${RUN}_${INFRA_ID}"
final_result_file="$infra_dir/result"
mkdir -p "$infra_dir"
touch "$final_result_file.tsv"
touch "$final_result_file.md"

print_result_tsv_header "$final_result_file"

environment_file="$infra_dir/environment"

print_environment "$environment_file"
cat "$environment_file.md" >> "$final_result_file.md"

TEST_NUMBER=0

for test_config in $PROJECT_ROOT/config/test/*.ini; do
    source $test_config
    ((TEST_NUMBER=TEST_NUMBER+1))

    if [[ "$INFRA_ENVIRONMENT" == "aws" && "$INFRA_RUNNER" == "host" && "$TEST_ID" == "wordpress_6_2" ]]; then
        sudo service docker start

        db_container_id="$($run_as docker ps -aqf "name=wordpress_db")"
        $run_as docker start "$db_container_id"

        sleep 9
    fi

    if [[ -z "$INFRA_DISABLE_TURBO_BOOST" ]]; then
        sleep 5
    else
        sleep 1
    fi

    run_benchmark

    if [[ "$INFRA_ENVIRONMENT" == "aws" && "$INFRA_RUNNER" == "host" && "$TEST_ID" == "wordpress_6_2" ]]; then
        sudo service docker stop
    fi
done
