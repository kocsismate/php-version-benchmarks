#!/usr/bin/env bash
set -e

laravel_version="12.11.0" # https://github.com/laravel/laravel/releases
symfony_version="2.8.0" # https://github.com/symfony/demo/releases
wordpress_url="https://github.com/kocsismate/benchmarking-wordpress-6.9"
wordpress_mysql_version="8.4.8"

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
            composer install --classmap-authoritative --no-interaction --working-dir=/code/app/laravel"

    sed -i "s/'lottery' => \\[2, 100\\],/'lottery' => \\[0, 100\\],/g" $PROJECT_ROOT/app/laravel/config/session.php
    #sed -i "s#error_reporting(-1);#//error_reporting(-1);#g" $PROJECT_ROOT/app/laravel/vendor/laravel/framework/src/Illuminate/Foundation/Bootstrap/HandleExceptions.php

    sed -i "s/if (\\\\PHP_VERSION_ID >= 80300) {/if (\\\\PHP_VERSION_ID > 80300 || (\\\\PHP_VERSION_ID === 80300 \&\& \\\\PHP_EXTRA_VERSION !== '-dev')) {/g" "$PROJECT_ROOT/app/laravel/vendor/symfony/polyfill-php83/bootstrap.php"
    sed -i "s/if (\\\\PHP_VERSION_ID >= 80300) {/if (\\\\PHP_VERSION_ID > 80300 || (\\\\PHP_VERSION_ID === 80300 \&\& \\\\PHP_EXTRA_VERSION !== '-dev')) {/g" "$PROJECT_ROOT/app/laravel/vendor/symfony/polyfill-php83/bootstrap81.php"
    sed -i "s/if (\\\\PHP_VERSION_ID >= 80400) {/if (\\\\PHP_VERSION_ID > 80400 || (\\\\PHP_VERSION_ID === 80400 \&\& \\\\PHP_EXTRA_VERSION !== '-dev')) {/g" "$PROJECT_ROOT/app/laravel/vendor/symfony/polyfill-php84/bootstrap.php"
    sed -i "s/if (\\\\PHP_VERSION_ID >= 80400) {/if (\\\\PHP_VERSION_ID > 80400 || (\\\\PHP_VERSION_ID === 80400 \&\& \\\\\PHP_EXTRA_VERSION !== '-dev')) {/g" "$PROJECT_ROOT/app/laravel/vendor/symfony/polyfill-php84/bootstrap82.php"
    sed -i "s/if (\\\\PHP_VERSION_ID >= 80500) {/if (\\\\PHP_VERSION_ID > 80500 || (\\\\PHP_VERSION_ID === 80500 \&\& \\\\PHP_EXTRA_VERSION !== '-dev')) {/g" "$PROJECT_ROOT/app/laravel/vendor/symfony/polyfill-php85/bootstrap.php"

    sudo chmod -R 777 "$PROJECT_ROOT/app/laravel/storage"
}

install_symfony () {
    mkdir -p "$PROJECT_ROOT/app/symfony"
    mkdir -p "$PROJECT_ROOT/tmp/app/symfony"

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
            composer update symfony/config:7.3.6 symfony/dependency-injection:7.3.9 symfony/event-dispatcher:7.3.3 doctrine/persistence:3.4.3 doctrine/orm:3.6.0 doctrine/doctrine-bundle:2.18.2 --working-dir=/code/app/symfony && \
            composer config platform-check false --working-dir=/code/app/symfony && \
            composer dump-autoload --classmap-authoritative --working-dir=/code/app/symfony"

    sed -i "/trigger_deprecation('symfony\/var-exporter', '7.3', 'Using ProxyHelper::generateLazyGhost() is deprecated, use native lazy objects instead.');/d" "$PROJECT_ROOT/app/symfony/vendor/symfony/var-exporter/ProxyHelper.php"
    sed -i "/trigger_deprecation('symfony\/var-exporter', '7.3', 'The \"%s\" trait is deprecated, use native lazy objects instead.', LazyProxyTrait::class);/d" "$PROJECT_ROOT/app/symfony/vendor/symfony/var-exporter/LazyProxyTrait.php"
    sed -i "/trigger_deprecation('symfony\/var-exporter', '7.3', 'The \"%s\" trait is deprecated, use native lazy objects instead.', LazyGhostTrait::class);/d" "$PROJECT_ROOT/app/symfony/vendor/symfony/var-exporter/LazyGhostTrait.php"

    sed -i "s/if (PHP_VERSION_ID >= 80400) {/if (0) {/g" "$PROJECT_ROOT/app/symfony/vendor/doctrine/orm/src/Configuration.php"
    sed -i "s/if (PHP_VERSION_ID >= 80400) {/if (0) {/g" "$PROJECT_ROOT/app/symfony/vendor/doctrine/orm/src/Proxy/Autoloader.php"
    sed -i "s/if (PHP_VERSION_ID >= 80400) {/if (0) {/g" "$PROJECT_ROOT/app/symfony/vendor/doctrine/orm/src/Proxy/DefaultProxyClassNameResolver.php"
    sed -i "s/if (PHP_VERSION_ID >= 80400) {/if (0) {/g" "$PROJECT_ROOT/app/symfony/vendor/doctrine/orm/src/Proxy/ProxyFactory.php"

    sudo chmod -R 777 "$PROJECT_ROOT/app/symfony/var"
}

install_wordpress () {
    mkdir -p "$PROJECT_ROOT/app/wordpress"
    mkdir -p "$PROJECT_ROOT/tmp/app/wordpress"

    git clone --depth=1 "$wordpress_url" "$PROJECT_ROOT/app/wordpress"

    local mysql_address="127.0.0.1"
    local mysql_container="wordpress_db"
    local mysql_db="wordpress"
    local mysql_user="wordpress"
    local mysql_password="wordpress"
    local mysql_timeout=60
    local mysql_data_path="$PROJECT_ROOT/tmp/app/wordpress/mysql-data"
    local mysql_config_path="$PROJECT_ROOT/build/mysql"

    sudo mkdir -p "$mysql_data_path"
    sudo chown $(id -u):$(id -g) "$mysql_data_path"

    MYSQL_CPUS="1-2"

    sudo cgexec -g cpuset:mysql \
        docker run \
        --name "$mysql_container" \
        --user "$(id -u):$(id -g)" \
        -v $mysql_data_path:/var/lib/mysql \
        -v $mysql_config_path:/etc/mysql/conf.d \
        --network "host" \
        --cpuset-cpus="$MYSQL_CPUS" \
        --memory="4G" \
        -e "MYSQL_ROOT_PASSWORD=root" \
        -e "MYSQL_DATABASE=$mysql_db" \
        -e "MYSQL_USER=$mysql_user" \
        -e "MYSQL_PASSWORD=$mysql_password" \
        -d mysql:$wordpress_mysql_version

    $PROJECT_ROOT/build/script/wait_for_mysql.sh "$mysql_container" "$mysql_db" "$mysql_user" "$mysql_password" "$mysql_timeout"

    sudo docker logs "$mysql_container"

    sudo docker run --rm \
        --name "wordpress_cli" \
        --volume "$PROJECT_ROOT:/code" \
        --user "$(id -u):$(id -g)" \
        --network "host" \
        -e "WORDPRESS_DB_HOST=$mysql_address" \
        setup bash -c "\
            set -e
            php /code/app/wordpress/wp-cli.phar core install \
                --path=/code/app/wordpress/ \
                --allow-root --url=localhost --title=Wordpress \
                --admin_user=wordpress --admin_password=wordpress --admin_email=benchmark@php.net"

    sed -i "s/\t\terror_reporting( E_CORE_ERROR | E_CORE_WARNING | E_COMPILE_ERROR | E_ERROR | E_WARNING | E_PARSE | E_USER_ERROR | E_USER_WARNING | E_RECOVERABLE_ERROR );/\t\terror_reporting( E_ALL );/g" "$PROJECT_ROOT/app/wordpress/wp-includes/load.php"
    sed -i "s/\terror_reporting( E_CORE_ERROR | E_CORE_WARNING | E_COMPILE_ERROR | E_ERROR | E_WARNING | E_PARSE | E_USER_ERROR | E_USER_WARNING | E_RECOVERABLE_ERROR );/\terror_reporting( E_ALL );/g" "$PROJECT_ROOT/app/wordpress/wp-load.php"
}

mkdir -p "$PROJECT_ROOT/tmp/app"

laravel_test="$(grep -c "TEST_ID=laravel" $PROJECT_ROOT/config/test/*.ini || true)"
symfony_main_test="$(grep -c "TEST_ID=symfony_main" $PROJECT_ROOT/config/test/*.ini || true)"
symfony_blog_test="$(grep -c "TEST_ID=symfony_blog" $PROJECT_ROOT/config/test/*.ini || true)"
wordpress_test="$(grep -c "TEST_ID=wordpress" $PROJECT_ROOT/config/test/*.ini || true)"

# Build docker image for setup
if [[ "$laravel_test" != "0" || "$symfony_main_test" != "0" || "$symfony_blog_test" != "0" || "$wordpress_test" != "0" ]]; then
    sudo docker build -t setup "$PROJECT_ROOT/app"
fi

# Install Laravel demo app
if [ "$laravel_test" != "0" ]; then
    install_laravel &
fi

# Install Symfony demo app
if [[ "$symfony_main_test" != "0" ]]; then
    install_symfony &
fi

# Install Wordpress
if [ "$wordpress_test" != "0" ]; then
    install_wordpress &
fi

wait
