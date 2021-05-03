#!/bin/sh

gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)";
debMultiarch="$(dpkg-architecture --query DEB_BUILD_MULTIARCH)";

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
