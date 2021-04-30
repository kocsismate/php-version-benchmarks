#!/usr/bin/env bash
set -e

export PROJECT_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [[ "$1" == "run" ]]; then

    export N="${3:-1}"
    export NOW="$(date +'%Y_%m_%d_%H_%M')"

    source $PROJECT_ROOT/.env
    export $(cut -d= -f1 $PROJECT_ROOT/.env)

    if [[ "$2" == "local-docker" ]]; then
        $PROJECT_ROOT/bin/setup.sh "$2"
    fi

    for config in $PROJECT_ROOT/config/*.ini; do
        source "$config"
        if [[ "$ENABLED" == "0" ]]; then
            continue
        fi
        export $(cut -d= -f1 $config)

        $PROJECT_ROOT/bin/build.sh "$2"
    done

    for r in $(seq "$N"); do

        export RUN="$r"

        for config in $PROJECT_ROOT/config/*.ini; do
            source "$config"
            if [[ "$ENABLED" == "0" ]]; then
                continue
            fi

            export $(cut -d= -f1 $config)
            export CONFIG_FILE=$config
            export GIT_PATH=$PROJECT_ROOT/tmp/$NAME

            echo "---------------------------------------------------------------------------------------"
            echo "$r/$N - $NAME (opcache: $PHP_OPCACHE, preloading: $PHP_PRELOADING, JIT: $PHP_JIT)"
            echo "---------------------------------------------------------------------------------------"

            if [[ "$2" == "local-docker" ]]; then
                $PROJECT_ROOT/build/script/php_source.sh "$2"
                $PROJECT_ROOT/bin/benchmark.sh "$2"
            elif [[ "$2" == "aws-docker" ]]; then
                $PROJECT_ROOT/bin/terraform.sh "$3"
            fi
        done
    done

elif [[ "$1" == "help" ]]; then

    echo "Usage: ./benchmark.sh run [runner]"
    echo ""
    echo "Available runners: local-docker, aws-docker"

else

    echo 'Available options: "run"!'
    exit 1

fi
