#!/bin/sh
set -e

# -fpic: generates position-independent code (for shared libraries).
# -fno-pie: no runtime indirection from PIE.
# -O2: predictable, stable optimizations.
# -fno-asynchronous-unwind-tables: no runtime metadata noise.
# -fno-stack-protector: no canaries (consistent stack layout).
# -fno-plt: removes PLT indirection variance.
# -fexcess-precision=standard / -ffp-contract=off: FP operations consistent across runs.
export CFLAGS="-fpic -fno-pie -O2 -fno-asynchronous-unwind-tables -fno-stack-protector -fno-plt -fexcess-precision=standard -ffp-contract=off -I/usr/include"
export CPPFLAGS="$CFLAGS"
# Enable linker optimization (this sorts the hash buckets to improve cache locality, and is non-default)
# -Wl,-O1: stable section ordering.
# -no-pie: reinforces non-PIE binary.
# --sort-common: deterministic placement of COMMON symbols.
# --build-id=none: removes build ID hash (avoids layout differences).
export LDFLAGS="-Wl,-O1 -no-pie --sort-common -Wl,--build-id=none -L/usr/lib64 -ljemalloc"

cd "$PHP_SOURCE_PATH"
./buildconf

if [ "$PHP_OPCACHE" = "2" ]; then
    opcache_option="--enable-opcache"
else
    opcache_option=""
fi

# --enable-werror \ commenting out due to dynasm errors

./configure \
    --with-config-file-path="$PHP_SOURCE_PATH" \
    --with-config-file-scan-dir="$PHP_SOURCE_PATH/conf.d" \
    --enable-option-checking=fatal \
    --disable-debug \
    --enable-mbstring \
    --with-mysqli=mysqlnd  \
    --enable-mysqlnd \
    --with-pdo-sqlite=/usr \
    --with-sqlite3=/usr \
    --with-curl \
    --with-libedit \
    $opcache_option \
    --with-openssl \
    --with-zlib \
    --enable-cgi \
    --with-valgrind || cat ./config.log

make -j "$(nproc)"

mkdir -p "$PHP_SOURCE_PATH/conf.d/"
cp "$PROJECT_ROOT/build/custom-php.ini" "$PHP_SOURCE_PATH/conf.d/zz-custom-php.ini"

sed -i "s/OPCACHE_ENABLED/$PHP_OPCACHE/g" "$PHP_SOURCE_PATH/conf.d/zz-custom-php.ini"

if [[ "$PHP_JIT" = "1" ]]; then
    sed -i "s/JIT_MODE/tracing/g" "$PHP_SOURCE_PATH/conf.d/zz-custom-php.ini"
    sed -i "s/JIT_BUFFER_SIZE/64M/g" "$PHP_SOURCE_PATH/conf.d/zz-custom-php.ini"
else
    sed -i "s/JIT_MODE/disable/g" "$PHP_SOURCE_PATH/conf.d/zz-custom-php.ini"
    sed -i "s/JIT_BUFFER_SIZE/0/g" "$PHP_SOURCE_PATH/conf.d/zz-custom-php.ini"
fi

# Ensure about correct config

if [ "$PHP_OPCACHE" = "2" ]; then
    opcache="-d zend_extension=$PHP_SOURCE_PATH/modules/opcache.so"
else
    opcache=""
fi

php_cli_executable="$PHP_SOURCE_PATH/sapi/cli/php $opcache"

$php_cli_executable -m
$php_cli_executable -i

if $php_cli_executable -i | grep -q "opcache.enable => On"; then
    opcache_enabled=1
else
    opcache_enabled=0
fi

jit_enabled=0
if $php_cli_executable -i | grep -q "opcache.jit => tracing"; then
    if $php_cli_executable -i | grep -q "opcache.jit_buffer_size => 64"; then
        jit_enabled=1
    fi
fi

if [[ -n "$PHP_OPCACHE" && "$opcache_enabled" = "0" ]]; then
    echo "OPCache should be enabled"
    exit 1
elif [[ -z "$PHP_OPCACHE" && "$opcache_enabled" = "1" ]]; then
    echo "OPCache should not be enabled"
    exit 1
fi

if [[ "$PHP_JIT" = "1" ]]; then
    if [[ "$jit_enabled" = "0" ]]; then
        echo "JIT should be enabled"
        exit 1
    fi
fi

if [[ "$PHP_JIT" = "0" ]]; then
    if [[ "$jit_enabled" = "1" ]]; then
        echo "JIT should not be enabled"
        exit 1
    fi
fi
