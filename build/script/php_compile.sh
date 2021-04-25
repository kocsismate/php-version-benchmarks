#!/bin/sh

set -eux; \
	{ \
		echo 'Package: php*'; \
		echo 'Pin: release *'; \
		echo 'Pin-Priority: -1'; \
	} > /etc/apt/preferences.d/no-debian-php

# dependencies required for running "phpize"
# (see persistent deps below)
PHPIZE_DEPS=autoconf dpkg-dev file g++ gcc libc-dev make pkg-config re2c bison

# persistent / runtime deps
set -eux
apt-get update
apt-get install -y --no-install-recommends $PHPIZE_DEPS ca-certificates curl xz-utils git
rm -rf /var/lib/apt/lists/*

# Apply stack smash protection to functions using local buffers and alloca()
# Make PHP's main executable position-independent (improves ASLR security mechanism, and has no performance impact on x86_64)
# Enable optimization (-O2)
# Enable linker optimization (this sorts the hash buckets to improve cache locality, and is non-default)
# https://github.com/docker-library/php/issues/272
# -D_LARGEFILE_SOURCE and -D_FILE_OFFSET_BITS=64 (https://www.php.net/manual/en/intro.filesystem.php)
PHP_CFLAGS="-fstack-protector-strong -fpic -fpie -O2 -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64"
PHP_CPPFLAGS="$PHP_CFLAGS"
PHP_LDFLAGS="-Wl,-O1 -pie"

savedAptMark="$(apt-mark showmanual)"
apt-get update
apt-get install -y --no-install-recommends dirmngr
rm -rf /var/lib/apt/lists/*
apt-mark auto '.*' > /dev/null
apt-mark manual $savedAptMark > /dev/null
apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false

cp . /usr/src/php/$NAME
PHP_INI_DIR=/usr/local/etc/php

mkdir -p "$PHP_INI_DIR/conf.d"
# allow running as an arbitrary user (https://github.com/docker-library/php/issues/743)
[ ! -d /var/www/html ]
mkdir -p /var/www/html
chown www-data:www-data /var/www/html
chmod 777 /var/www/html

savedAptMark="$(apt-mark showmanual)";
apt-get update
apt-get install -y --no-install-recommends \
    libargon2-dev \
	libcurl4-openssl-dev \
	libedit-dev \
	libonig-dev \
	libsodium-dev \
	libsqlite3-dev \
	libssl-dev \
	libxml2-dev \
	zlib1g-dev
rm -rf /var/lib/apt/lists/*
export CFLAGS="$PHP_CFLAGS" \
    CPPFLAGS="$PHP_CPPFLAGS" \
	LDFLAGS="$PHP_LDFLAGS"

gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)";
debMultiarch="$(dpkg-architecture --query DEB_BUILD_MULTIARCH)";
# https://bugs.php.net/bug.php?id=74125
if [ ! -d /usr/include/curl ]; then
	ln -sT "/usr/include/$debMultiarch/curl" /usr/local/include/curl;
fi;
cd /usr/src/php/$NAME;
    ./buildconf; \
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
		--enable-fpm \
        --with-fpm-user=www-data \
        --with-fpm-group=www-data \
        --disable-cgi \
        --with-pear

make -j "$(nproc)"
find -type f -name '*.a' -delete
make install
find /usr/local/bin /usr/local/sbin -type f -executable -exec strip --strip-all '{}' + || true
make clean

cp -v php.ini-* "$PHP_INI_DIR/"
# reset apt-mark's "manual" list so that "purge --auto-remove" will remove all build dependencies
apt-mark auto '.*' > /dev/null
[ -z "$savedAptMark" ] || apt-mark manual $savedAptMark;
find /usr/local -type f -executable -exec ldd '{}' ';' \
		| awk '/=>/ { print $(NF-1) }' \
		| sort -u \
		| xargs -r dpkg-query --search \
		| cut -d: -f1 \
		| sort -u \
		| xargs -r apt-mark manual

apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false
pecl update-channels
rm -rf /tmp/pear ~/.pearrc
# smoke test
php --version

# temporary "freetype-config" workaround for https://github.com/docker-library/php/issues/865 (https://bugs.php.net/bug.php?id=76324)
{ echo '#!/bin/sh'; echo 'exec pkg-config "$@" freetype2'; } > /usr/local/bin/freetype-config && chmod +x /usr/local/bin/freetype-config
