#!/usr/bin/env bash
set -e

disable_cpu_turbo_boost () {
    if [[ "$INFRA_DISABLE_TURBO_BOOST" == "1" ]]; then
        echo "Disabling turbo boost"
        sudo sh -c 'echo 1 > /sys/devices/system/cpu/intel_pstate/no_turbo'
    else
        echo "Skipped disabling turbo boost"
    fi
}

verify_cpu_turbo_boost () {
    if [[ "$INFRA_DISABLE_TURBO_BOOST" == "1" ]]; then
        # Path to the Turbo Boost control file
        local turbo_file="/sys/devices/system/cpu/intel_pstate/no_turbo"

        if [[ ! -f "$turbo_file" ]]; then
          echo "Error: Turbo boost is enabled"
          exit 1
        fi

        local turbo_status="$(cat "$turbo_file")"

        if [[ "$turbo_status" != "1" ]]; then
          echo "Error: Turbo boost is enabled"
          exit 1
        fi

       echo "OK: Turbo boost is disabled."
    fi
}

subcommand="$1"

case "$subcommand" in
    "disable")
        disable_cpu_turbo_boost
        ;;

    "verify")
        verify_cpu_turbo_boost
        ;;

    *)
        echo "Invalid subcommand $subcommand"
        exit 1
esac
