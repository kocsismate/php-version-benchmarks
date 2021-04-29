#!/usr/bin/env bash
set -e

if [[ "$1" == "local-docker" ]]; then

    mkdir -p "$PROJECT_ROOT/app/symfony"
    mkdir -p "$PROJECT_ROOT/app/laravel"
    mkdir -p "$PROJECT_ROOT/app/wordpress"
    mkdir -p "$PROJECT_ROOT/app/zend"

    # Install Laravel demo app
    if [ -z "$(ls -A $PROJECT_ROOT/app/laravel)" ]; then
        docker run --rm \
            --volume $PROJECT_ROOT:/code \
            --user $(id -u):$(id -g) \
            composer create-project laravel/laravel laravel 8.5.16 --no-interaction --working-dir=/code/app

        docker run --rm \
            --volume $PROJECT_ROOT:/code \
            --user $(id -u):$(id -g) \
            composer dump-autoload --classmap-authoritative --working-dir=/code/app/laravel
    fi

    sed -i".original" "s/'lottery' => \\[2, 100\\],/'lottery' => \\[0, 100\\],/g" $PROJECT_ROOT/app/laravel/config/session.php

    # Install Symfony demo app
    if [ -z "$(ls -A $PROJECT_ROOT/app/symfony)" ]; then
        docker run --rm \
            --volume $PROJECT_ROOT:/code \
            --user $(id -u):$(id -g) \
            composer create-project symfony/symfony-demo symfony dev-main --no-interaction --working-dir=/code/app

        docker run --rm \
            --volume $PROJECT_ROOT:/code \
            --user $(id -u):$(id -g) \
            composer dump-autoload --classmap-authoritative --working-dir=/code/app/symfony
    fi

    # Download bench.php
    if [ ! -f "$PROJECT_ROOT/app/zend/bench.php" ]; then
        docker run --rm \
            --volume $PROJECT_ROOT:/code \
            --user $(id -u):$(id -g) \
            curlimages/curl https://raw.githubusercontent.com/php/php-src/master/Zend/bench.php --output /code/app/zend/bench.php
    fi

    # Download micro_bench.php
    if [ ! -f "$PROJECT_ROOT/app/zend/bench.php" ]; then
        docker run --rm \
            --volume $PROJECT_ROOT:/code \
            --user $(id -u):$(id -g) \
            curlimages/curl https://raw.githubusercontent.com/php/php-src/master/Zend/micro_bench.php --output /code/app/zend/micro_bench.php
    fi

    # Download concat test
    if [ ! -f "$PROJECT_ROOT/app/zend/concat.php" ]; then
        docker run --rm \
            --volume $PROJECT_ROOT:/code \
            --user $(id -u):$(id -g) \
            curlimages/curl https://raw.githubusercontent.com/craigfrancis/php-is-literal-rfc/main/tests/001.phpt --output /code/app/zend/concat.php
    fi

elif [[ "$1" == "aws-docker" ]]; then

    mkdir -p "$PROJECT_ROOT/app/symfony"
    mkdir -p "$PROJECT_ROOT/app/laravel"
    mkdir -p "$PROJECT_ROOT/app/wordpress"
    mkdir -p "$PROJECT_ROOT/app/zend"

    # Install Laravel demo app
    sudo docker run --rm \
        --volume $PROJECT_ROOT:/code \
        --user $(id -u):$(id -g) \
        composer create-project laravel/laravel laravel 8.5.16 --no-interaction --working-dir=/code/app

    sudo chmod -R 777 "$PROJECT_ROOT/app/laravel/storage"

    # Install Symfony demo app
    sudo docker run --rm \
        --volume $PROJECT_ROOT:/code \
        --user $(id -u):$(id -g) \
        composer create-project symfony/symfony-demo symfony dev-main --no-interaction --working-dir=/code/app

    sudo chmod -R 777 "$PROJECT_ROOT/app/symfony/var"

    # Download bench.php
    sudo docker run --rm \
        --volume $PROJECT_ROOT:/code \
        --user $(id -u):$(id -g) \
        curlimages/curl https://raw.githubusercontent.com/php/php-src/master/Zend/bench.php --output /code/app/zend/bench.php

    # Download micro_bench.php
    sudo docker run --rm \
        --volume $PROJECT_ROOT:/code \
        --user $(id -u):$(id -g) \
        curlimages/curl https://raw.githubusercontent.com/php/php-src/master/Zend/micro_bench.php --output /code/app/zend/micro_bench.php

    # Download concat.php
    sudo docker run --rm \
        --volume $PROJECT_ROOT:/code \
        --user $(id -u):$(id -g) \
        curlimages/curl https://raw.githubusercontent.com/craigfrancis/php-is-literal-rfc/main/tests/001.phpt --output /code/app/zend/concat.php

else

    echo 'Available options: "local-docker", "aws-docker"!'
    exit 1

fi
