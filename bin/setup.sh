#!/usr/bin/env bash
set -e

if [[ "$1" == "local-docker" ]]; then
    run_as=""
else
    run_as="sudo"
fi

mkdir -p "$PROJECT_ROOT/app/symfony"
mkdir -p "$PROJECT_ROOT/app/laravel"
mkdir -p "$PROJECT_ROOT/app/wordpress"

# Install Laravel demo app
if [ -z "$(ls -A $PROJECT_ROOT/app/laravel)" ]; then
    $run_as docker run --rm \
        --volume $PROJECT_ROOT:/code \
        --user $(id -u):$(id -g) \
        composer create-project laravel/laravel laravel 8.5.16 --no-interaction --working-dir=/code/app \

    $run_as docker run --rm \
        --volume $PROJECT_ROOT:/code \
        --user $(id -u):$(id -g) \
        composer dump-autoload --classmap-authoritative --working-dir=/code/app/laravel

    sed -i".original" "s/'lottery' => \\[2, 100\\],/'lottery' => \\[0, 100\\],/g" $PROJECT_ROOT/app/laravel/config/session.php
    sed -i".original" "s#error_reporting(-1);#//error_reporting(-1);#g" $PROJECT_ROOT/app/laravel/vendor/laravel/framework/src/Illuminate/Foundation/Bootstrap/HandleExceptions.php
fi

# Install Symfony demo app
if [ -z "$(ls -A $PROJECT_ROOT/app/symfony)" ]; then
    $run_as docker run --rm \
        --volume $PROJECT_ROOT:/code \
        --user $(id -u):$(id -g) \
        composer create-project symfony/symfony-demo symfony dev-main --no-interaction --working-dir=/code/app

    $run_as docker run --rm \
        --volume $PROJECT_ROOT:/code \
        --user $(id -u):$(id -g) \
        composer dump-autoload --classmap-authoritative --working-dir=/code/app/symfony
fi

if [[ "$1" == "aws-docker" ]]; then

    sudo chmod -R 777 "$PROJECT_ROOT/app/laravel/storage"
    sudo chmod -R 777 "$PROJECT_ROOT/app/symfony/var"

fi
