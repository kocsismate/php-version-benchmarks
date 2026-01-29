#!/usr/bin/env bash
set -e

# -fno-pic: does not generate position-independent code (for shared libraries).
# -fno-pie: no runtime indirection from PIE.
# -O2: predictable, stable optimizations.
# -fno-asynchronous-unwind-tables: no runtime metadata noise.

# Other options tried out:
# -fno-stack-protector: no canaries (consistent stack layout).
# -fno-plt: removes PLT indirection variance.
# -fexcess-precision=standard / -ffp-contract=off: FP operations consistent across runs.
cflags="-fno-pic -fno-pie -O2 -fno-asynchronous-unwind-tables -frandom-seed=1"
cppflags="$cflags"
# Enable linker optimization (this sorts the hash buckets to improve cache locality, and is non-default)
# -Wl,-O1: stable section ordering.
# -no-pie: reinforces non-PIE binary.
# --build-id=none: removes build ID hash (avoids layout differences).
ldflags="-Wl,-O1 -no-pie -Wl,--build-id=none"
export SOURCE_DATE_EPOCH=0

cd "$PHP_SOURCE_PATH"

./buildconf

if git merge-base --is-ancestor "7b4c14dc10167b65ce51371507d7b37b74252077" HEAD > /dev/null 2>&1; then
    opcache_option=""
else
    opcache_option="--enable-opcache"
fi

# --enable-werror \ commenting out due to dynasm errors

CFLAGS=$cflags CPPFLAGS=$cppflags LDFLAGS=$ldflags ./configure \
    --with-config-file-path="$PHP_SOURCE_PATH" \
    --with-config-file-scan-dir="$PHP_SOURCE_PATH/conf.d" \
    --enable-option-checking=fatal \
    --disable-debug \
    --enable-mbstring \
    --enable-intl \
    --with-mysqli=mysqlnd  \
    --enable-mysqlnd \
    --with-pdo-sqlite=/usr \
    --with-sqlite3=/usr \
    --with-curl \
    --with-libedit \
    $opcache_option \
    --with-openssl \
    --with-zlib \
    --enable-cgi

OPCACHE_FILE_PATH="$PHP_SOURCE_PATH/opcache_files"
mkdir -p "$OPCACHE_FILE_PATH"

make -j "$1"

mkdir -p "$PHP_SOURCE_PATH/conf.d/"
cp "$PROJECT_ROOT/build/custom-php.ini" "$PHP_SOURCE_PATH/conf.d/zz-custom-php.ini"

sed -i "s|OPCACHE_FILE_PATH|$OPCACHE_FILE_PATH|g" "$PHP_SOURCE_PATH/conf.d/zz-custom-php.ini"

if [[ "$PHP_JIT" = "1" ]]; then
    sed -i "s/JIT_MODE/tracing/g" "$PHP_SOURCE_PATH/conf.d/zz-custom-php.ini"
    sed -i "s/JIT_BUFFER_SIZE/64M/g" "$PHP_SOURCE_PATH/conf.d/zz-custom-php.ini"
else
    sed -i "s/JIT_MODE/disable/g" "$PHP_SOURCE_PATH/conf.d/zz-custom-php.ini"
    sed -i "s/JIT_BUFFER_SIZE/0/g" "$PHP_SOURCE_PATH/conf.d/zz-custom-php.ini"
fi
