#!/usr/bin/env bash
set -e

sudo dnf update -y

sudo dnf install --allowerasing -y \
    util-linux \
    kernel-tools \
    kexec-tools \
    autoconf \
    git \
    docker \
    file \
    htop \
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
    libicu-devel \
    rsync \
    zlib-devel \
    time \
    perf \
    wget \
    bc

sudo usermod -a -G docker "$USER"

# Add the following lines to install jemalloc:
# jemalloc \
# jemalloc-devel \

cpu_rdt_support="$(cat "/proc/cpuinfo" | grep -E "rdt|cat_l3|cat_l2|mba|cmt|mbm")"
if [[ -n "$cpu_rdt_support" ]]; then
    echo "Installing intel-cmt-cat..."
    git clone https://github.com/intel/intel-cmt-cat.git "/tmp/intel-cmt-cat"
    git --git-dir=/tmp/intel-cmt-cat/.git --work-tree=/tmp/intel-cmt-cat checkout v25.04
    (cd /tmp/intel-cmt-cat && make && sudo make install)

    echo "/usr/local/lib" | sudo tee /etc/ld.so.conf.d/local.conf
    sudo ldconfig
fi
