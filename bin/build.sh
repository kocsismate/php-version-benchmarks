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
    echo "Installing apps..."
    $PROJECT_ROOT/bin/install.sh
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
    echo "PHP alignment variations: $INFRA_PHP_ALIGNMENT_VARIATIONS"
    echo "PHP linking order variations: $INFRA_PHP_LINKING_ORDER_VARIATIONS"

    php_variation=1
    linking_order_variation_count="$INFRA_PHP_LINKING_ORDER_VARIATIONS"
    if [[ -z "$linking_order_variation_count" ]] || [[ "$linking_order_variation_count" -eq 0 ]]; then
        linking_order_variation_count=1
    fi
    for php_alignment in $INFRA_PHP_ALIGNMENT_VARIATIONS; do
        for php_linking_order in $(seq "$linking_order_variation_count"); do
            for php_config in $PROJECT_ROOT/config/php/*.ini; do
                source "$php_config"
                export $(cut -d= -f1 $php_config)
                export PHP_SOURCE_PATH="$PROJECT_ROOT/tmp/$PHP_ID"

                php_target_path="$PHP_SOURCE_PATH-v${php_variation}"
                rsync -a "$PHP_SOURCE_PATH/" "$php_target_path"

                echo "Compiling $PHP_NAME (alignment: $php_alignment, linking order: $php_linking_order)..."
                $PROJECT_ROOT/build/script/php_compile.sh "$php_target_path" "$php_alignment" "$INFRA_PHP_ALIGNMENT_VARIATIONS" "$cpu_per_php" &
            done

            wait
            php_variation="$((php_variation + 1))"
        done
    done

    php_variation=1
    for php_alignment in $INFRA_PHP_ALIGNMENT_VARIATIONS; do
        for php_linking_order in $(seq "$linking_order_variation_count"); do
            for php_config in $PROJECT_ROOT/config/php/*.ini; do
                source "$php_config"
                export $(cut -d= -f1 $php_config)
                export PHP_SOURCE_PATH="$PROJECT_ROOT/tmp/$PHP_ID-v${php_variation}"

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

            wait
            php_variation="$((php_variation + 1))"
        done
    done
fi
