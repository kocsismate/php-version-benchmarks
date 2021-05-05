#!/bin/sh
set -e

# persistent / runtime deps
sudo yum update -y
sudo yum groupinstall -y "Development Tools"
sudo yum install -y \
    util-linux \
    autoconf \
    file \
    gcc \
    gcc-c++ \
    libc-dev \
    make \
    pkg-config \
    re2c \
    bison \
    ca-certificates \
    xz-utils \
    dirmngr \
    libargon2-devel \
    libcurl-devel \
    libedit-devel \
    oniguruma-devel \
    libsodium \
    libsodium-devel \
    sqlite-devel \
    libxml2-devel \
    openssl-devel \
    zlib-devel
