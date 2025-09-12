#!/bin/sh
set -e

# -fno-pic: does not generate position-independent code (for shared libraries).
# -fno-pie: no runtime indirection from PIE.
# -O2: predictable, stable optimizations.
# -fno-asynchronous-unwind-tables: no runtime metadata noise.

# Other options tried out:
# -fno-stack-protector: no canaries (consistent stack layout).
# -fno-plt: removes PLT indirection variance.
# -fexcess-precision=standard / -ffp-contract=off: FP operations consistent across runs.
cflags="-fno-pic -fno-pie -O2 -fno-asynchronous-unwind-tables -frandom-seed=1 -ffunction-sections -fdata-sections"
cppflags="$cflags"
# Enable linker optimization (this sorts the hash buckets to improve cache locality, and is non-default)
# -Wl,-O1: stable section ordering.
# -no-pie: reinforces non-PIE binary.
# --build-id=none: removes build ID hash (avoids layout differences).
ldflags="-Wl,-O1 -no-pie -Wl,--build-id=none -Wl,-gc-sections -Wl,-T,/tmp/my.ld"
export CC=gcc14-gcc
export CXX=gcc14-g++
export SOURCE_DATE_EPOCH=0

cd "$PHP_SOURCE_PATH"

# Temporary revert
if git merge-base --is-ancestor "9659f3e53f4d10bf0b596c5143d61c73f1c220a9" HEAD; then
    git revert --no-edit "9659f3e53f4d10bf0b596c5143d61c73f1c220a9"
fi

if git merge-base --is-ancestor "49fdf496e2b6d6348941a7bf0437d5cf89e307f6" HEAD; then
    git revert --no-edit "49fdf496e2b6d6348941a7bf0437d5cf89e307f6"
fi

if git merge-base --is-ancestor "a5f2eee785d99ab97e2bfd877f015608d9e9f94e" HEAD; then
    git revert --no-edit "a5f2eee785d99ab97e2bfd877f015608d9e9f94e"
fi

if git merge-base --is-ancestor "4191843f6ab31077e3916f4a39251d7d6eda9aea" HEAD; then
    git revert --no-edit "4191843f6ab31077e3916f4a39251d7d6eda9aea"
fi

if git merge-base --is-ancestor "f18e99244b675a31a8ee5dea5dbfd75e5abf610a" HEAD; then
    git revert --no-edit "f18e99244b675a31a8ee5dea5dbfd75e5abf610a"
fi

./buildconf

if [ "$PHP_OPCACHE" = "2" ]; then
    opcache_option="--enable-opcache"
else
    opcache_option=""
fi

# --enable-werror \ commenting out due to dynasm errors

CFLAGS=$cflags CPPFLAGS=$cppflags LDFLAGS=$ldflags ./configure \
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
    --with-valgrind

make -j "$1"

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
