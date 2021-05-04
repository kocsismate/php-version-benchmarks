#!/usr/bin/env bash
set -e

find -type f -name '*.a' -delete
find /usr/local/bin /usr/local/sbin -type f -executable -exec strip --strip-all '{}' + || true
make clean

# reset apt-mark's "manual" list so that "purge --auto-remove" will remove all build dependencies
sudo apt-mark auto '.*' > /dev/null
[ -z "$savedAptMark" ] || apt-mark manual $savedAptMark;
find /usr/local -type f -executable -exec ldd '{}' ';' \
		| awk '/=>/ { print $(NF-1) }' \
		| sort -u \
		| xargs -r dpkg-query --search \
		| cut -d: -f1 \
		| sort -u \
		| xargs -r apt-mark manual

sudo apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false
pecl update-channels
rm -rf /tmp/pear ~/.pearrc

# temporary "freetype-config" workaround for https://github.com/docker-library/php/issues/865 (https://bugs.php.net/bug.php?id=76324)
{ echo '#!/bin/sh'; echo 'exec pkg-config "$@" freetype2'; } > /usr/local/bin/freetype-config && chmod +x /usr/local/bin/freetype-config
