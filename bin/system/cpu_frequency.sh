#!/usr/bin/env bash
set -e

lock_cpu_frequency () {
    if [[ "$INFRA_LOCK_CPU_FREQUENCY" == "1" ]]; then
        cpu_base_frequency_khz="$(cat /sys/devices/system/cpu/cpu0/cpufreq/base_frequency)"
        cpu_base_frequency_mhz="$(( cpu_base_frequency_khz / 1000 ))"

        echo "Locking CPU frequency to $cpu_base_frequency_mhz MHz"
        sudo cpupower frequency-set --min "${cpu_base_frequency_mhz}MHz" --max "${cpu_base_frequency_mhz}MHz" -g performance

        echo "performance" | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference > /dev/null || true
    else
        echo "Skipped locking CPU frequency"
    fi
}

verify_cpu_frequency () {
    cpupower frequency-info
    if [[ "$INFRA_LOCK_CPU_FREQUENCY" == "1" ]]; then
        local info="$(cpupower frequency-info)"

        if echo "$info" | grep -q "The governor \"performance\""; then
            echo "OK: CPU governor is performance"
        else
            echo "Error: CPU governor isn't performance!"
            exit 1
        fi

        local policy_line="$(echo "$info" | grep "current policy:" || true)"
        if [ -z "$policy_line" ]; then
            echo "Error: No CPU governor policy is available"
            exit 1
        fi

        local cpu_min_frequency="$(echo "$policy_line" | sed -E 's/.*within (.*) and .*/\1/' | xargs)"
        local cpu_max_frequency="$(echo "$policy_line" | sed -E 's/.*and (.*)\./\1/' | xargs)"

        if [ "$cpu_min_frequency" == "$cpu_max_frequency" ]; then
            echo "OK: Minimum and maximum frequency are correct ($cpu_max_frequency)"
        else
            echo "Error: Minimum and maximum CPU frequency differ ($cpu_min_frequency and $cpu_max_frequency)"
            exit 1
        fi
    fi
}

subcommand="$1"

case "$subcommand" in
    "lock")
        lock_cpu_frequency
        ;;

    "verify")
        verify_cpu_frequency
        ;;

    *)
        echo "Invalid subcommand $subcommand"
        exit 1
esac
