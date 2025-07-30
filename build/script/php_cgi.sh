#!/bin/sh
set -e

sed -i "s/OPCACHE_ENABLED/$PHP_OPCACHE/g" /usr/local/etc/php/conf.d/zz-custom-php.ini

if [[ "$PHP_JIT" = "1" ]]; then
    sed -i "s/JIT_MODE/tracing/g" /usr/local/etc/php/conf.d/zz-custom-php.ini
    sed -i "s/JIT_BUFFER_SIZE/64M/g" /usr/local/etc/php/conf.d/zz-custom-php.ini
else
    sed -i "s/JIT_MODE/disable/g" /usr/local/etc/php/conf.d/zz-custom-php.ini
    sed -i "s/JIT_BUFFER_SIZE/0/g" /usr/local/etc/php/conf.d/zz-custom-php.ini
fi

if [ "$PHP_OPCACHE" = "2" ]; then
    OPCACHE_PATH="$(cd /usr/local/lib/php/extensions/ && find . -path "./*/opcache.so")"
    opcache="-d zend_extension=/usr/local/lib/php/extensions/$OPCACHE_PATH"
else
    opcache=""
fi

export REQUEST_URI="$4"
export APP_ENV="$5"
export APP_DEBUG=false
export APP_SECRET=random
export SESSION_DRIVER=cookie
export LOG_LEVEL=warning

if [ "$1" = "quiet" ]; then
    php-cgi $opcache "-T$2" "$3" > /dev/null
else
    php-cgi $opcache -q "-T$2" "$3"
fi
