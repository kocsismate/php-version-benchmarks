#!/usr/bin/env bash
set -e

export LC_ALL=C
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

    infra_count="$(ls 2>/dev/null -Ubad1 -- $PROJECT_ROOT/config/infra/$INFRA_ENVIRONMENT/*.ini | wc -l)"
    infra_count="$(echo "$infra_count" | awk '{$1=$1;print}')"
    if [ "$infra_count" -eq "0" ]; then
        echo "The ./config/infra/$INFRA_ENVIRONMENT directory should contain at least one .ini file in order to be able to run the benchmark"
        exit 1
    fi

    php_count="$(ls 2>/dev/null -Ubad1 -- $PROJECT_ROOT/config/php/*.ini | wc -l)"
    php_count="$(echo "$php_count" | awk '{$1=$1;print}')"
    if [ "$php_count" -eq "0" ]; then
        echo "The ./config/php directory should contain at least one .ini file in order to be able to run the benchmark"
        exit 1
    fi

    test_count="$(ls 2>/dev/null -Ubad1 -- $PROJECT_ROOT/config/test/*.ini | wc -l)"
    test_count="$(echo "$test_count" | awk '{$1=$1;print}')"
    if [ "$test_count" -eq "0" ]; then
        echo "The ./config/test directory should contain at least one .ini file in order to be able to run the benchmark"
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
