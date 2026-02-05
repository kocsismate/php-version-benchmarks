#!/usr/bin/env bash
set -e

cpu="$1"

temp="$($PROJECT_ROOT/bin/system/cpu_temp.sh "$cpu")"
if [[ "$temp" == "" ]]; then
    echo "N/A"
else
    echo "$temp °C"
fi
