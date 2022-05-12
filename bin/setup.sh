#!/usr/bin/env bash
set -e

laravel_version="9.1.8" # https://github.com/laravel/laravel/releases
symfony_version="2.0.2" # https://github.com/symfony/demo/releases

run_as=""
if [[ "$INFRA_ENVIRONMENT" == "aws" ]]; then
    run_as="sudo"
fi

mkdir -p "$PROJECT_ROOT/app/symfony"
mkdir -p "$PROJECT_ROOT/app/laravel"

# Install Laravel demo app
if [ -z "$(ls -A $PROJECT_ROOT/app/laravel)" ]; then
    $run_as docker run --rm \
        --volume $PROJECT_ROOT:/code \
        --user $(id -u):$(id -g) \
        composer create-project laravel/laravel laravel $laravel_version --no-interaction --working-dir=/code/app

    $run_as docker run --rm \
        --volume $PROJECT_ROOT:/code \
        --user $(id -u):$(id -g) \
        composer update --prefer-lowest --no-interaction --working-dir=/code/app/laravel --classmap-authoritative

    sed -i".original" "s/'lottery' => \\[2, 100\\],/'lottery' => \\[0, 100\\],/g" $PROJECT_ROOT/app/laravel/config/session.php
    sed -i".original" "s#error_reporting(-1);#//error_reporting(-1);#g" $PROJECT_ROOT/app/laravel/vendor/laravel/framework/src/Illuminate/Foundation/Bootstrap/HandleExceptions.php
fi

# Install Symfony demo app
if [ -z "$(ls -A $PROJECT_ROOT/app/symfony)" ]; then
    $run_as docker run --rm \
        --volume $PROJECT_ROOT:/code \
        --user $(id -u):$(id -g) \
        composer create-project symfony/symfony-demo symfony $symfony_version --no-interaction --working-dir=/code/app

    $run_as docker run --rm \
        --volume $PROJECT_ROOT:/code \
        --user $(id -u):$(id -g) \
        composer dump-autoload --classmap-authoritative --working-dir=/code/app/symfony
fi

if [[ "$INFRA_ENVIRONMENT" == "aws" ]]; then

    sudo chmod -R 777 "$PROJECT_ROOT/app/laravel/storage"
    sudo chmod -R 777 "$PROJECT_ROOT/app/symfony/var"

fi
