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
    libcgroup-tools \
    libargon2-devel \
    libcurl-devel \
    libedit-devel \
    libsodium-devel \
    oniguruma-devel \
    sqlite-devel \
    libxml2-devel \
    openssl-devel \
    rsync \
    zlib-devel \
    time \
    wget \
    bc
