#!/usr/bin/env bash
set -e

cpu="$1"
max_allowed_cpu_temp="$2"
timeout="$3"
fallback_sleep="$4"

function get_cpu_temp_zone () {
    local cpu="$1"
    local package_id="$(cat "/sys/devices/system/cpu/cpu${cpu}/topology/physical_package_id")"

    for zone in /sys/class/thermal/thermal_zone*; do
        if [[ -f "$zone/package_id" ]]; then
            if [[ "$(cat "$zone/package_id")" == "$package_id" ]]; then
                basename "$zone"
                return
            fi
        fi
    done

    echo "thermal_zone${package_id}"
}

function get_cpu_temp () {
    local cpu="$1"
    local zone="$(get_cpu_temp_zone "$cpu")"

    if [[ -f "/sys/class/thermal/$zone/temp" ]]; then
        echo "scale=0; $(cat "/sys/class/thermal/$zone/temp") / 1000" | bc
    else
        echo ""
    fi
}

if [[ "$max_allowed_cpu_temp" == "0" ]]; then
    exit 0
fi

start_time="$(date +%s)"

while true; do
    current_cpu_temp="$(get_cpu_temp "$cpu")"
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
