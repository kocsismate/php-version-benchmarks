#!/bin/sh
set -e

cp /code/build/container/php-cgi/custom-php.ini /usr/local/etc/php/conf.d/zz-custom-php.ini

sed -i "s/OPCACHE_ENABLED/$PHP_OPCACHE/g" /usr/local/etc/php/conf.d/zz-custom-php.ini

if [[ "$PHP_JIT" = "1" ]]; then
    sed -i "s/JIT_MODE/tracing/g" /usr/local/etc/php/conf.d/zz-custom-php.ini
    sed -i "s/JIT_BUFFER_SIZE/64M/g" /usr/local/etc/php/conf.d/zz-custom-php.ini
else
    sed -i "s/JIT_MODE/disable/g" /usr/local/etc/php/conf.d/zz-custom-php.ini
    sed -i "s/JIT_BUFFER_SIZE/0/g" /usr/local/etc/php/conf.d/zz-custom-php.ini
fi
