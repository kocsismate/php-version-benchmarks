#!/usr/bin/env bash
set -e

php_target_path="$1"
php_alignment="$2"
php_linking_order="$3"
cpu_count="$4"

# -fno-pic: does not generate position-independent code (for shared libraries).
# -fno-pie: no runtime indirection from PIE.
# -O2: predictable, stable optimizations.
# -fno-asynchronous-unwind-tables: no runtime metadata noise.

# Other options tried out:
# -fno-stack-protector: no canaries (consistent stack layout).
# -fno-plt: removes PLT indirection variance.
# -fexcess-precision=standard / -ffp-contract=off: FP operations consistent across runs.
cflags="-fno-pic -fno-pie -O2 -fno-asynchronous-unwind-tables -frandom-seed=1"
if [[ "$php_alignment" -ne "0" ]]; then
    cflags="$cflags -falign-functions=$php_alignment -falign-loops=$php_alignment -falign-jumps=$php_alignment"
fi
cppflags="$cflags"
# Enable linker optimization (this sorts the hash buckets to improve cache locality, and is non-default)
# -Wl,-O1: stable section ordering.
# -no-pie: reinforces non-PIE binary.
# --build-id=none: removes build ID hash (avoids layout differences).
ldflags="-fuse-ld=lld -Wl,-O1 -no-pie -Wl,--build-id=none"
if [[ "$php_linking_order" -ne "0" ]]; then
    seed="$(shuf -i 1-9999 -n 1)"
    ldflags="$ldflags -Wl,--shuffle-sections=.text=$seed"
fi
export SOURCE_DATE_EPOCH=0

cd "$php_target_path"

./buildconf

if git merge-base --is-ancestor "7b4c14dc10167b65ce51371507d7b37b74252077" HEAD > /dev/null 2>&1; then
    opcache_option=""
else
    opcache_option="--enable-opcache"
fi

# --enable-werror \ commenting out due to dynasm errors

CFLAGS=$cflags CPPFLAGS=$cppflags LDFLAGS=$ldflags ./configure \
    --with-config-file-path="$php_target_path" \
    --with-config-file-scan-dir="$php_target_path/conf.d" \
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

OPCACHE_FILE_PATH="$php_target_path/opcache_files"
mkdir -p "$OPCACHE_FILE_PATH"

make -j "$cpu_count"

mkdir -p "$php_target_path/conf.d/"
cp "$PROJECT_ROOT/build/custom-php.ini" "$php_target_path/conf.d/zz-custom-php.ini"

sed -i "s|OPCACHE_FILE_PATH|$OPCACHE_FILE_PATH|g" "$php_target_path/conf.d/zz-custom-php.ini"

if [[ "$PHP_JIT" = "1" ]]; then
    sed -i "s/JIT_MODE/tracing/g" "$php_target_path/conf.d/zz-custom-php.ini"
    sed -i "s/JIT_BUFFER_SIZE/64M/g" "$php_target_path/conf.d/zz-custom-php.ini"
else
    sed -i "s/JIT_MODE/disable/g" "$php_target_path/conf.d/zz-custom-php.ini"
    sed -i "s/JIT_BUFFER_SIZE/0/g" "$php_target_path/conf.d/zz-custom-php.ini"
fi
