#!/usr/bin/env bash
set -e

source "$PROJECT_ROOT/bin/system/lib.sh"

isolate_cpu () {
    local cpu_list="$1"

    echo "isolcpus=$cpu_list nohz_full=$cpu_list rcu_nocbs=$cpu_list"
}

verify_cpu_isolation () {
    local cpu_list="$1"
    local parsed_cpu_list="$(parse_cpu_list "$cpu_list")"

    local isolated_cpu_cores="$(cat /sys/devices/system/cpu/isolated)"
    local parsed_isolated_cpu_cores="$(parse_cpu_list "$isolated_cpu_cores")"
    if [[ "$parsed_cpu_list" != "$parsed_isolated_cpu_cores" ]]; then
        echo "Error: CPU isolation error (\"$parsed_cpu_list\" doesn't match \"$parsed_isolated_cpu_cores\")"
        exit 1
    fi

    local no_hz_cpu_cores="$(cat /sys/devices/system/cpu/nohz_full)"
    local parsed_no_hz_cpu_cores="$(parse_cpu_list "$no_hz_cpu_cores")"
    if [[ "$parsed_cpu_list" != "$parsed_no_hz_cpu_cores" ]]; then
        echo "Error: CPU NO HZ isolation error ($parsed_cpu_list doesn't match $parsed_no_hz_cpu_cores)"
        exit 1
    fi

    echo "OK: CPU isolation is correct"
}

subcommand="$1"
cpu_list="$2"

case "$subcommand" in
    "isolate")
        isolate_cpu "$cpu_list"
        ;;

    "verify")
        verify_cpu_isolation "$cpu_list"
        ;;

    *)
        echo "Invalid subcommand $subcommand"
        exit 1
esac
