#!/usr/bin/env bash
set -e

source $PROJECT_ROOT/bin/math/lib.sh

print_environment () {
    printf "URI\tID\tName\tEnvironment\tRunner\tInstance type\tArchitecture\tCPU\tCPU cores\tCPU frequency\tRAM\tKernel\tOS\tGCC\tDedicated instance\tDeeper C-states\tTurbo boost\tHyper-threading\tTime\n" > "$1.tsv"

cat << EOF > "$1.md"
### $INFRA_NAME

|  Attribute    |     Value      |
|---------------|----------------|
EOF

    instance_type="$INFRA_INSTANCE_TYPE"
    if [[ "$INFRA_DEDICATED_INSTANCE" == "1" ]]; then
        instance_type="${instance_type} (dedicated)"
    fi
    instance_type="| Instance type |$instance_type|\n"

    local architecture="$(uname -m)"
    local kernel="$(uname -r)"

    cpu="$(lscpu | grep '^Model name:' || true)"
    cpu="${cpu/Model name:/}"
    cpu="$(echo "$cpu" | awk '{$1=$1;print}')"

    ram_kb=$(grep "MemTotal" /proc/meminfo | awk '{print $2}')
    ram_gb=$(expr "$ram_kb" / 1024 / 1024)

    os="$(grep '^PRETTY_NAME=' /etc/os-release)"
    os="${os/PRETTY_NAME=/}"
    os="${os//\"/}"
    os="$(echo "$os" | awk '{$1=$1;print}')"
    gcc_version="$(gcc -v 2>&1 | grep "gcc version" | awk '{print $3}')"

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

    if [[ "$INFRA_LOCK_CPU_FREQUENCY" == "1" ]]; then
        cpu_frequency_khz="$(cat /sys/devices/system/cpu/cpu0/cpufreq/base_frequency)"
        cpu_frequency_mhz="$(( cpu_frequency_khz / 1000 ))"
    else
        cpu_frequency_mhz=""
    fi

    if [ ! -z "$cpu_settings" ]; then
        cpu_settings="${cpu_settings:2}"
    fi

    printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%d\t%d\t%d\t%s\t%s\t%s\t%d\t%d\t%d\t%d\t%s\n" \
        "${RESULT_ROOT_DIR}_${RUN}_${INFRA_ID}" "$INFRA_ID" "$INFRA_NAME" "$INFRA_ENVIRONMENT" "$INFRA_RUNNER" "$INFRA_INSTANCE_TYPE" "$architecture" \
        "$cpu" "$BENCH_CPU_COUNT" "$cpu_frequency_mhz" "$ram_gb" "$kernel" "$os" "$gcc_version" "$INFRA_DEDICATED_INSTANCE" "$deeper_c_states" "$turbo_boost" "$hyper_threading" \
        "$NOW" >> "$1.tsv"

    if [[ -n "$cpu" ]]; then
        cpu="${cpu}, "
    fi
    cpu="${cpu}${BENCH_CPU_COUNT} core"
    if [ "$BENCH_CPU_COUNT" -gt "1" ]; then
        cpu="${cpu}s"
    fi

    if [[ -n "$cpu_frequency_mhz" ]]; then
        cpu="${cpu} @ $cpu_frequency_mhz MHz"
    fi

    if [[ -n "$cpu_settings" ]]; then
        cpu_settings="| CPU settings  |$cpu_settings|\n"
    fi

    if [[ -n "$BENCHMARK_LOG_URL" || -n "$BENCHMARK_ARTIFACT_URL" ]]; then
        job_details_value="$BENCHMARK_LOG_URL"
        if [[ -n "$BENCHMARK_ARTIFACT_URL" ]]; then
            job_details_value="$job_details_value ([Artifacts]($BENCHMARK_ARTIFACT_URL))"
        fi
        job_details="| Job details  |$job_details_value|\n"
    fi

    if [[ -n "$BENCHMARK_EXTRA_TITLE" && -n "$BENCHMARK_EXTRA_TEXT" ]]; then
        extra="| $BENCHMARK_EXTRA_TITLE  |$BENCHMARK_EXTRA_TEXT|\n"
    fi

    printf "| Environment   |%s|\n${instance_type}| Architecture  |%s\n| CPU           |%s|\n${cpu_settings}| RAM           |%d GB|\n| Kernel        |%s|\n| OS            |%s|\n| GCC           |%s|\n| Time          |%s|\n${job_details}${extra}" \
        "$INFRA_ENVIRONMENT" "$architecture" \
        "$cpu" "$ram_gb" "$kernel" "$os" "$gcc_version" "$NOW UTC" >> "$1.md"
}

print_result_tsv_header () {
    printf "Test name\tTest warmup\tTest iterations\tTest requests\tPHP\tPHP Commit hash\tPHP Commit URL\tMin\tMax\tStd dev\tRel std dev %%\tMean\tMean diff %%\tMedian\tMedian diff %%\tSkewness\tZ-stat\tP-value\tMemory usage\n" >> "$1.tsv"
}

print_result_md_header () {
    local result_file="$1"

    local run_suffix=""
    if [ "$TEST_ITERATIONS" -gt "1" ]; then
        run_suffix="s"
    fi

    local warmup_suffix=""
    if [ "$TEST_WARMUP" -gt "1" ]; then
        warmup_suffix="s"
    fi

    local request_suffix=""
    if [ "$TEST_REQUESTS" -gt "1" ]; then
        request_suffix="s"
    fi

    local description="$(printf "%d iteration%s, %d warmup%s, %d request%s" "$TEST_ITERATIONS" "$run_suffix" "$TEST_WARMUP" "$warmup_suffix" "$TEST_REQUESTS" "$request_suffix")"

cat << EOF >> "$result_file.md"
### $TEST_NAME - $description (sec)

|     PHP     |     Min     |     Max     |    Std dev   | Rel std dev % |  Mean  | Mean diff % |   Median   | Median diff % | Skewness |  Z-stat  | P-value |     Memory    |
|-------------|-------------|-------------|--------------|---------------|--------|-------------|------------|---------------|----------|----------|---------|---------------|
EOF
}

print_result_value () {
    local log_file="$1"
    local memory_log_file="$2"
    local perf_log_file="$3"
    local result_file="$4"
    local final_result_file="$5"
    local stat_file="$6"

    local var="PHP_COMMITS_$PHP_ID"
    local commit_hash="${!var}"
    commit_hash="$(echo "$commit_hash" | cut -c 1-10)"
    local url="${PHP_REPO//.git/}/commit/$commit_hash"

    local results="$(cat "$log_file")"
    if [ -z "$first_results" ]; then
        first_results="$results"
    fi
    if [ -z "$first_log_file" ]; then
        first_log_file="$log_file"
    fi

    local memory_result="$(cat "$memory_log_file")"

    local n_arr=($results)
    local n="$(echo "${#n_arr[@]}")"
    if [ -z "$first_n" ]; then
        first_n="$n"
    fi
    local min="$(min "$results")"
    local max="$(max "$results")"
    local mean="$(mean "$results")"
    if [ -z "$first_mean" ]; then
        first_mean="$mean"
    fi
    local mean_diff="$(percent_diff "$mean" "$first_mean")"
    local median="$(median "$results" "$n")"
    if [ -z "$first_median" ]; then
        first_median="$median"
    fi
    local median_diff="$(percent_diff "$median" "$first_median")"
    local variance="$(variance "$results" "$mean" "$n")"
    if [ -z "$first_var" ]; then
        first_var="$variance"
    fi
    local std_dev="$(std_dev "$variance")"
    local relative_std_dev="$(relative_std_dev "$mean" "$std_dev")"
    local skewness="$(skewness "$results" "$mean" "$std_dev" "$n")"
    local mad="$(median_abs_dev "$results" "$median" "$n")"
    local outliers="$(outliers "$results" "$median" "$mad")"
    local apparent_distribution="$(decide_distribution "$results" "$n" "$skewness")"
    local df="$(degrees_of_freedom "$first_var" "$first_n" "$variance" "$n")"
    local welch_t_stat="$(welch_t_stat "$first_mean" "$first_var" "$first_n" "$mean" "$variance" "$n")"
    local welch_p_value="$(welch_p_value "$df" "$welch_t_stat")"
    read wilcoxon_u1_value wilcoxon_u2_value <<< "$(wilcoxon_u_test "$first_log_file" "$log_file" "$n")"
    local wilcoxon_z_stat="$(wilcoxon_z_test "$n" "$wilcoxon_u1_value" "$first_log_file" "$log_file")"
    local wilcoxon_p_value="$(wilcoxon_p_value "$wilcoxon_z_stat")"
    local effect_size_standardized="$(effect_size_standardized "$n" "$wilcoxon_z_stat")"
    local effect_size_common="$(effect_size_common "$n" "$wilcoxon_u1_value")"

    echo "-----------------------------------------------------------------"
    echo "$PHP_ID"
    echo "-----------------------------------------------------------------"
    echo "Descriptive statistics"
    echo "- N                 : $n" | tee -a "$stat_file"
    echo "- Min               : $min" | tee -a "$stat_file"
    echo "- Max               : $max" | tee -a "$stat_file"
    printf -- "- Mean              : %.6f (%.6f %%)\n" "$mean" "$mean_diff" | tee -a "$stat_file"
    printf -- "- Median            : %.6f (%.6f %%)\n" "$median" "$median_diff" | tee -a "$stat_file"
    printf -- "- Variance          : %.9f\n" "$variance" | tee -a "$stat_file"
    printf -- "- Std dev           : %.6f (%.6f %%)\n" "$std_dev" "$relative_std_dev" | tee -a "$stat_file"
    printf -- "- Skewness          : %.6f\n" "$skewness" | tee -a "$stat_file"
    printf -- "- MAD (median)      : %.6f\n" "$mad" | tee -a "$stat_file"
    printf -- "- Outliers          : %s\n" "$outliers" | tee -a "$stat_file"
    printf -- "- Distribution      : ~ %s\n" "$apparent_distribution" | tee -a "$stat_file"
    # Based on https://www.statskingdom.com/150MeanT2uneq.html
    echo "Welch's T test" | tee -a "$stat_file"
    printf -- "- Degrees of freedom: %.6f\n" "$df" | tee -a "$stat_file"
    printf -- "- Test statistic T  : %.6f\n" "$welch_t_stat" | tee -a "$stat_file"
    printf -- "- Two tailed P-value: %.6f\n" "$welch_p_value" | tee -a "$stat_file"
    # Based on https://www.statskingdom.com/170median_mann_whitney.html
    echo "Wilcoxon U test" | tee -a "$stat_file"
    printf -- "- U1                : %.6f\n" "$wilcoxon_u1_value" | tee -a "$stat_file"
    printf -- "- U2                : %.6f\n" "$wilcoxon_u2_value" | tee -a "$stat_file"
    printf -- "- Test statistic Z  : %.6f\n" "$wilcoxon_z_stat" | tee -a "$stat_file"
    printf -- "- Two tailed P-value: %.6f\n" "$wilcoxon_p_value" | tee -a "$stat_file"
    printf -- "- Std effect size   : %.6f\n" "$effect_size_standardized" | tee -a "$stat_file"
    printf -- "- Common effect size: %.6f\n" "$effect_size_common" | tee -a "$stat_file"

    local memory_usage="$(echo "scale=3;${memory_result}/1024"|bc -l)"

    printf "%s\t%d\t%d\t%d\t%s\t%s\t%s\t%.5f\t%.5f\t%.5f\t%.5f\t%.5f\t%.2f\t%.5f\t%.2f\t%.3f\t%.3f\t%.3f\t%.2f\n" \
        "$TEST_NAME" "$TEST_WARMUP" "$TEST_ITERATIONS" "$TEST_REQUESTS" \
        "$PHP_NAME" "$commit_hash" "$url" \
        "$min" "$max" "$std_dev" "$relative_std_dev" "$mean" "$mean_diff" "$median" "$median_diff" "$skewness" "$wilcoxon_z_stat" "$wilcoxon_p_value" "$memory_usage" | tee -a "$result_file.tsv" "$final_result_file.tsv" > /dev/null

    printf "|[%s]($url)|%.5f|%.5f|%.5f|%.2f%%|%.5f|%.2f%%|%.5f|%.2f%%|%.3f|%.3f|%.3f|%.2f MB|\n" \
        "$PHP_NAME" "$min" "$max" "$std_dev" "$relative_std_dev" "$mean" "$mean_diff" "$median" "$median_diff" "$skewness" "$wilcoxon_z_stat" "$wilcoxon_p_value" "$memory_usage" >> "$result_file.md"
}

run_cgi () {
    local mode="$1"
    local warmup="$2"
    local requests="$3"
    local script="$4"
    local uri="$5"
    local env="$6"

    if git --git-dir="$php_source_path/.git" --work-tree="$php_source_path" merge-base --is-ancestor "7b4c14dc10167b65ce51371507d7b37b74252077" HEAD > /dev/null 2>&1; then
        opcache=""
    else
        opcache="-d zend_extension=$php_source_path/modules/opcache.so"
    fi

    declare -A php_env_vars=( \
        [CONTENT_TYPE]="'text/html; charset=utf-8'" \
        [REQUEST_URI]="$uri" \
        [HTTP_HOST]="localhost" \
        [SERVER_NAME]="localhost" \
        [SCRIPT_FILENAME]="$PROJECT_ROOT/$4" \
        [REQUEST_METHOD]="GET" \
        [REDIRECT_STATUS]="200" \
        [APP_ENV]="$env" \
        [APP_DEBUG]=false \
        [APP_SECRET]=random \
        [SESSION_DRIVER]=cookie \
        [SESSION_DOMAIN]="" \
        [CACHE_STORE]=null \
        [LOG_LEVEL]=INFO \
        [LOG_CHANNEL]=stderr \
        [DB_CONNECTION]=sqlite \
        [LOG_DEPRECATIONS_CHANNEL]=stderr \
        [LOG_DEPRECATIONS_TRACE]=true \
        [BROADCAST_DRIVER]=null \
        [USE_ZEND_ALLOC_HUGE_PAGES]=1 \
        [MALLOC_ARENA_MAX]=1 \
        [MALLOC_MMAP_THRESHOLD_]=131072 \
    )

    local php_env_var_list=()
    for key in "${!php_env_vars[@]}"; do
      php_env_var_list+=("$key=${php_env_vars[$key]}")
    done

    # TODO for jemalloc
    # export LD_PRELOAD=/usr/lib64/libjemalloc.so.2
    # export MALLOC_CONF="narenas:1,dirty_decay_ms:2000,muzzy_decay_ms:2000,background_thread:false"

    if [ "$mode" = "quiet" ]; then
        if [[ "$INFRA_LOCK_CPU_FREQUENCY" == "0" || "$INFRA_DISABLE_DEEPER_C_STATES" == "0" ]]; then
            sleep 0.25
        fi
        sudo cgexec -g cpuset:php \
            nice -n -20 ionice -c 1 -n 0 \
            sudo -u "$USER" \
            env -i -S "${php_env_var_list[*]}" \
            $php_source_path/sapi/cgi/php-cgi $opcache -T "$warmup,$requests" "$PROJECT_ROOT/$4" > /dev/null
    elif [ "$mode" = "verbose" ]; then
       sudo cgexec -g cpuset:php \
            nice -n -20 ionice -c 1 -n 0 \
            sudo -u "$USER" \
            env -i -S "${php_env_var_list[*]}" \
            $php_source_path/sapi/cgi/php-cgi $opcache -T "$warmup,$requests" "$PROJECT_ROOT/$4"
    elif [ "$mode" = "memory" ]; then
        sudo cgexec -g cpuset:php \
            nice -n -20 ionice -c 1 -n 0 \
            sudo -u "$USER" \
            env -i -S "${php_env_var_list[*]}" \
            /usr/bin/time -v $php_source_path/sapi/cgi/php-cgi $opcache -q -T "$warmup,$requests" "$PROJECT_ROOT/$4" > /dev/null
    elif [ "$mode" = "perf" ]; then
        sudo cgexec -g cpuset:php \
            nice -n -20 ionice -c 1 -n 0 \
            sudo -u "$USER" \
            env -i -S "${php_env_var_list[*]}" \
            perf stat -e instructions,cycles,branches,branch-misses,page-faults --repeat=5 \
            $php_source_path/sapi/cgi/php-cgi $opcache -q -T "$warmup,$requests" "$PROJECT_ROOT/$4" > /dev/null

        if [[ "$INFRA_COLLECT_EXTENDED_PERF_STATS" == "1" ]]; then
            sudo cgexec -g cpuset:php \
                nice -n -20 ionice -c 1 -n 0 \
                sudo -u "$USER" \
                env -i -S "${php_env_var_list[*]}" \
                perf stat -e LLC-loads,LLC-load-misses --repeat=5 \
                $php_source_path/sapi/cgi/php-cgi $opcache -q -T "$warmup,$requests" "$PROJECT_ROOT/$4" > /dev/null

            sudo cgexec -g cpuset:php \
                nice -n -20 ionice -c 1 -n 0 \
                sudo -u "$USER" \
                env -i -S "${php_env_var_list[*]}" \
                perf stat -e LLC-stores,LLC-store-misses --repeat=5 \
                $php_source_path/sapi/cgi/php-cgi $opcache -q -T "$warmup,$requests" "$PROJECT_ROOT/$4" > /dev/null

            sudo cgexec -g cpuset:php \
                nice -n -20 ionice -c 1 -n 0 \
                sudo -u "$USER" \
                env -i -S "${php_env_var_list[*]}" \
                perf stat -e iTLB-load-misses,dTLB-load-misses --repeat=5 \
                $php_source_path/sapi/cgi/php-cgi $opcache -q -T "$warmup,$requests" "$PROJECT_ROOT/$4" > /dev/null
        fi
    else
        echo "Invalid php-cgi run mode"
        exit 1
    fi
}

run_cli () {
    local mode="$1"
    local warmup="$2"
    local requests="$3"
    local script="$4"

    if git --git-dir="$php_source_path/.git" --work-tree="$php_source_path" merge-base --is-ancestor "7b4c14dc10167b65ce51371507d7b37b74252077" HEAD > /dev/null 2>&1; then
        opcache=""
    else
        opcache="-d zend_extension=$php_source_path/modules/opcache.so"
    fi

    declare -A php_env_vars=( \
        [USE_ZEND_ALLOC_HUGE_PAGES]=1 \
        [MALLOC_ARENA_MAX]=1 \
        [MALLOC_MMAP_THRESHOLD_]=131072 \
    )

    local php_env_var_list=()
    for key in "${!php_env_vars[@]}"; do
      php_env_var_list+=("$key=${php_env_vars[$key]}")
    done

    # TODO for jemalloc
    # export LD_PRELOAD=/usr/lib64/libjemalloc.so.2
    # export MALLOC_CONF="narenas:1,dirty_decay_ms:2000,muzzy_decay_ms:2000,background_thread:false"

    if [ "$mode" = "quiet" ]; then
        if [[ "$INFRA_LOCK_CPU_FREQUENCY" == "0" || "$INFRA_DISABLE_DEEPER_C_STATES" == "0" ]]; then
            sleep 0.5
        fi

        sudo cgexec -g cpuset:php \
            nice -n -20 ionice -c 1 -n 0 \
            sudo -u "$USER" \
            env -i -S "${php_env_var_list[*]}" \
            $php_source_path/sapi/cgi/php-cgi $opcache -T "$warmup,$requests" "$PROJECT_ROOT/$script" > /dev/null
    elif [ "$mode" = "verbose" ]; then
        sudo cgexec -g cpuset:php \
            nice -n -20 ionice -c 1 -n 0 \
            sudo -u "$USER" \
            env -i -S "${php_env_var_list[*]}" \
            $php_source_path/sapi/cgi/php-cgi $opcache -T "$warmup,$requests" "$PROJECT_ROOT/$script"
    elif [ "$mode" = "memory" ]; then
        sudo cgexec -g cpuset:php \
            nice -n -20 ionice -c 1 -n 0 \
            sudo -u "$USER" \
            env -i -S "${php_env_var_list[*]}" \
            /usr/bin/time -v \
            $php_source_path/sapi/cgi/php-cgi $opcache -T "$warmup,$requests" "$PROJECT_ROOT/$script" > /dev/null
    elif [ "$mode" = "perf" ]; then
        sudo cgexec -g cpuset:php \
            nice -n -20 ionice -c 1 -n 0 \
            sudo -u "$USER" \
            env -i -S "${php_env_var_list[*]}" \
            perf stat -e instructions,cycles,branches,branch-misses,page-faults --repeat=5 \
            $php_source_path/sapi/cgi/php-cgi $opcache -T "$warmup,$requests" "$PROJECT_ROOT/$script" > /dev/null

        if [[ "$INFRA_COLLECT_EXTENDED_PERF_STATS" == "1" ]]; then
            sudo cgexec -g cpuset:php \
                nice -n -20 ionice -c 1 -n 0 \
                sudo -u "$USER" \
                env -i -S "${php_env_var_list[*]}" \
                perf stat -e LLC-loads,LLC-load-misses --repeat=5 \
                $php_source_path/sapi/cgi/php-cgi $opcache -T "$warmup,$requests" "$PROJECT_ROOT/$script" > /dev/null

            sudo cgexec -g cpuset:php \
                nice -n -20 ionice -c 1 -n 0 \
                sudo -u "$USER" \
                env -i -S "${php_env_var_list[*]}" \
                perf stat -e LLC-stores,LLC-store-misses --repeat=5 \
                $php_source_path/sapi/cgi/php-cgi $opcache -T "$warmup,$requests" "$PROJECT_ROOT/$script" > /dev/null

            sudo cgexec -g cpuset:php \
                nice -n -20 ionice -c 1 -n 0 \
                sudo -u "$USER" \
                env -i -S "${php_env_var_list[*]}" \
                perf stat -e iTLB-load-misses,dTLB-load-misses --repeat=5 \
                $php_source_path/sapi/cgi/php-cgi $opcache -T "$warmup,$requests" "$PROJECT_ROOT/$script" > /dev/null
        fi
    else
        echo "Invalid php-cli run mode"
        exit 1
    fi
}

assert_test_output() {
    local expectation_file="$1"
    local actual_file="$2"

    $php_source_path/sapi/cli/php "$PROJECT_ROOT/app/zend/assert_output.php" "$expectation_file" "$actual_file"
}

format_memory_log_file() {
    local result="$(grep "Maximum resident set size" "$1")"
    echo "$result" > "$1"
    sed -i "s/	Maximum resident set size (kbytes): //g" "$1"
}

format_perf_log_file() {
    local stats_pattern="instructions|cycles|branches|branch-misses|page-faults|LLC-loads|LLC-load-misses|LLC-stores|LLC-store-misses|iTLB-load-misses|dTLB-load-misses|stalled-cycles-frontend|stalled-cycles-backend"
    local result="$(grep -E "$stats_pattern" "$1")"

    echo "$result" > "$1"
}

load_php_config () {
    source $PHP_CONFIG_FILE
    export PHP_CONFIG_FILE
    php_source_path="$PROJECT_ROOT/tmp/$PHP_ID"

    log_dir="$result_dir"
    log_file="$log_dir/${PHP_ID}.log"
    output_file="$log_dir/${PHP_ID}_output.txt"
    memory_log_file="$log_dir/${PHP_ID}_memory.log"
    perf_log_file="$log_dir/${PHP_ID}_perf.log"
    stat_file="$log_dir/${PHP_ID}_stat.log"
    environment_debug_log_file="$log_dir/${PHP_ID}_env_debug.log"
    mkdir -p "$log_dir"
}

collect_environment_metrics() {
    local cpu="$1"

    local v_context_switches n_context_switches \
        minor_page_faults major_page_faults \
        irqs soft_irqs run_queue_length \
        io_reads io_writes io_time

    # Context switches
    v_context_switches="$(sed -n 's/^voluntary_ctxt_switches:[[:space:]]*//p' /proc/self/status)"
    n_context_switches="$(sed -n 's/^nonvoluntary_ctxt_switches:[[:space:]]*//p' /proc/self/status)"

    # Page faults (minflt = column 10, majflt = column 12)
    read -r _ _ _ _ _ _ _ _ _ _ minor_page_faults _ major_page_faults _ < /proc/self/stat

    # IRQ for the given CPU
    irqs=0
    while read -r line; do
        set -- "$line"
        # first column is the IRQ name, then CPU0 CPU1 CPU2...
        # CPU colum index: cpu+2 (mert $1 = IRQ név)
        col="$((cpu + 2))"
        val="$(eval "echo \${$col}")"
        irqs="$((irqs + val))"
    done < <(tail -n +2 /proc/interrupts)

    # soft_irq
    soft_irqs=0
    while read -r line; do
        set -- $line
        local col=$((cpu + 2))
        local val=$(eval "echo \${$col}")
        soft_irqs="$((soft_irqs + val))"
    done < <(tail -n +2 /proc/softirqs)

    # run_queue length
    run_queue_length="$(cut -d ' ' -f1 /proc/loadavg)"

#    sudo nvme amzn stats /dev/nvme2n1 | head
#    Total Ops:
#      Read: 238
#      Write: 0
#    Total Bytes:
#      Read: 4426752
#      Write: 0
#    Total Time (us):
#      Read: 7958
#      Write: 0

    # I/O stats
    local io_line="$(grep " nvme0n1 " /proc/diskstats)"
    read -r _ _ _ io_reads _ _ _ io_writes _ _ _ _ io_time _ _ <<< "$io_line"

    echo "$v_context_switches" "$n_context_switches" \
        "$minor_page_faults" "$major_page_faults" \
        "$irqs" "$soft_irqs" "$run_queue_length" \
        "$io_reads" "$io_writes" "$io_time"
}

print_environment_metrics_diff () {
    local iteration="$1"

    local v_context_switches_diff="$(int_diff "${v_context_switches[1]}" "${v_context_switches[0]}")"
    local n_context_switches_diff="$(int_diff "${n_context_switches[1]}" "${n_context_switches[0]}")"
    local minor_page_faults_diff="$(int_diff "${minor_page_faults[1]}" "${minor_page_faults[0]}")"
    local major_page_faults_diff="$(int_diff "${major_page_faults[1]}" "${major_page_faults[0]}")"
    local irqs_diff="$(int_diff "${irqs[1]}" "${irqs[0]}")"
    local soft_irqs_diff="$(int_diff "${soft_irqs[1]}" "${soft_irqs[0]}")"
    local run_queue_length_diff="$(diff "${run_queue_length[1]}" "${run_queue_length[0]}")"
    local io_reads_diff="$(int_diff "${io_reads[1]}" "${io_reads[0]}")"
    local io_writes_diff="$(int_diff "${io_writes[1]}" "${io_writes[0]}")"
    local io_time_diff="$(int_diff "${io_time[1]}" "${io_time[0]}")"

    echo "-----------------------------------------------------------------"
    printf "Iteration: %-4d\tResult: #RESULT$iteration#\tDiff: #DIFF$iteration#\n" "$iteration"
    echo "-----------------------------------------------------------------"
    printf "Voluntary context switches    : %d\n" "$v_context_switches_diff"
    printf "Non-voluntary context switches: %d\n" "$n_context_switches_diff"
    printf "Minor page faults             : %d\n" "$minor_page_faults_diff"
    printf "Major page faults             : %d\n" "$major_page_faults_diff"
    printf "IRQs                          : %d\n" "$irqs_diff"
    printf "Soft IRQs                     : %d\n" "$soft_irqs_diff"
    printf "Run queue length              : %.3f\n" "$run_queue_length_diff"
    printf "I/O reads                     : %d\n" "$io_reads_diff"
    printf "I/O writes                    : %d\n" "$io_writes_diff"
    printf "I/O time (ms)                 : %d\n" "$io_time_diff"
}

postprocess_environment_debug_Log_file () {
    local environment_debug_log_file="$1"
    local log_file="$2"

    local results="$(cat "$log_file")"
    local results_arr=($results)
    local n="${#results_arr[@]}"
    local median="$(median "$results" "$n")"

    for k in "${!results_arr[@]}"; do
        local iteration="$(( k + 1 ))"
        local diff="$(printf "%+.6f" "$(diff "${results_arr[${k}]}" "$median")")"

        sed -i "s/#RESULT$iteration#/${results_arr[${k}]}/g" "$environment_debug_log_file"
        sed -i "s/#DIFF$iteration#/$diff/g" "$environment_debug_log_file"
   done
}

draw_diagram () {
    result_dir="$1"
    test_name="$2"
    plot_args="$3"

    gnuplot -persist <<EOF
    set terminal svg size 1600,850 fname "Arial" background "white"
    set output "$result_dir/result.svg"

    set title "Benchmark results for $test_name"
    set key outside bottom
    set xlabel "Iteration"
    set ylabel "Execution time (s)"
    set grid

    set datafile separator "\t"
    plot $plot_args
EOF
}

reset_original_file () {
    file="$1"

    if [[ -f "${file}.original" ]]; then
        mv -f "${file}.original" "$file"
    fi
}

reset_symfony () {
    # Update config based on PHP version
    reset_original_file "$PROJECT_ROOT/app/symfony/config/packages/doctrine.yaml"
    reset_original_file "$PROJECT_ROOT/app/symfony/vendor/symfony/var-exporter/ProxyHelper.php"
    reset_original_file "$PROJECT_ROOT/app/symfony/vendor/symfony/dependency-injection/LazyProxy/PhpDumper/LazyServiceDumper.php"

    if git --git-dir="$php_source_path/.git" --work-tree="$php_source_path" merge-base --is-ancestor "315fef2c72d172f4f81420e8f64ab2f3cd9e55b1" HEAD > /dev/null 2>&1; then
        sed -i.original "s/        enable_lazy_ghost_objects: true/        enable_lazy_ghost_objects: true\n        enable_native_lazy_objects: true/g" "$PROJECT_ROOT/app/symfony/config/packages/doctrine.yaml"
    else
        sed -i.original "s/if (\\\\PHP_VERSION_ID < 80400) {/if (\\\\PHP_VERSION_ID <= 80400) {/g" "$PROJECT_ROOT/app/symfony/vendor/symfony/var-exporter/ProxyHelper.php"
        sed -i.original "s/if (\\\\PHP_VERSION_ID < 80400) {/if (\\\\PHP_VERSION_ID <= 80400) {/g" "$PROJECT_ROOT/app/symfony/vendor/symfony/dependency-injection/LazyProxy/PhpDumper/LazyServiceDumper.php"
    fi

    # Regenerate cache
    if [[ -d "$PROJECT_ROOT/tmp/app/symfony/cache-$PHP_ID" ]]; then
        cp -rf "$PROJECT_ROOT/tmp/app/symfony/cache-$PHP_ID" "$PROJECT_ROOT/app/symfony/var/cache"
    else
        rm -rf "$PROJECT_ROOT/tmp/app/symfony/cache/prod/Container*"
        rm -rf "$PROJECT_ROOT/tmp/app/symfony/cache/prod/App_KernelProdContainer*"
        APP_ENV=prod APP_DEBUG=false APP_SECRET=random $php_source_path/sapi/cli/php "$PROJECT_ROOT/app/symfony/bin/console" "cache:warmup"

        cp -r "$PROJECT_ROOT/app/symfony/var/cache" "$PROJECT_ROOT/tmp/app/symfony/cache-$PHP_ID"
    fi
}

reset_apps () {
    case "$TEST_ID" in
        symfony_main_*)
            reset_symfony
            ;;

        symfony_blog_*)
            reset_symfony
            ;;
    esac
}

postprocess_results () {
    local plot_args=""
    local -a plot_colors=("#1f77b4" "#ff7f0e" "#2ca02c" "#d62728" "#9467bd" "#8c564b" "#e377c2" "#7f7f00" "#17becf" "#00008b" "#b8860b" "#000000")
    local plot_size="${#plot_colors[@]}"

    local i=0
    for PHP_CONFIG_FILE in $PROJECT_ROOT/config/php/*.ini; do
        load_php_config

        # Format benchmark log
        sed -i "/^[[:space:]]*$/d" "$log_file"
        sed -i "s/Elapsed time\: //g" "$log_file"
        sed -i "s/ sec//g" "$log_file"

        if [ "$INFRA_DEBUG_ENVIRONMENT" == "1" ]; then
            postprocess_environment_debug_Log_file "$environment_debug_log_file" "$log_file"
        fi

        if [[ -n "$plot_args" ]]; then
            plot_args="${plot_args}, "
        fi

        plot_color_num="$(( i % plot_size ))"
        plot_args="${plot_args}  \"$log_file\" using 1 with points lc rgb \"${plot_colors[plot_color_num]}\" pointtype 7 pointsize 1.5 title \"$PHP_NAME results\""
        i="$(( i + 1 ))"
    done

    draw_diagram "$result_dir" "$TEST_NAME" "$plot_args"
}

run_real_benchmark () {
    for PHP_CONFIG_FILE in $PROJECT_ROOT/config/php/*.ini; do
        load_php_config

        reset_apps

        echo "---------------------------------------------------------------------------------------"
        echo "$TEST_NAME PERF STATS - $RUN/$N - $INFRA_NAME - $PHP_NAME (JIT: $PHP_JIT)"
        echo "---------------------------------------------------------------------------------------"

        # Verifying output
        run_cgi "verbose" "0" "1" "$1" "$2" "$3" 2>&1 | tee -a "$output_file"
        if [ -n "$test_expectation_file" ]; then
            assert_test_output "$test_expectation_file" "$output_file"
        fi

        # Measuring memory usage
        run_cgi "memory" "$TEST_WARMUP" "$TEST_REQUESTS" "$1" "$2" "$3" 2>&1 | tee -a "$memory_log_file"

        # Gathering perf metrics
        run_cgi "perf" "$TEST_WARMUP" "$TEST_REQUESTS" "$1" "$2" "$3" 2>&1 | tee -a "$perf_log_file"
    done

    if [ "$INFRA_DEBUG_ENVIRONMENT" == "1" ]; then
        declare -a v_context_switches=(0 0)
        declare -a n_context_switches=(0 0)
        declare -a minor_page_faults=(0 0)
        declare -a major_page_faults=(0 0)
        declare -a irqs=(0 0)
        declare -a soft_irqs=(0 0)
        declare -a run_queue_length=(0 0)
        declare -a io_reads=(0 0)
        declare -a io_writes=(0 0)
        declare -a io_time=(0 0)
    fi

    $PROJECT_ROOT/bin/system/wait_for_cpu_temp.sh "$BENCH_PHP_CPU" "$INFRA_MAX_ALLOWED_CPU_TEMP" "$CPU_TEMP_TIMEOUT" "$CPU_TEMP_FALLBACK_SLEEP"

    # Benchmark
    for i in $(seq $TEST_ITERATIONS); do
        for PHP_CONFIG_FILE in $PROJECT_ROOT/config/php/*.ini; do
            load_php_config

            reset_apps

            cpu_temp="$($PROJECT_ROOT/bin/system/cpu_temp_pretty.sh "$BENCH_PHP_CPU")"
            echo "---------------------------------------------------------------------------------------"
            echo "$TEST_NAME BENCHMARK $i/$TEST_ITERATIONS - run $RUN/$N - $INFRA_NAME - $PHP_NAME (JIT: $PHP_JIT) - CPU: $cpu_temp"
            echo "---------------------------------------------------------------------------------------"

            # Debugging environment - initial state
            if [ "$INFRA_DEBUG_ENVIRONMENT" == "1" ]; then
                read -r "v_context_switches[0]" "n_context_switches[0]" \
                    "minor_page_faults[0]" "major_page_faults[0]" \
                    "irqs[0]" "soft_irqs[0]" "run_queue_length[0]" \
                    "io_reads[0]" "io_writes[0]" "io_time[0]" < <(collect_environment_metrics "$BENCH_PHP_CPU")
            fi

            run_cgi "quiet" "$TEST_WARMUP" "$TEST_REQUESTS" "$1" "$2" "$3" 2>&1 | tee -a "$log_file"

            # Debugging environment - final state
            if [ "$INFRA_DEBUG_ENVIRONMENT" == "1" ]; then
                read -r "v_context_switches[1]" "n_context_switches[1]" \
                    "minor_page_faults[1]" "major_page_faults[1]" \
                    "irqs[1]" "soft_irqs[1]" "run_queue_length[1]" \
                    "io_reads[1]" "io_writes[1]" "io_time[1]" < <(collect_environment_metrics "$BENCH_PHP_CPU")

                print_environment_metrics_diff "$i" | tee -a "$environment_debug_log_file"
            fi
        done
    done

    postprocess_results
}

run_micro_benchmark () {
    for PHP_CONFIG_FILE in $PROJECT_ROOT/config/php/*.ini; do
        load_php_config

        echo "---------------------------------------------------------------------------------------"
        echo "$TEST_NAME PERF STATS - $RUN/$N - $INFRA_NAME - $PHP_NAME (JIT: $PHP_JIT)"
        echo "---------------------------------------------------------------------------------------"

        # Verifying output
        run_cli "verbose" "0" "1" "$1" 2>&1 | tee -a "$output_file"
        if [ ! -z "$test_expectation_file" ]; then
            assert_test_output "$test_expectation_file" "$output_file"
        fi

        # Measuring memory usage
        run_cli "memory" "0" "$TEST_REQUESTS" "$1" 2>&1 | tee -a "$memory_log_file"

        # Gathering perf metrics
        run_cli "perf" "0" "$TEST_REQUESTS" "$1" 2>&1 | tee -a "$perf_log_file"
    done

    if [ "$INFRA_DEBUG_ENVIRONMENT" == "1" ]; then
        declare -a v_context_switches=(0 0)
        declare -a n_context_switches=(0 0)
        declare -a minor_page_faults=(0 0)
        declare -a major_page_faults=(0 0)
        declare -a irqs=(0 0)
        declare -a soft_irqs=(0 0)
        declare -a run_queue_length=(0 0)
        declare -a io_reads=(0 0)
        declare -a io_writes=(0 0)
        declare -a io_time=(0 0)
    fi

    $PROJECT_ROOT/bin/system/wait_for_cpu_temp.sh "$BENCH_PHP_CPU" "$INFRA_MAX_ALLOWED_CPU_TEMP" "$CPU_TEMP_TIMEOUT" "$CPU_TEMP_FALLBACK_SLEEP"

    # Benchmark
    for i in $(seq $TEST_ITERATIONS); do
        for PHP_CONFIG_FILE in $PROJECT_ROOT/config/php/*.ini; do
            load_php_config

            cpu_temp="$($PROJECT_ROOT/bin/system/cpu_temp_pretty.sh "$BENCH_PHP_CPU")"
            echo "---------------------------------------------------------------------------------------"
            echo "$TEST_NAME BENCHMARK $i/$TEST_ITERATIONS - run $RUN/$N - $INFRA_NAME - $PHP_NAME (JIT: $PHP_JIT) - CPU: $cpu_temp"
            echo "---------------------------------------------------------------------------------------"

            # Debugging environment - initial state
            if [ "$INFRA_DEBUG_ENVIRONMENT" == "1" ]; then
                read -r "v_context_switches[0]" "n_context_switches[0]" \
                    "minor_page_faults[0]" "major_page_faults[0]" \
                    "irqs[0]" "soft_irqs[0]" "run_queue_length[0]" \
                    "io_reads[0]" "io_writes[0]" "io_time[0]" < <(collect_environment_metrics "$BENCH_PHP_CPU")
            fi

            run_cli "quiet" "$TEST_WARMUP" "$TEST_REQUESTS" "$1" 2>&1 | tee -a "$log_file"

            # Debugging environment - final state
            if [ "$INFRA_DEBUG_ENVIRONMENT" == "1" ]; then
                read -r "v_context_switches[1]" "n_context_switches[1]" \
                    "minor_page_faults[1]" "major_page_faults[1]" \
                    "irqs[1]" "soft_irqs[1]" "run_queue_length[1]" \
                    "io_reads[1]" "io_writes[1]" "io_time[1]" < <(collect_environment_metrics "$BENCH_PHP_CPU")

                print_environment_metrics_diff "$i" | tee -a "$environment_debug_log_file"
            fi
        done
    done

    postprocess_results
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

    first_log_file=""
    first_results=""
    first_n=""
    first_mean=""
    first_median=""
    first_var=""

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

        format_perf_log_file "$perf_log_file"

        format_memory_log_file "$memory_log_file"

        print_result_value "$log_file" "$memory_log_file" "$perf_log_file" "$result_file" "$final_result_file" "$stat_file"
    done

    echo "" >> "$final_result_file.md"
    cat "$result_file.md" >> "$final_result_file.md"
}

CPU_TEMP_TIMEOUT=240
CPU_TEMP_FALLBACK_SLEEP=10

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

function run_benchmarks () {
    TEST_NUMBER=0
    for test_config in $PROJECT_ROOT/config/test/*.ini; do
        source $test_config
        ((TEST_NUMBER=TEST_NUMBER+1))

        if [[ "$TEST_ID" =~ ^wordpress_.*$ ]]; then
            sudo systemctl start containerd.service
            sudo service docker start

            db_container_id="$(docker ps -aqf "name=wordpress_db")"
            sudo cgexec -g cpuset:mysql \
                docker start "$db_container_id"

            $PROJECT_ROOT/build/script/wait_for_mysql.sh "wordpress_db" "wordpress" "wordpress" "wordpress" "60"
        fi

        run_benchmark

        if [[ "$TEST_ID" =~ ^wordpress_.*$ ]]; then
            sudo service docker stop
            sudo systemctl stop containerd.service
        fi
    done
}

run_benchmarks
