#!/usr/bin/env bash
set -e

first_cpu_from_list () {
    local cpu_list="$1"

    echo "$cpu_list" | sed 's/-.*//' | sed 's/,.*//'
}

last_cpu_from_list () {
    local cpu_list="$1"

    echo "$cpu_list" | sed 's/.*-//' | sed 's/.*,//'
}

parse_cpu_list () {
    local input="$1"
    local -a result=()

    IFS=',' read -ra parts <<< "$input"

    for part in "${parts[@]}"; do
        if [[ "$part" == *-* ]]; then
            local start="${part%-*}"
            local end="${part#*-}"

            for ((i=start; i<=end; i++)); do
                result+=("$i")
            done
        else
            result+=("$part")
        fi
    done

    printf "%s\n" "${result[@]}" | sort -n  | xargs
}
