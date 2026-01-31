#!/usr/bin/env bash
set -e

max_allowed_cpu_temp="$1"
timeout="$2"
fallback_sleep="$3"

function get_cpu_temp () {
    if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
        echo "scale=0; $(cat /sys/class/thermal/thermal_zone0/temp) / 1000" | bc
    else
        echo ""
    fi
}

if [[ "$max_allowed_cpu_temp" == "0" ]]; then
    exit 0
fi

start_time="$(date +%s)"

while true; do
    current_cpu_temp="$(get_cpu_temp)"
    if [[ "$current_cpu_temp" == "" ]]; then
        echo "CPU temperature sensor is not available, waiting for $fallback_sleep seconds instead"
        sleep "$fallback_sleep"
        break
    else
        echo "Waiting for CPU temperature ($current_cpu_temp °C) to drop below $max_allowed_cpu_temp °C..."
    fi

    now="$(date +%s)"

    if [[ "$current_cpu_temp" -lt "$max_allowed_cpu_temp" ]]; then
        echo "CPU temperature is ready in $(( now - start_time )) seconds"
        break
    fi

    if (( now - start_time > timeout )); then
        echo "CPU temperature didn't drop below $max_allowed_cpu_temp within $timeout seconds"
        exit 1
    fi

    sleep 1
done
