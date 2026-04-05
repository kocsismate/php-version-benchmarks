#!/usr/bin/env bash
set -e

reset_original_file () {
    file="$1"

    if [[ -f "${file}.original" ]]; then
        mv -f "${file}.original" "$file"
    fi
}

symfony_dir="$PROJECT_ROOT/app/symfony"
symfony_tmp_dir="$PROJECT_ROOT/tmp/app/symfony"

# Update config based on PHP version
reset_original_file "$symfony_dir/config/packages/doctrine.yaml"
reset_original_file "$symfony_dir/vendor/symfony/var-exporter/ProxyHelper.php"
reset_original_file "$symfony_dir/vendor/symfony/dependency-injection/LazyProxy/PhpDumper/LazyServiceDumper.php"

if git --git-dir="$php_source_path/.git" --work-tree="$php_source_path" merge-base --is-ancestor "315fef2c72d172f4f81420e8f64ab2f3cd9e55b1" HEAD > /dev/null 2>&1; then
    sed -i.original "s/        enable_lazy_ghost_objects: true/        enable_lazy_ghost_objects: true\n        enable_native_lazy_objects: true/g" "$symfony_dir/config/packages/doctrine.yaml"
else
    sed -i.original "s/if (\\\\PHP_VERSION_ID < 80400) {/if (\\\\PHP_VERSION_ID <= 80400) {/g" "$symfony_dir/vendor/symfony/var-exporter/ProxyHelper.php"
    sed -i.original "s/if (\\\\PHP_VERSION_ID < 80400) {/if (\\\\PHP_VERSION_ID <= 80400) {/g" "$symfony_dir/vendor/symfony/dependency-injection/LazyProxy/PhpDumper/LazyServiceDumper.php"
fi

# Regenerate cache
if [[ -d "$symfony_tmp_dir/cache-$PHP_ID" ]]; then
    cp -rf "$symfony_tmp_dir/cache-$PHP_ID" "$symfony_dir/var/cache"
else
    rm -rf "$symfony_tmp_dir/cache/prod/Container*"
    rm -rf "$symfony_tmp_dir/cache/prod/App_KernelProdContainer*"
    APP_ENV=prod APP_DEBUG=false APP_SECRET=random $php_source_path/sapi/cli/php "$symfony_dir/bin/console" "cache:warmup"

    cp -r "$symfony_dir/var/cache" "$symfony_tmp_dir/cache-$PHP_ID"
fi
