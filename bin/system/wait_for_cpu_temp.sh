#!/usr/bin/env bash
set -e

cpu="$1"
max_allowed_cpu_temp="$2"
timeout="$3"
fallback_sleep="$4"

if [[ "$max_allowed_cpu_temp" == "0" ]]; then
    exit 0
fi

start_time="$(date +%s)"

while true; do
    current_cpu_temp="$($PROJECT_ROOT/bin/system/cpu_temp.sh "$cpu")"
    if [[ "$current_cpu_temp" == "" ]]; then
        echo "CPU temperature sensor is not available, waiting for $fallback_sleep seconds instead"
        sleep "$fallback_sleep"
        break
    else
        echo "Waiting for CPU $cpu temperature ($current_cpu_temp °C) to drop below $max_allowed_cpu_temp °C..."
    fi

    now="$(date +%s)"

    if [[ "$current_cpu_temp" -lt "$max_allowed_cpu_temp" ]]; then
        echo "CPU $cpu temperature is ready in $(( now - start_time )) seconds"
        break
    fi

    if (( now - start_time > timeout )); then
        echo "CPU $cpu temperature didn't drop below $max_allowed_cpu_temp within $timeout seconds"
        exit 1
    fi

    sleep 1
done
