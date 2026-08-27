#!/usr/bin/env bash
set -e

cd "$PHP_SOURCE_PATH"

cflags="-O2 -frandom-seed=1"
ldflags="-Wl,-O1 -Wl,--build-id=sha1"
if [[ "$INFRA_BINARY_LAYOUT_STRATEGY" == "bolt" || "$INFRA_BINARY_LAYOUT_STRATEGY" == "bolt_align" ]]; then
    cflags="$cflags -fpic -fpie -fno-reorder-blocks-and-partition"
    ldflags="$ldflags -pie -Wl,--emit-relocs"

    if git merge-base --is-ancestor "13b83a46cfb810418ed15be89f24d45de884c082" HEAD > /dev/null 2>&1; then
        pic_option="--enable-pic=yes"
    else
        pic_option="--with-pic=yes"
    fi
else
    cflags="$cflags -fno-pic -fno-pie -fno-asynchronous-unwind-tables"
    ldflags="$ldflags -no-pie"
    pic_option=""
fi

cppflags="$cflags"

export SOURCE_DATE_EPOCH=0

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
    $pic_option \
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
