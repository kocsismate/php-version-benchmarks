#!/usr/bin/env bash
set -e

laravel_version="12.11.0" # https://github.com/laravel/laravel/releases
symfony_version="2.8.0" # https://github.com/symfony/demo/releases
wordpress_url="https://github.com/kocsismate/benchmarking-wordpress-6.9"

install_laravel () {
    mkdir -p "$PROJECT_ROOT/app/laravel"

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
            composer install --classmap-authoritative --no-interaction --working-dir=/code/app/laravel && \
            composer dump-autoload --classmap-authoritative --working-dir=/code/app/laravel"

    sed -i".original" "s/'lottery' => \\[2, 100\\],/'lottery' => \\[0, 100\\],/g" $PROJECT_ROOT/app/laravel/config/session.php
    #sed -i".original" "s#error_reporting(-1);#//error_reporting(-1);#g" $PROJECT_ROOT/app/laravel/vendor/laravel/framework/src/Illuminate/Foundation/Bootstrap/HandleExceptions.php

    sudo chmod -R 777 "$PROJECT_ROOT/app/laravel/storage"
}

install_symfony () {
    mkdir -p "$PROJECT_ROOT/app/symfony"

    if [ -z "$(ls -A $PROJECT_ROOT/app/symfony)" ]; then
        sudo docker run --rm \
            --volume $PROJECT_ROOT:/code \
            --user $(id -u):$(id -g) \
            setup bash -c "\
            set -e
            export APP_ENV=prod
            export APP_DEBUG=false
            export APP_SECRET=random
            [[ -n '$GITHUB_TOKEN' ]] && composer config --global github-oauth.github.com '$GITHUB_TOKEN'; \
            composer create-project symfony/symfony-demo symfony $symfony_version --no-interaction --working-dir=/code/app && \
            composer update symfony/config:7.3.6 symfony/dependency-injection:7.3.9 doctrine/persistence:3.4.3 doctrine/orm:3.6.0 doctrine/doctrine-bundle:2.18.2 --working-dir=/code/app/symfony && \
            composer config platform-check false --working-dir=/code/app/symfony && \
            composer dump-autoload --classmap-authoritative --working-dir=/code/app/symfony"
    fi

    sed -i".original" "/trigger_deprecation('symfony\/var-exporter', '7.3', 'Using ProxyHelper::generateLazyGhost() is deprecated, use native lazy objects instead.');/d" "$PROJECT_ROOT/app/symfony/vendor/symfony/var-exporter/ProxyHelper.php"
    sed -i".original" "/trigger_deprecation('symfony\/var-exporter', '7.3', 'The \"%s\" trait is deprecated, use native lazy objects instead.', LazyProxyTrait::class);/d" "$PROJECT_ROOT/app/symfony/vendor/symfony/var-exporter/LazyProxyTrait.php"
    sed -i".original" "/trigger_deprecation('symfony\/var-exporter', '7.3', 'The \"%s\" trait is deprecated, use native lazy objects instead.', LazyGhostTrait::class);/d" "$PROJECT_ROOT/app/symfony/vendor/symfony/var-exporter/LazyGhostTrait.php"

    sed -i".original" "s/if (PHP_VERSION_ID >= 80400) {/if (0) {/g" "$PROJECT_ROOT/app/symfony/vendor/doctrine/orm/src/Proxy/Autoloader.php"
    sed -i".original" "s/if (PHP_VERSION_ID >= 80400) {/if (0) {/g" "$PROJECT_ROOT/app/symfony/vendor/doctrine/orm/src/Proxy/DefaultProxyClassNameResolver.php"

    sudo chmod -R 777 "$PROJECT_ROOT/app/symfony/var"
}

install_wordpress () {
    mkdir -p "$PROJECT_ROOT/app/wordpress"

    if [ -z "$(ls -A $PROJECT_ROOT/app/wordpress)" ]; then
        git clone --depth=1 "$wordpress_url" "$PROJECT_ROOT/app/wordpress" &

        for PHP_CONFIG_FILE in $PROJECT_ROOT/config/php/*.ini; do
            source $PHP_CONFIG_FILE
            php_executable="$PROJECT_ROOT/tmp/$PHP_ID/sapi/cli/php"
        done

        sudo docker run \
            --name wordpress_db \
            --user $(id -u):$(id -g) \
            -p "3306:3306" \
            -e MYSQL_ROOT_PASSWORD=root \
            -e MYSQL_DATABASE=wordpress \
            -e MYSQL_USER=wordpress \
            -e MYSQL_PASSWORD=wordpress \
            -d mysql:8.0

        sleep 10

        $php_executable -d error_reporting=0 $PROJECT_ROOT/app/wordpress/wp-cli.phar core install \
            --path=$PROJECT_ROOT/app/wordpress/ \
            --allow-root --url=localhost --title=Wordpress \
            --admin_user=wordpress --admin_password=wordpress --admin_email=benchmark@php.net

        sed -i".original" "s/\t\terror_reporting( E_CORE_ERROR | E_CORE_WARNING | E_COMPILE_ERROR | E_ERROR | E_WARNING | E_PARSE | E_USER_ERROR | E_USER_WARNING | E_RECOVERABLE_ERROR );/\t\terror_reporting( E_ALL );/g" "$PROJECT_ROOT/app/wordpress/wp-includes/load.php"
        sed -i".original" "s/\terror_reporting( E_CORE_ERROR | E_CORE_WARNING | E_COMPILE_ERROR | E_ERROR | E_WARNING | E_PARSE | E_USER_ERROR | E_USER_WARNING | E_RECOVERABLE_ERROR );/\terror_reporting( E_ALL );/g" "$PROJECT_ROOT/app/wordpress/wp-load.php"
    fi
}

laravel_test="$(grep "TEST_ID=laravel" $PROJECT_ROOT/config/test/*.ini | wc -l | sed -e 's/^ *//')"
symfony_main_test="$(grep "TEST_ID=symfony_main" $PROJECT_ROOT/config/test/*.ini | wc -l | sed -e 's/^ *//')"
symfony_blog_test="$(grep "TEST_ID=symfony_blog" $PROJECT_ROOT/config/test/*.ini | wc -l | sed -e 's/^ *//')"

# Build docker image for setup
if [[ "$laravel_test" -gt "0" || "$symfony_main_test" -gt "0" || "$symfony_blog_test" -gt "0" ]]; then
    sudo docker build -t setup $PROJECT_ROOT/app
fi

# Install Laravel demo app
if [ "$laravel_test" -gt "0" ]; then
    install_laravel &
fi

# Install Symfony demo app
if [[ "$symfony_main_test" -gt "0" || "$symfony_blog_test" -gt "0" ]]; then
    install_symfony &
fi

# Install Wordpress
wordpress_test="$(grep "TEST_ID=wordpress" $PROJECT_ROOT/config/test/*.ini | wc -l | sed -e 's/^ *//')"
if [ "$wordpress_test" -gt "0" ]; then
    install_wordpress &
fi

wait
