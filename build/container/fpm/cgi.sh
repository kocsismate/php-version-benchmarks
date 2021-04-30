#!/bin/sh
set -e

/code/build/container/fpm/config.sh

if [ "$PHP_OPCACHE" = "1" ]; then
    OPCACHE_PATH="$(cd /usr/local/lib/php/extensions/ && find . -path "./*/opcache.so")"
    opcache="-d zend_extension=/usr/local/lib/php/extensions/$OPCACHE_PATH"
else
    opcache=""
fi

export REQUEST_URI="$4"
export APP_ENV="$5"
export APP_DEBUG=false
export SESSION_DRIVER=cookie
export LOG_LEVEL=warning

if [ "$1" = "quiet" ]; then
    php-cgi $opcache "-T$2" "$3" > /dev/null
else
    php-cgi $opcache -q "-T$2" "$3"
fi
