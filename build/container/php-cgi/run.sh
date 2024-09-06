#!/bin/sh
set -e

/code/build/container/php-cgi/config.sh

if [ "$PHP_OPCACHE" = "1" ]; then
    OPCACHE_PATH="$(cd /usr/local/lib/php/extensions/ && find . -path "./*/opcache.so")"
    opcache="-d zend_extension=/usr/local/lib/php/extensions/$OPCACHE_PATH"
else
    opcache=""
fi

export CONTENT_TYPE="text/html; charset=utf-8"
export SCRIPT_FILENAME="/code/$3"
export REQUEST_URI="$4"
export APP_ENV="$5"
export APP_DEBUG=false
export SESSION_DRIVER=cookie
export LOG_LEVEL=warning
export DB_CONNECTION=sqlite
export LOG_CHANNEL=stderr
export BROADCAST_DRIVER=null

if [ "$1" = "quiet" ]; then
    php-cgi $opcache "-T$2" "/code/$3" > /dev/null
elif [ "$1" = "verbose" ]; then
    php-cgi $opcache "-T$2" "/code/$3"
elif [ "$1" = "instruction_count" ]; then
    valgrind --tool=callgrind --dump-instr=no -- \
        php-cgi $opcache "-T$2" "/code/$3" > /dev/null
elif [ "$1" = "memory" ]; then
    /usr/bin/time -v \
        php-cgi $opcache "-T$2" "/code/$3" > /dev/null
else
    php-cgi $opcache -q "-T$2" "/code/$3"
fi
