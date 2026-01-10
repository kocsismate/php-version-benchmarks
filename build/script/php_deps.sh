#!/bin/sh
set -e

sudo dnf install --allowerasing -y \
    util-linux \
    kernel-tools \
    autoconf \
    file \
    htop \
    gcc14 \
    gcc14-c++ \
    glibc-devel \
    make \
    pkg-config \
    re2c \
    bison \
    valgrind-devel \
    ca-certificates \
    xz \
    dirmngr \
    libcgroup-tools \
    libargon2-devel \
    libcurl-devel \
    libedit-devel \
    libsodium-devel \
    oniguruma-devel \
    sqlite-devel \
    libxml2-devel \
    openssl-devel \
    libicu-devel \
    rsync \
    zlib-devel \
    time \
    wget \
    bc

# Add the following lines to install jemalloc:
# jemalloc \
# jemalloc-devel \
