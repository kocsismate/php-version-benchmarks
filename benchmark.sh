#!/usr/bin/env bash
set -e

export PROJECT_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [[ "$1" == "run" ]]; then

    export N="${3:-1}"
    export NOW="$(date +'%Y_%m_%d_%H_%M')"

    for i in $(seq "$N"); do

        export RUN="$i"

        if [[ "$2" == "local-docker" ]]; then
            source $PROJECT_ROOT/.env
            export $(cut -d= -f1 $PROJECT_ROOT/.env)

            $PROJECT_ROOT/bin/setup.sh "$2"

            for config in $PROJECT_ROOT/config/*.ini; do
                source "$config"
                if [[ "$ENABLED" == "0" ]]; then
                    continue
                fi

                export $(cut -d= -f1 $config)
                export CONFIG_FILE=$config
                export GIT_PATH=$PROJECT_ROOT/tmp/$NAME

                echo "---------------------------------------------------------------------------------------"
                echo "Current benchmark: $NAME (opcache: $PHP_OPCACHE, preloading: $PHP_PRELOADING, JIT: $PHP_JIT)"
                echo "---------------------------------------------------------------------------------------"

                $PROJECT_ROOT/bin/provision.sh "$2"
                $PROJECT_ROOT/bin/benchmark.sh "$2"
                $PROJECT_ROOT/bin/deprovision.sh "$2"
            done

        elif [[ "$2" == "aws-docker" ]]; then
            $PROJECT_ROOT/bin/terraform.sh "$3"
        fi

    done

elif [[ "$1" == "help" ]]; then

    echo "Usage: ./benchmark.sh run [runner]"
    echo ""
    echo "Available runners: local-docker, aws-docker"

else

    echo 'Available options: "run"!'
    exit 1

fi
