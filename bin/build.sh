#!/usr/bin/env bash
set -e

if [[ "$1" == "$INFRA_ENVIRONMENT" && "$INFRA_ENVIRONMENT" != "local" ]]; then
    sudo service docker start &
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

if [[ "$1" == "$INFRA_ENVIRONMENT" ]]; then
    echo "Checking out apps..."
    $PROJECT_ROOT/bin/setup.sh
fi

wait

if [[ "$1" == "$INFRA_ENVIRONMENT" ]]; then

    echo "Default linker file:"
    ld --verbose

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

    for php_config in $PROJECT_ROOT/config/php/*.ini; do
        source "$php_config"
        export $(cut -d= -f1 $php_config)
        export PHP_SOURCE_PATH="$PROJECT_ROOT/tmp/$PHP_ID"

        echo "Verifying compilation of $PHP_NAME..."

        if [ ! -f "$PHP_SOURCE_PATH/sapi/cli/php" ]; then
            echo "Failed to compile PHP"
            cat "$PHP_SOURCE_PATH/config.log" || true
            exit 1;
        fi

        if git --git-dir="$PHP_SOURCE_PATH/.git" --work-tree="$PHP_SOURCE_PATH" merge-base --is-ancestor "7b4c14dc10167b65ce51371507d7b37b74252077" HEAD > /dev/null 2>&1; then
            opcache=""
        else
            opcache="-d zend_extension=$PHP_SOURCE_PATH/modules/opcache.so"
        fi

        php_cli_executable="$PHP_SOURCE_PATH/sapi/cli/php $opcache"

        $php_cli_executable -m
        $php_cli_executable -i

        if $php_cli_executable -i | grep -q "opcache.enable => On"; then
            opcache_enabled=1
        else
            opcache_enabled=0
        fi

        jit_enabled=0
        if $php_cli_executable -i | grep -q "opcache.jit => tracing"; then
            if $php_cli_executable -i | grep -q "opcache.jit_buffer_size => 64"; then
                jit_enabled=1
            fi
        fi

        if [[ "$opcache_enabled" = "0" ]]; then
            echo "OPCache should be enabled"
            exit 1
        fi

        if [[ "$PHP_JIT" = "1" ]]; then
            if [[ "$jit_enabled" = "0" ]]; then
                echo "JIT should be enabled"
                exit 1
            fi
        fi

        if [[ "$PHP_JIT" = "0" ]]; then
            if [[ "$jit_enabled" = "1" ]]; then
                echo "JIT should not be enabled"
                exit 1
            fi
        fi

        size $PHP_SOURCE_PATH/sapi/cgi/php-cgi --format=SysV
    done
fi
