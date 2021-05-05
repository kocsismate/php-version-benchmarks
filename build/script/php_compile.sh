#!/bin/sh
set -e

# Apply stack smash protection to functions using local buffers and alloca()
# Make PHP's main executable position-independent (improves ASLR security mechanism, and has no performance impact on x86_64)
# Enable optimization (-O2)
# Enable linker optimization (this sorts the hash buckets to improve cache locality, and is non-default)
# https://github.com/docker-library/php/issues/272
# -D_LARGEFILE_SOURCE and -D_FILE_OFFSET_BITS=64 (https://www.php.net/manual/en/intro.filesystem.php)
export PHP_CFLAGS="-fstack-protector-strong -fPIC -fpie -O2 -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64"
export PHP_CPPFLAGS="$PHP_CFLAGS"
export PHP_LDFLAGS="-Wl,-O1 -no-pie"

#gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)";
#debMultiarch="$(dpkg-architecture --query DEB_BUILD_MULTIARCH)";
#--build="$gnuArch" \
#--with-libdir="lib/$debMultiarch" \

cd "$PHP_SOURCE_PATH"
./buildconf
./configure \
    --with-config-file-path="$PHP_SOURCE_PATH" \
    --with-config-file-scan-dir="$PHP_SOURCE_PATH/conf.d" \
    --enable-option-checking=fatal \
    --enable-mbstring \
    --enable-mysqlnd \
    --with-pdo-sqlite=/usr \
    --with-sqlite3=/usr \
    --with-curl \
    --with-libedit \
    --with-openssl \
    --with-zlib \
    --enable-cgi \
    --with-pear

make -j "$(nproc)"

mkdir -p "$PHP_SOURCE_PATH/conf.d/"
cp "$PROJECT_ROOT/build/container/php-cgi/custom-php.ini" "$PHP_SOURCE_PATH/conf.d/zz-custom-php.ini"

sed -i "s/OPCACHE_ENABLED/$PHP_OPCACHE/g" "$PHP_SOURCE_PATH/conf.d/zz-custom-php.ini"

if [ "$PHP_PRELOADING" = "1" ]; then
    sed -i "s/PRELOAD_SCRIPT/\/code\/app\/preload\.php/g" "$PHP_SOURCE_PATH/conf.d/zz-custom-php.ini"
else
    sed -i "s/PRELOAD_SCRIPT/\"\"/g" "$PHP_SOURCE_PATH/conf.d/zz-custom-php.ini"
fi

if [ "$PHP_JIT" = "1" ]; then
    sed -i "s/JIT_BUFFER_SIZE/32M/g" "$PHP_SOURCE_PATH/conf.d/zz-custom-php.ini"
else
    sed -i "s/JIT_BUFFER_SIZE/0/g" "$PHP_SOURCE_PATH/conf.d/zz-custom-php.ini"
fi
