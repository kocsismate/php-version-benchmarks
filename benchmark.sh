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

    DRY_RUN="0";
    if [[ "$4" == "dry-run" ]]; then
        DRY_RUN="1"
    fi
    export DRY_RUN

    RESULT_ROOT_DIR="${NOW//-/_}"
    RESULT_ROOT_DIR="${RESULT_ROOT_DIR// /_}"
    RESULT_ROOT_DIR="${RESULT_ROOT_DIR//:/_}"
    export RESULT_ROOT_DIR
    export INFRA_ENVIRONMENT

    for infra_config in $PROJECT_ROOT/config/infra/$INFRA_ENVIRONMENT/*.ini; do
        source "$infra_config"
        export $(cut -d= -f1 $infra_config)

        for php_config in $PROJECT_ROOT/config/php/*.ini; do
            $PROJECT_ROOT/bin/build.sh "local"
        done
    done

    for php_config in $PROJECT_ROOT/config/php/*.ini; do
        source "$php_config"
        if [ -z "$PHP_BASE_ID" ]; then
            export PHP_SOURCE_PATH="$PROJECT_ROOT/tmp/$PHP_ID"
        else
            export PHP_SOURCE_PATH="$PROJECT_ROOT/tmp/$PHP_BASE_ID"
        fi

        export "PHP_COMMITS_$PHP_ID=$(git -C "$PHP_SOURCE_PATH" rev-parse HEAD)"
    done

    ls ./config/test/*.ini > /dev/null # Exit early if no tests are available, ref `set -e`

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

    if [[ "$DRY_RUN" -eq "0" ]]; then
        $PROJECT_ROOT/bin/generate_results.sh "$PROJECT_ROOT/tmp/results/$RESULT_ROOT_DIR" "$PROJECT_ROOT/docs/results/$RESULT_ROOT_DIR"
    fi

elif [[ "$1" == "help" ]]; then

    echo "Usage: ./benchmark.sh run [environment] [runs] [dry-run]"
    echo ""
    echo "Available runners: local, aws"

else

    echo 'Available options: "run", "help"!'
    exit 1

fi
