#!/bin/sh
set -e

sudo dnf update -y
sudo dnf groupinstall -y "Development Tools"
sudo dnf install --allowerasing -y \
    util-linux \
    autoconf \
    file \
    gcc \
    gcc-c++ \
    glibc-devel \
    make \
    pkg-config \
    re2c \
    bison \
    valgrind-devel \
    ca-certificates \
    xz \
    dirmngr \
    libargon2-devel \
    libcurl-devel \
    libedit-devel \
    oniguruma-devel \
    sqlite-devel \
    libxml2-devel \
    openssl-devel \
    rsync \
    zlib-devel \
    time \
    wget \
    bc

# Install Sodium
SODIUM_VERSION="1.0.18"
wget "https://download.libsodium.org/libsodium/releases/libsodium-$SODIUM_VERSION.tar.gz"
wget https://download.pureftpd.org/public_keys/jedi.gpg.asc -O - | gpg --import -
wget "https://download.libsodium.org/libsodium/releases/libsodium-$SODIUM_VERSION.tar.gz.sig" -O - | gpg --verify - "libsodium-$SODIUM_VERSION.tar.gz"

tar -xzf "libsodium-$SODIUM_VERSION.tar.gz"
cd "libsodium-$SODIUM_VERSION"
./configure
make && make check
sudo make install
echo /usr/local/lib | sudo tee /etc/ld.so.conf.d/local.conf
sudo ldconfig
ldconfig -p | grep libsodium
