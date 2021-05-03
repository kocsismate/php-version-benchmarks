#!/usr/bin/env bash
set -e

export PROJECT_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [[ "$1" == "run" ]]; then

    if [[ "$2" == "local" ]]; then
        INFRA_ENVIRONMENT="local"
    elif [[ "$2" == "aws" ]]; then
        INFRA_ENVIRONMENT="aws"
    else
        echo "Available environments: local, aws"
        exit 1
    fi

    export N="${3:-1}"
    NOW="$(date +'%Y-%m-%d %H:%M')"
    export NOW

    RESULT_ROOT_DIR="${NOW//-/_}"
    RESULT_ROOT_DIR="${RESULT_ROOT_DIR// /_}"
    RESULT_ROOT_DIR="${RESULT_ROOT_DIR//:/_}"
    export RESULT_ROOT_DIR
    export INFRA_ENVIRONMENT

    for infra_config in $PROJECT_ROOT/config/infra/$INFRA_ENVIRONMENT/*.ini; do
        source "$infra_config"
        export $(cut -d= -f1 $infra_config)

        for php_config in $PROJECT_ROOT/config/php/*.ini; do
            source "$php_config"
            export $(cut -d= -f1 $php_config)
            export PHP_SOURCE_PATH="$PROJECT_ROOT/tmp/$PHP_ID"

            $PROJECT_ROOT/build/script/php_source.sh
            $PROJECT_ROOT/bin/build.sh
        done
    done

    if [[ "$INFRA_ENVIRONMENT" == "local" ]]; then
        $PROJECT_ROOT/bin/setup.sh
    fi

    for RUN in $(seq "$N"); do
        export RUN

        for infra_config in $PROJECT_ROOT/config/infra/$INFRA_ENVIRONMENT/*.ini; do
            source "$infra_config"
            export $(cut -d= -f1 $infra_config)

            $PROJECT_ROOT/bin/provision.sh
        done
    done

elif [[ "$1" == "help" ]]; then

    echo "Usage: ./benchmark.sh run [runner] [runs]"
    echo ""
    echo "Available runners: local-docker, aws-docker, aws-host"

else

    echo 'Available options: "run", "help"!'
    exit 1

fi
