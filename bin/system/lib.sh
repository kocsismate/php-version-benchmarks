#!/usr/bin/env bash
set -e

first_cpu_from_list () {
    local cpu_list="$1"

    echo "$cpu_list" | sed 's/-.*//' | sed 's/,.*//'
}
