#!/bin/sh
set -eux

cat << EOF | sudo tee /etc/apt/preferences.d/no-debian-php
Package: php*
Pin: release *
Pin-Priority: -1
EOF

# dependencies required for running "phpize"
# (see persistent deps below)
PHPIZE_DEPS=autoconf dpkg-dev file g++ gcc libc-dev make pkg-config re2c bison

# persistent / runtime deps
sudo apt-get update
sudo apt-get install -y --no-install-recommends $PHPIZE_DEPS ca-certificates curl xz-utils git
rm -rf /var/lib/apt/lists/*

savedAptMark="$(sudo apt-mark showmanual)"
sudo apt-get update
sudo apt-get install -y --no-install-recommends dirmngr
sudo rm -rf /var/lib/apt/lists/*
sudo apt-mark auto '.*' > /dev/null
sudo apt-mark manual $savedAptMark > /dev/null
sudo apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false

savedAptMark="$(apt-mark showmanual)";
sudo apt-get update
sudo apt-get install -y --no-install-recommends \
    libargon2-dev \
	libcurl4-openssl-dev \
	libedit-dev \
	libonig-dev \
	libsodium-dev \
	libsqlite3-dev \
	libssl-dev \
	libxml2-dev \
	zlib1g-dev
sudo rm -rf /var/lib/apt/lists/*

debMultiarch="$(dpkg-architecture --query DEB_BUILD_MULTIARCH)";
# https://bugs.php.net/bug.php?id=74125
if [ ! -d /usr/include/curl ]; then
	ln -sT "/usr/include/$debMultiarch/curl" /usr/local/include/curl;
fi;
