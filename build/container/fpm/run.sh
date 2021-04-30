#!/bin/sh
set -e

/code/build/container/fpm/config.sh

if [ "$PHP_OPCACHE" = "1" ]; then
    OPCACHE_PATH="$(cd /usr/local/lib/php/extensions/ && find . -path "./*/opcache.so")"
    php-fpm -d "zend_extension=/usr/local/lib/php/extensions/$OPCACHE_PATH"
else
    php-fpm
fi
