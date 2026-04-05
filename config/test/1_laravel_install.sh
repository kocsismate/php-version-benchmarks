#!/usr/bin/env bash
set -e

laravel_version="12.11.0" # https://github.com/laravel/laravel/releases
laravel_dir="$PROJECT_ROOT/app/laravel"

if [[ -d "$laravel_dir" ]]; then
    echo "Laravel is already installed"
    exit
fi

mkdir -p "$laravel_dir"

sudo docker run --rm \
    --volume $PROJECT_ROOT:/code \
    --user $(id -u):$(id -g) \
    setup bash -c "\
        set -e \
        [[ -n '$GITHUB_TOKEN' ]] && composer config --global github-oauth.github.com '$GITHUB_TOKEN'; \
        composer create-project laravel/laravel laravel $laravel_version --no-interaction --working-dir=/code/app && \
        cp /code/app/laravel.composer.lock /code/app/laravel/composer.lock && \
        composer config platform-check false --working-dir=/code/app/laravel && \
        composer config platform.php 8.2 --working-dir=/code/app/laravel && \
        composer install --classmap-authoritative --no-interaction --working-dir=/code/app/laravel"

sed -i "s/'lottery' => \\[2, 100\\],/'lottery' => \\[0, 100\\],/g" $laravel_dir/config/session.php
#sed -i "s#error_reporting(-1);#//error_reporting(-1);#g" $laravel_dir/vendor/laravel/framework/src/Illuminate/Foundation/Bootstrap/HandleExceptions.php

sed -i "s/if (\\\\PHP_VERSION_ID >= 80300) {/if (\\\\PHP_VERSION_ID > 80300 || (\\\\PHP_VERSION_ID === 80300 \&\& \\\\PHP_EXTRA_VERSION !== '-dev')) {/g" "$laravel_dir/vendor/symfony/polyfill-php83/bootstrap.php"
sed -i "s/if (\\\\PHP_VERSION_ID >= 80300) {/if (\\\\PHP_VERSION_ID > 80300 || (\\\\PHP_VERSION_ID === 80300 \&\& \\\\PHP_EXTRA_VERSION !== '-dev')) {/g" "$laravel_dir/vendor/symfony/polyfill-php83/bootstrap81.php"
sed -i "s/if (\\\\PHP_VERSION_ID >= 80400) {/if (\\\\PHP_VERSION_ID > 80400 || (\\\\PHP_VERSION_ID === 80400 \&\& \\\\PHP_EXTRA_VERSION !== '-dev')) {/g" "$laravel_dir/vendor/symfony/polyfill-php84/bootstrap.php"
sed -i "s/if (\\\\PHP_VERSION_ID >= 80400) {/if (\\\\PHP_VERSION_ID > 80400 || (\\\\PHP_VERSION_ID === 80400 \&\& \\\\\PHP_EXTRA_VERSION !== '-dev')) {/g" "$laravel_dir/vendor/symfony/polyfill-php84/bootstrap82.php"
sed -i "s/if (\\\\PHP_VERSION_ID >= 80500) {/if (\\\\PHP_VERSION_ID > 80500 || (\\\\PHP_VERSION_ID === 80500 \&\& \\\\PHP_EXTRA_VERSION !== '-dev')) {/g" "$laravel_dir/vendor/symfony/polyfill-php85/bootstrap.php"

sudo chmod -R 777 "$laravel_dir/storage"
