#!/usr/bin/env bash
set -e

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

function cpu_temp () {
    local cpu="$1"
    local zone="$(get_cpu_temp_zone "$cpu")"

    if [[ -f "/sys/class/thermal/$zone/temp" ]]; then
        echo "scale=0; $(cat "/sys/class/thermal/$zone/temp") / 1000" | bc
    else
        echo ""
    fi
}

cpu="$1"

cpu_temp "$cpu"
