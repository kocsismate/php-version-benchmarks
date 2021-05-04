#!/bin/sh
set -eux

gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)";
debMultiarch="$(dpkg-architecture --query DEB_BUILD_MULTIARCH)";

# Apply stack smash protection to functions using local buffers and alloca()
# Make PHP's main executable position-independent (improves ASLR security mechanism, and has no performance impact on x86_64)
# Enable optimization (-O2)
# Enable linker optimization (this sorts the hash buckets to improve cache locality, and is non-default)
# https://github.com/docker-library/php/issues/272
# -D_LARGEFILE_SOURCE and -D_FILE_OFFSET_BITS=64 (https://www.php.net/manual/en/intro.filesystem.php)
export PHP_CFLAGS="-fstack-protector-strong -fpic -fpie -O2 -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64"
export PHP_CPPFLAGS="$PHP_CFLAGS"
export PHP_LDFLAGS="-Wl,-O1 -pie"

cd "$PHP_SOURCE_PATH"
./buildconf
./configure \
    --build="$gnuArch" \
    --with-config-file-path="$PHP_INI_DIR" \
    --with-config-file-scan-dir="$PHP_INI_DIR/conf.d" \
    --enable-option-checking=fatal \
    --enable-mbstring \
    --enable-mysqlnd \
    --with-password-argon2 \
    --with-sodium \
    --with-pdo-sqlite=/usr \
    --with-sqlite3=/usr \
    --with-curl \
    --with-libedit \
    --with-openssl \
    --with-zlib \
    --with-libdir="lib/$debMultiarch" \
    --enable-cgi \
    --with-pear

make -j "$(nproc)"
