#!/usr/bin/env bash
set -e

mkdir -p "$PROJECT_ROOT/tmp/app"

sudo docker build -t setup "$PROJECT_ROOT/app"

for test_config in $PROJECT_ROOT/config/test/*.ini; do
    source $test_config

    install_script="${test_config//.ini/_install.sh}"
    if [[ -f "$install_script" ]]; then
        "$install_script" &
    fi
done

wait
