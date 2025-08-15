#!/usr/bin/env bash
set -e

abs () {
    local x="$1"

    printf "%.20f" "$(echo "scale=20; x=$x; if (x < 0) x = - (x); x" | bc -l)"
}

diff () {
  awk -v t1="$1" -v t2="$2" 'BEGIN{print (t1/t2-1) * 100}'
}

min () {
  echo "$1" | awk 'BEGIN{a=999999}{if ($1<0+a) a=$1}END{print a}'
}

max () {
  echo "$1" | awk 'BEGIN{a=0}{if ($1>0+a) a=$1}END{print a}'
}

mean () {
   local numbers=($1)
   local n="$2"
   local sum=0

   for val in "${numbers[@]}"; do
       sum="$(echo "scale=20; $sum + $val" | bc -l)"
   done

   printf "%.20f" "$(echo "scale=20; $sum / ${#numbers[@]}" | bc -l)"
}

median () {
    local arr=("$@")
    # Sort numbers numerically
    local sorted=($(printf "%s\n" "${arr[@]}" | sort -n))

    local n="${#sorted[@]}"
    local mid="$((n/2))"

    if (( n % 2 == 1 )); then
        # Odd length: middle element
        printf "%.20f" "${sorted[$mid]}"
    else
        # Even length: average of two middle elements
        printf "%.20f" "$(echo "scale=20; (${sorted[$mid-1]} + ${sorted[$mid]}) / 2" | bc -l)"
    fi
}

variance () {
    local numbers="$1"
    local mean="$2"
    local n="$3"

    local sum_sq_diff=0
    for val in $numbers; do
      diff="$(echo "scale=20; $val - $mean" | bc -l)"
      sq_diff="$(echo "scale=20; $diff * $diff" | bc -l)"
      sum_sq_diff="$(echo "scale=20; $sum_sq_diff + $sq_diff" | bc -l)"
    done

    # sample variance: divide by n-1 instead of n
    printf "%.20f" "$(echo "scale=20; $sum_sq_diff / ($n - 1)" | bc -l)"
}

# sample standard deviation
std_dev () {
    local numbers="$1"
    local mean="$2"
    local var="$3"
    local n="$4"

    printf "%.20f" "$(echo "scale=20; sqrt($var)" | bc -l)"
}

relative_std_dev () {
    local mean="$1"
    local std_dev="$2"

    printf "%.20f" "$(echo "scale=20; $std_dev / $mean * 100" | bc -l)"
}

welch_t () {
    local mean1="$1"
    local var1="$2"
    local n1="$3"
    local mean2="$4"
    local var2="$5"
    local n2="$6"

    local t_num="$(echo "scale=20; $mean1 - $mean2" | bc -l)"
    local t_denom="$(echo "scale=20; sqrt($var1 / $n1 + $var2 / $n2)" | bc -l)"

    printf "%.20f" "$(echo "scale=20; $t_num / $t_denom" | bc -l)"
}

# Degrees of freedom (Welch–Satterthwaite)
degrees_of_freedom () {
    local mean1="$1"
    local var1="$2"
    local n1="$3"

    local mean1="$4"
    local mean2="$5"
    local n2="$6"

    df_num="$(echo "scale=20; ($var1 / $n1 + $var2 / $n2)^2" | bc -l)"
    df_denom="$(echo "scale=20; (($var1 / $n1)^2) / ($n1 - 1) + (($var2 / $n2)^2) / ($n2 - 1)" | bc -l)"

    printf "%.20f" "$(echo "scale=20; $df_num / $df_denom" | bc -l)"
}

p_value () {
    local input1=($1)
    local mean1="$2"
    local var1="$3"
    local n1="${#input1[@]}"

    local input2=($4)
    local mean2="$5"
    local var2="$6"
    local n2="${#input2[@]}"

    if (( n1 < 2 || n2 < 2 )); then
        echo "Each dataset must have at least 2 values" >&2
        return 1
    fi

    t_stat="$(welch_t "$mean1" "$var1" "$n1" "$mean2" "$var2" "$n2")"
    df="$(degrees_of_freedom "$mean1" "$var1" "$n1" "$mean2" "$var2" "$n2")"

    local x="$(echo "scale=12; $df / ($df + $t_stat^2)" | bc -l)"
    # Using regularized incomplete beta approximation (simplified)
    local a="$(echo "scale=12; $df/2" | bc -l)"
    local b=0.5
    # Approximation of incomplete beta function using continued fraction
    # Here we use a simple bash approximation for demonstration
    # For higher accuracy, a proper beta function implementation is needed
    # Two-tailed p-value
    printf "%.20f" "$(echo "scale=12; 2* (1 - (0.5 + 0.5*sqrt(1 - $x)))" | bc -l)"

    #echo "T-statistic: $t_stat"
    #echo "Degrees of freedom: $df"
    #echo "Two-tailed p-value: $p_val"
}

print_environment () {
    printf "URI\tID\tName\tEnvironment\tRunner\tInstance type\tArchitecture\tCPU\tCPU cores\tRAM\tKernel\tOS\tGCC\tDedicated instance\tDeeper C-states\tTurbo boost\tHyper-threading\tTime\n" > "$1.tsv"

cat << EOF > "$1.md"
### $INFRA_NAME

|  Attribute    |     Value      |
|---------------|----------------|
EOF

    instance_type=""
    instance_type="$INFRA_INSTANCE_TYPE"
    if [[ "$INFRA_DEDICATED_INSTANCE" == "1" ]]; then
        instance_type="${instance_type} (dedicated)"
    fi
    instance_type="| Instance type |$instance_type|\n"

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
        deeper_c_states="0"
    else
        deeper_c_states="1"
    fi

    if [[ "$INFRA_DISABLE_TURBO_BOOST" == "1" ]]; then
        cpu_settings="${cpu_settings}, disabled turbo boost"
        turbo_boost="0"
    else
        turbo_boost="1"
    fi

    if [[ "$INFRA_DISABLE_HYPER_THREADING" == "1" ]]; then
        cpu_settings="${cpu_settings}, disabled hyper-threading"
        hyper_threading="0"
    else
        hyper_threading="1"
    fi

    if [ ! -z "$cpu_settings" ]; then
        cpu_settings="${cpu_settings:2}"
    fi

    printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%d\t%d GB\t%s\t%s\t%s\t%d\t%d\t%d\t%d\t%s\n" \
        "${RESULT_ROOT_DIR}_${RUN}_${INFRA_ID}" "$INFRA_ID" "$INFRA_NAME" "$INFRA_ENVIRONMENT" "$INFRA_RUNNER" "$INFRA_INSTANCE_TYPE" "$architecture" \
        "$cpu" "$cpu_count" "$ram_gb" "$kernel" "$os" "$gcc_version" "$INFRA_DEDICATED_INSTANCE" "$deeper_c_states" "$turbo_boost" "$hyper_threading" \
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
    printf "Test name\tTest warmup\tTest iterations\tTest requests\tPHP\tPHP Commit hash\tPHP Commit URL\tMin\tMax\tStd dev\Rel std dev %%\tMean\tMean diff %%\tMedian\tMedian diff %%\tP-value\tInstruction count\tMemory usage\n" >> "$1.tsv"
}

print_result_md_header () {
    description="$TEST_ITERATIONS consecutive runs"
    if [ ! -z "$TEST_REQUESTS" ]; then
        description="$description, $TEST_REQUESTS requests"
    fi

    if [ "$INFRA_MEASURE_INSTRUCTION_COUNT" == "1" ]; then
        instruction_count_header_name="|  Instr count  "
        instruction_count_header_separator="|---------------";
    else
        instruction_count_header_name=""
        instruction_count_header_separator="";
    fi

cat << EOF >> "$1.md"
### $TEST_NAME - $description (sec)

|     PHP     |     Min     |     Max     |    Std dev   | Rel std dev % |  Mean  | Mean diff % |   Median   | Median diff % | P-value $instruction_count_header_name|     Memory    |
|-------------|-------------|-------------|--------------|---------------|--------|-------------|------------|---------------|---------$instruction_count_header_separator|---------------|
EOF
}

print_result_value () {
    var="PHP_COMMITS_$PHP_ID"
    commit_hash="${!var}"
    commit_hash="$(echo "$commit_hash" | cut -c1-10)"
    url="${PHP_REPO//.git/}/commit/$commit_hash"

    results="$(cat "$1")"
    if [ -z "$first_results" ]; then
        first_results="$results"
    fi

    if [ "$INFRA_MEASURE_INSTRUCTION_COUNT" == "1" ]; then
        instruction_count_tsv_format="\t%d"
        instruction_count_tsv_value="$(cat "$2")"
        instruction_count_md_format="|%d"
        instruction_count_md_value="$(cat "$2")"
    else
        instruction_count_tsv_format="\t%d"
        instruction_count_tsv_value="0"
        instruction_count_md_format="%s"
        instruction_count_md_value=""
    fi
    memory_result="$(cat "$3")"

    echo ""
    echo "Descriptive statistics for $PHP_ID:"

    local n_arr=($results)
    local n="$(echo "${#n_arr[@]}")"
    echo "N: $n"

    local min="$(min "$results")"
    echo "Min: $min"

    local max="$(max "$results")"
    echo "Max: $max"

    local mean="$(mean "$results")"
    if [ -z "$first_mean" ]; then
        first_mean="$mean"
    fi
    local mean_diff="$(diff "$mean" "$first_mean")"
    echo "Mean: $mean ($mean_diff %)"

    local median="$(median $results)"
    if [ -z "$first_median" ]; then
        first_median="$median"
    fi
    local median_diff="$(diff "$median" "$first_median")"
    echo "Median: $median ($median_diff %)"

    local var="$(variance "$results" "$mean" "$n")"
    if [ -z "$first_var" ]; then
        first_var="$var"
    fi
    echo "Variance: $var"

    local std_dev="$(std_dev "$results" "$median" "$var" "$n")"
    local relative_std_dev="$(relative_std_dev "$mean" "$std_dev")"
    echo "Std dev: $std_dev ($relative_std_dev)"

    local p_value="$(p_value "$first_results" "$results")"
    echo "Two tailed P-value: $p_value"
    echo ""

    local memory_usage="$(echo "scale=3;${memory_result}/1024"|bc -l)"

    printf "%s\t%d\t%d\t%d\t%s\t%s\t%s\t%.5f\t%.5f\t%.5f\t%.5f\t%.5f\t%.2f\t%.5f\t%.2f\t%.3f$instruction_count_tsv_format\t%.2f\n" \
        "$TEST_NAME" "$TEST_WARMUP" "$TEST_ITERATIONS" "$TEST_REQUESTS" \
        "$PHP_NAME" "$commit_hash" "$url" \
        "$min" "$max" "$std_dev" "$relative_std_dev" "$mean" "$mean_diff" "$median" "$median_diff" "$p_value" "$instruction_count_tsv_value" "$memory_usage" >> "$4.tsv"

    if [ "$5" -eq "1" ]; then
        printf "|[%s]($url)|%.5f|%.5f|%.5f|%.2f%%|%.5f|%.2f%%|%.5f|%.2f%%|%.3f$instruction_count_md_format|%.2f MB|\n" \
            "$PHP_NAME" "$min" "$max" "$std_dev" "$relative_std_dev" "$mean" "$mean_diff" "$median" "$median_diff" "$p_value" "$instruction_count_md_value" "$memory_usage" >> "$4.md"
    fi
}

print_result_footer () {
    now="$(TZ=UTC date +'%Y-%m-%d %H:%M:%S')"

    printf "\n##### Generated: $now UTC\n" >> "$1.md"
}

run_cgi () {
    if [ "$PHP_OPCACHE" = "2" ]; then
        opcache="-d zend_extension=$php_source_path/modules/opcache.so"
    else
        opcache=""
    fi

    export CONTENT_TYPE="text/html; charset=utf-8"
    export SCRIPT_FILENAME="$PROJECT_ROOT/$4"
    export REQUEST_URI="$5"
    export HTTP_HOST="localhost"
    export SERVER_NAME="localhost"
    export REQUEST_METHOD="GET"
    export REDIRECT_STATUS="200"
    export APP_ENV="$6"
    export APP_DEBUG=false
    export APP_SECRET=random
    export SESSION_DRIVER=cookie
    export CACHE_STORE=null
    export LOG_LEVEL=warning
    export DB_CONNECTION=sqlite
    export LOG_CHANNEL=stderr
    export BROADCAST_DRIVER=null

    # TODO try to use sudo chrt -f 99 for real-time process
    if [ "$1" = "quiet" ]; then
        sleep 0.6
        taskset -c "$last_cpu" \
            $php_source_path/sapi/cgi/php-cgi $opcache -T "$2,$3" "$PROJECT_ROOT/$4" > /dev/null
    elif [ "$1" = "verbose" ]; then
        taskset -c "$last_cpu" \
            $php_source_path/sapi/cgi/php-cgi $opcache -T "$2,$3" "$PROJECT_ROOT/$4"
    elif [ "$1" = "instruction_count" ]; then
        sudo cgexec -g cpuset:bench \
            valgrind --tool=callgrind --dump-instr=no -- \
            $php_source_path/sapi/cgi/php-cgi $opcache -q -T "$2,$3" "$PROJECT_ROOT/$4" > /dev/null
    elif [ "$1" = "memory" ]; then
        sudo cgexec -g cpuset:bench \
            /usr/bin/time -v $php_source_path/sapi/cgi/php-cgi $opcache -q -T "$2,$3" "$PROJECT_ROOT/$4" > /dev/null
    else
        echo "Invalid php-cgi run mode"
        exit 1
    fi
}

run_cli () {
    if [ "$PHP_OPCACHE" = "2" ]; then
        opcache="-d zend_extension=$php_source_path/modules/opcache.so"
    else
        opcache=""
    fi

    # TODO try to use sudo chrt -f 99 for real-time process
    if [ "$1" = "quiet" ]; then
        taskset -c "$last_cpu" \
            $php_source_path/sapi/cli/php $opcache "$PROJECT_ROOT/$2" > /dev/null
    elif [ "$1" = "verbose" ]; then
        taskset -c "$last_cpu" \
            $php_source_path/sapi/cli/php $opcache "$PROJECT_ROOT/$2"
    elif [ "$1" = "normal" ]; then
        sleep 0.6
        taskset -c "$last_cpu" \
            $php_source_path/sapi/cli/php $opcache "$PROJECT_ROOT/$2"
    elif [ "$1" = "instruction_count" ]; then
        sudo cgexec -g cpuset:bench \
            valgrind --tool=callgrind --dump-instr=no -- \
            $php_source_path/sapi/cli/php $opcache "$PROJECT_ROOT/$2" > /dev/null
    elif [ "$1" = "memory" ]; then
        sudo cgexec -g cpuset:bench /usr/bin/time -v \
            $php_source_path/sapi/cli/php $opcache "$PROJECT_ROOT/$2" > /dev/null
    else
        echo "Invalid php-cli run mode"
        exit 1
    fi
}

assert_test_output() {
    expectation_file="$1"
    actual_file="$2"

    $php_source_path/sapi/cli/php "$PROJECT_ROOT/app/zend/assert_output.php" "$expectation_file" "$actual_file"
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

load_php_config () {
    source $PHP_CONFIG_FILE
    export PHP_CONFIG_FILE
    php_source_path="$PROJECT_ROOT/tmp/$PHP_ID"

    log_dir="$result_dir"
    log_file="$log_dir/${PHP_ID}.log"
    output_file="$log_dir/${PHP_ID}_output.txt"
    instruction_count_log_file="$log_dir/${PHP_ID}.instruction_count.log"
    memory_log_file="$log_dir/${PHP_ID}.memory.log"
    mkdir -p "$log_dir"
}

run_real_benchmark () {
    for PHP_CONFIG_FILE in $PROJECT_ROOT/config/php/*.ini; do
        load_php_config

        echo "---------------------------------------------------------------------------------------"
        echo "$TEST_NAME PERF STATS - $RUN/$N - $INFRA_NAME - $PHP_NAME (opcache: $PHP_OPCACHE, JIT: $PHP_JIT)"
        echo "---------------------------------------------------------------------------------------"

        # Verifying output
        run_cgi "verbose" "0" "1" "$1" "$2" "$3" | tee -a "$output_file"
        if [ ! -z "$test_expectation_file" ]; then
            assert_test_output "$test_expectation_file" "$output_file"
        fi

        # Measuring instruction count
        if [ "$INFRA_MEASURE_INSTRUCTION_COUNT" == "1" ]; then
            run_cgi "instruction_count" "10" "10" "$1" "$2" "$3" 2>&1 | tee -a "$instruction_count_log_file"
        fi

        # Measuring memory usage
        run_cgi "memory" "$TEST_WARMUP" "$TEST_REQUESTS" "$1" "$2" "$3" 2>&1 | tee -a "$memory_log_file"
    done

    sleep 7

    # Benchmark
    for i in $(seq $TEST_ITERATIONS); do
        for PHP_CONFIG_FILE in $PROJECT_ROOT/config/php/*.ini; do
            load_php_config

            echo "---------------------------------------------------------------------------------------"
            echo "$TEST_NAME BENCHMARK $i/$TEST_ITERATIONS - run $RUN/$N - $INFRA_NAME - $PHP_NAME (opcache: $PHP_OPCACHE, JIT: $PHP_JIT)"
            echo "---------------------------------------------------------------------------------------"

            run_cgi "quiet" "$TEST_WARMUP" "$TEST_REQUESTS" "$1" "$2" "$3" 2>&1 | tee -a "$log_file"
        done
    done

    for PHP_CONFIG_FILE in $PROJECT_ROOT/config/php/*.ini; do
        load_php_config

        # Format benchmark log
        sed -i".original" "/^[[:space:]]*$/d" "$log_file"
        sed -i".original" "s/Elapsed time\: //g" "$log_file"
        sed -i".original" "s/ sec//g" "$log_file"
        rm "$log_file.original"
    done
}

run_micro_benchmark () {
    for PHP_CONFIG_FILE in $PROJECT_ROOT/config/php/*.ini; do
        load_php_config

        echo "---------------------------------------------------------------------------------------"
        echo "$TEST_NAME PERF STATS - $RUN/$N - $INFRA_NAME - $PHP_NAME (opcache: $PHP_OPCACHE, JIT: $PHP_JIT)"
        echo "---------------------------------------------------------------------------------------"

        # Verifying output
        run_cli "verbose" "$1" | tee -a "$output_file"
        if [ ! -z "$test_expectation_file" ]; then
            assert_test_output "$test_expectation_file" "$output_file"
        fi

        # Measuring instruction count
        if [ "$INFRA_MEASURE_INSTRUCTION_COUNT" == "1" ]; then
            run_cli "instruction_count" "$1" 2>&1 | tee -a "$instruction_count_log_file"
        fi

        # Measuring memory usage
        run_cli "memory" "$1" 2>&1 | tee -a "$memory_log_file"
    done

    sleep 7

    # Benchmark
    for i in $(seq $TEST_ITERATIONS); do
        for PHP_CONFIG_FILE in $PROJECT_ROOT/config/php/*.ini; do
            load_php_config

            echo "---------------------------------------------------------------------------------------"
            echo "$TEST_NAME BENCHMARK $i/$TEST_ITERATIONS - run $RUN/$N - $INFRA_NAME - $PHP_NAME (opcache: $PHP_OPCACHE, JIT: $PHP_JIT)"
            echo "---------------------------------------------------------------------------------------"

            for w in $(seq $TEST_WARMUP); do
                run_cli "quiet" "$1"
            done

            run_cli "normal" "$1" 2>&1 | tee -a "$log_file"
        done
    done

    for PHP_CONFIG_FILE in $PROJECT_ROOT/config/php/*.ini; do
        load_php_config

        # Format benchmark log
        results="$(grep "Total" "$log_file")"
        echo "$results" > "$log_file"
        sed -i".original" "s/Total              //g" "$log_file"
        sed -i".original" -e "1,${TEST_WARMUP}d" "$log_file"
        rm "$log_file.original"
    done
}

run_benchmark () {
    test_expectation_file="${test_config//.ini/.expectation}"
    if [ ! -f "$test_expectation_file" ]; then
        test_expectation_file=""
    fi
    result_dir="$infra_dir/${TEST_NUMBER}_${TEST_ID}"
    result_file="$result_dir/result"

    mkdir -p "$result_dir"
    touch "$result_file.tsv"
    touch "$result_file.md"

    print_result_tsv_header "$result_file"
    print_result_md_header "$result_file"

    first_mean=""
    first_median=""
    first_results=""

    cpu_count="$(nproc)"
    last_cpu="$((cpu_count-1))"

    case "$TEST_ID" in
        laravel_*)
            run_real_benchmark "app/laravel/public/index.php" "" "production"
            ;;

        symfony_main_*)
            run_real_benchmark "app/symfony/public/index.php" "/" "prod"
            ;;

        symfony_blog_*)
            run_real_benchmark "app/symfony/public/index.php" "/en/blog/" "prod"
            ;;

        wordpress_*)
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
            exit 1
            ;;
    esac

    for PHP_CONFIG_FILE in $PROJECT_ROOT/config/php/*.ini; do
        load_php_config

        # Format instruction count log
        if [ "$INFRA_MEASURE_INSTRUCTION_COUNT" == "1" ]; then
            format_instruction_count_log_file "$instruction_count_log_file"
        fi

        # Format memory log
        format_memory_log_file "$memory_log_file"

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

    if [[ "$TEST_ID" == "wordpress_6_2" ]]; then
        sudo systemctl start containerd.service
        sudo service docker start

        db_container_id="$($run_as docker ps -aqf "name=wordpress_db")"
        $run_as docker start "$db_container_id"

        sleep 9
    fi

    run_benchmark

    if [[ "$TEST_ID" == "wordpress_6_2" ]]; then
        sudo service docker stop
        sudo systemctl stop containerd.service
    fi
done
