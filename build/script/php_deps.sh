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
    ca-certificates \
    xz \
    dirmngr \
    libargon2-devel \
    libcurl-devel \
    libedit-devel \
    oniguruma-devel \
    libsodium \
    libsodium-devel \
    sqlite-devel \
    libxml2-devel \
    openssl1.1-devel \
    rsync \
    zlib-devel \
    time \
    bc
