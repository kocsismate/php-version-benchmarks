#!/usr/bin/env bash
set -e

if [[ "$1" == "$INFRA_ENVIRONMENT" && "$INFRA_ENVIRONMENT" != "local" ]]; then
    sudo service docker start &
    $PROJECT_ROOT/build/script/php_deps.sh &
fi

for php_config in $PROJECT_ROOT/config/php/*.ini; do
    source "$php_config"
    export $(cut -d= -f1 $php_config)
    export PHP_SOURCE_PATH="$PROJECT_ROOT/tmp/$PHP_ID"

    if [ -z "$PHP_BASE_ID" ]; then
        export PHP_BASE_SOURCE_PATH=""
    else
        export PHP_BASE_SOURCE_PATH="$PROJECT_ROOT/tmp/$PHP_BASE_ID"
    fi

    echo "Checking out source for $PHP_NAME..."

    if [ -z "$PHP_BASE_ID" ]; then
        $PROJECT_ROOT/build/script/php_source.sh "$1" &
    else
        wait
        $PROJECT_ROOT/build/script/php_source.sh "$1"
    fi
done

wait

if [[ "$1" == "$INFRA_ENVIRONMENT" ]]; then
    cpu_count="$(nproc)"
    php_ini_count="$( set -- $PROJECT_ROOT/config/php/*.ini; [ -e "$1" ] && echo $# || echo 0)"
    cpu_per_php="$((cpu_count / php_ini_count))"

    echo "Setting up compilation..."
    echo "CPU count: $cpu_count"
    echo "php.ini count: $php_ini_count"
    echo "CPU per php.ini count: $cpu_per_php"

    for php_config in $PROJECT_ROOT/config/php/*.ini; do
        source "$php_config"
        export $(cut -d= -f1 $php_config)
        export PHP_SOURCE_PATH="$PROJECT_ROOT/tmp/$PHP_ID"
        if [ -z "$PHP_BASE_ID" ]; then
            export PHP_BASE_SOURCE_PATH=""
        else
            export PHP_BASE_SOURCE_PATH="$PROJECT_ROOT/tmp/$PHP_BASE_ID"
        fi

        echo "Compiling $PHP_NAME..."

        $PROJECT_ROOT/build/script/php_compile.sh "$cpu_per_php" &
    done

    wait
fi
