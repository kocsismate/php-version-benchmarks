#!/usr/bin/env bash
set -e

isolate_cpu () {
    local cpu_list="$1"

    echo "isolcpus=$cpu_list nohz_full=$cpu_list rcu_nocbs=$cpu_list"
}

verify_cpu_isolation () {
    local cpu_list="$1"

    local isolated_cpu_cores="$(cat /sys/devices/system/cpu/isolated)"
    if [[ "$isolated_cpu_cores" != "$cpu_list" ]]; then
        echo "Error: CPU isolation error ($isolated_cpu_cores)"
        exit 1
    fi

    local no_hz_cpu_cores="$(cat /sys/devices/system/cpu/nohz_full)"
    if [[ "$no_hz_cpu_cores" != "$cpu_list" ]]; then
        echo "Error: CPU NO HZ isolation error ($no_hz_cpu_cores)"
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
