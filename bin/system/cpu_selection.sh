#!/usr/bin/env bash
set -e

source "$PROJECT_ROOT/bin/system/lib.sh"

get_target_cpu_list () {
    local target_numa="$1"

    local online_cpus_raw="$(cat "/sys/devices/system/cpu/online")"

    if [[ -z "$target_numa" ]]; then
        echo "$online_cpus_raw"
        return 0
    fi

    local -a online_list=($(parse_cpu_list "$online_cpus_raw"))
    local online_comma_list=",$(IFS=','; echo "${online_list[*]}"),"

    local numa_cpus_raw="$(cat "/sys/devices/system/node/node$target_numa/cpulist")"
    local -a numa_list=($(parse_cpu_list "$numa_cpus_raw"))

    local -a intersection=()
    for cpu in "${numa_list[@]}"; do
        if [[ "$online_comma_list" == *",$cpu,"* ]]; then
            intersection+=("$cpu")
        fi
    done

    echo "${intersection[*]}"
}

select_cpus () {
    local target_numa="$1"

    $PROJECT_ROOT/bin/system/cpu_hyper_threading.sh "disable"

    local cpu_count="$(nproc)"
    if [[ "$cpu_count" -lt "4" ]]; then
        echo "At least 4 physical CPU cores are required to run the benchmark ($cpu_count is used)"
        exit 1
    fi

    $PROJECT_ROOT/bin/system/cpu_irq_affinity.sh "dedicate"

    echo "Selecting CPUs for benchmarking..."

    local target_cpu_list="$(get_target_cpu_list "$target_numa")"
    local irq_loads="$($PROJECT_ROOT/bin/system/cpu_irq_affinity.sh "analyze_load" "$target_cpu_list")"

    echo "Target CPU list:"
    echo "$target_cpu_list"

    echo "IRQ load per CPU:"
    echo "$irq_loads"

    # Removing CPU 0 from the targets as it is a special core
    irq_loads="$(echo "$irq_loads" | sed "/^0 /d")"

    # The core with the least IRQs is selected for PHP
    local php_cpu="$(echo "$irq_loads" | sed -n "1p" | cut -d ' ' -f1)"

    # The core with the second least IRQs is selected for MySQL
    local mysql_cpu="$(echo "$irq_loads" | sed -n "2p" | cut -d' ' -f1)"

    echo "CPU core count: $cpu_count"
    echo "PHP is assigned to CPU core $php_cpu"
    echo "MySQL is assigned to CPU core $mysql_cpu"

    echo "export BENCH_CPU_COUNT=$cpu_count" >> "$DOT_ENV_FILE"
    echo "export BENCH_PHP_CPU=$php_cpu" >> "$DOT_ENV_FILE"
    echo "export BENCH_MYSQL_CPU=$mysql_cpu" >> "$DOT_ENV_FILE"
}

subcommand="$1"

case "$subcommand" in
    "select")
        target_numa="$2"
        select_cpus "$target_numa"
        ;;

    *)
        echo "Invalid subcommand $subcommand"
        exit 1
esac
