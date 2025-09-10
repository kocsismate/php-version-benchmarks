#!/bin/sh
set -e

sudo dnf install --allowerasing -y \
    util-linux \
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
    rsync \
    zlib-devel \
    time \
    wget \
    jemalloc \
    jemalloc-devel \
    bc \
    perf \
    llvm18 \
    clang \
    ninja-build \
    cmake

git clone https://github.com/llvm/llvm-project.git "/tmp/llvm-project"
cd "/tmp/llvm-project"
git checkout llvmorg-21.1.0

mkdir /tmp/build
cd /tmp/build

cmake -G Ninja ../llvm-project/llvm \
    -DLLVM_ENABLE_PROJECTS="bolt" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr/local \
    -DLLVM_TARGETS_TO_BUILD="X86"

sudo ninja -j$(nproc) install-bolt-stripped

ls -la /usr/local

llvm-bolt --version
perf2bolt --help
