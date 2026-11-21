#!/usr/bin/env bash
set -e

mkdir -p "$PROJECT_ROOT/tmp/app"

sudo docker build --quiet -t setup "$PROJECT_ROOT/app"

install_pids=()

for test_config in $PROJECT_ROOT/config/test/*.ini; do
    source "$test_config"

    install_script="${test_config//.ini/_install.sh}"
    if [[ -f "$install_script" ]]; then
        "$install_script" &
        install_pids+=("$!")
    fi
done

install_status=0
for pid in "${install_pids[@]}"; do
    wait "$pid" || install_status=$?
done

exit "$install_status"
