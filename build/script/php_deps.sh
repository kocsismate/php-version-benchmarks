#!/usr/bin/env bash
set -e

sudo dnf install --allowerasing -y \
    util-linux \
    kernel-tools \
    kexec-tools \
    autoconf \
    git \
    docker \
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
    bc \
    nano

sudo usermod -a -G docker "$USER"

# Add the following lines to install jemalloc:
# jemalloc \
# jemalloc-devel \

GCC_PATH="$(which gcc14-gcc)"
echo "Creating symlink for $GCC_PATH"
sudo ln -s "$GCC_PATH" /usr/local/bin/gcc

G_PLUS_PLUS_PATH="$(which gcc14-c++)"
echo "Creating symlink for $G_PLUS_PLUS_PATH"
sudo ln -s "$G_PLUS_PLUS_PATH" /usr/local/bin/g++

cpu_rdt_support="$(grep -E "rdt_a|cat_l3|cat_l2|mba|cmt|mbm" "/proc/cpuinfo" || true)"
uname="$(uname -r)"
kernel_support="$(grep "CONFIG_X86_CPU_RESCTRL=y" "/boot/config-$uname" || true)"
if [[ -n "$cpu_rdt_support" && -n "$kernel_support" ]]; then
    echo "Installing intel-cmt-cat..."
    git clone https://github.com/intel/intel-cmt-cat.git "/tmp/intel-cmt-cat"
    git --git-dir=/tmp/intel-cmt-cat/.git --work-tree=/tmp/intel-cmt-cat checkout v25.04
    (cd /tmp/intel-cmt-cat && make CC=gcc14-gcc && sudo make install)

    echo "/usr/local/lib" | sudo tee /etc/ld.so.conf.d/local.conf
    sudo ldconfig
fi
