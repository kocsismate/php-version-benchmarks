#!/usr/bin/env bash
set -e

export PROJECT_ROOT=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

if [[ "$1" == "run" ]]; then

    $PROJECT_ROOT/bin/setup.sh "$2"
    source $PROJECT_ROOT/.env
    export $(cut -d= -f1 $PROJECT_ROOT/.env)

    for config in $PROJECT_ROOT/config/*.ini; do
        export CONFIG_FILE=$config
        source "$config"

        export $(cut -d= -f1 $config)
        export GIT_PATH=$PROJECT_ROOT/tmp/$NAME

        echo "---------------------------------------------------------------------------------------"
        echo "Current benchmark: $NAME (opcache: $PHP_OPCACHE, preloading: $PHP_PRELOADING, JIT: $PHP_JIT)"
        echo "---------------------------------------------------------------------------------------"

        $PROJECT_ROOT/bin/provision.sh "$2"
        $PROJECT_ROOT/bin/benchmark.sh "$2"
        $PROJECT_ROOT/bin/deprovision.sh "$2"
    done

elif [[ "$1" == "aws" ]]; then

    echo ""

else

    echo 'Available options: "run"!'
    exit 1

fi
