#!/bin/sh
set -e

sudo dnf install --allowerasing -y \
    util-linux \
    kernel-tools \
    kexec-tools \
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
    perf \
    wget \
    bc

# Add the following lines to install jemalloc:
# jemalloc \
# jemalloc-devel \

GCC14_PATH="$(which gcc14-gcc)"
echo "Creating symlink for $GCC14_PATH"
sudo ln -s "$GCC14_PATH" /usr/local/bin/gcc
ls -la /usr/local/bin/gcc || true

git clone https://github.com/intel/intel-cmt-cat.git "/tmp/intel-cmt-cat"
git --git-dir=/tmp/intel-cmt-cat/.git --work-tree=/tmp/intel-cmt-cat checkout v25.04
(cd /tmp/intel-cmt-cat && make CC=gcc14-gcc && sudo make install)

echo "/usr/local/lib" | sudo tee /etc/ld.so.conf.d/local.conf
sudo ldconfig
