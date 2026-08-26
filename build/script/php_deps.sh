#!/usr/bin/env bash
set -e

sudo dnf install --allowerasing -y \
    util-linux \
    kernel-tools \
    kexec-tools \
    autoconf271 \
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
    ca-certificates \
    xz \
    gnuplot \
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
    nano \
    nvme-cli

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
    git clone --depth 1 -b v25.04 https://github.com/intel/intel-cmt-cat.git "/tmp/intel-cmt-cat"
    (cd /tmp/intel-cmt-cat && make CC=gcc14-gcc && sudo make install)

    echo "/usr/local/lib" | sudo tee /etc/ld.so.conf.d/local.conf
    sudo ldconfig
fi

if [[ "$INFRA_BINARY_LAYOUT_STRATEGY" == "bolt" || "$INFRA_BINARY_LAYOUT_STRATEGY" == "bolt_align" ]]; then
    sudo dnf install --allowerasing -y \
        lld \
        clang \
        cmake \
        llvm18 \
        ninja-build

    git clone --depth 1 -b bolt-align-fix https://github.com/kocsismate/llvm-project "/tmp/llvm-project"

    mkdir /tmp/build
    cd /tmp/build

    if [[ "$INFRA_ARCHITECTURE" == "x86_64" ]]; then
        llvm_target="X86"
    elif [[ "$INFRA_ARCHITECTURE" == "arm64" ]]; then
        llvm_target="AArch64"
    else
        echo "Unsupported architecture $INFRA_ARCHITECTURE for compiling LLVM" >&2
        exit 1
    fi

    cmake -G Ninja ../llvm-project/llvm \
        -DLLVM_ENABLE_PROJECTS="bolt" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DLLVM_TARGETS_TO_BUILD="$llvm_target" \
        -DLLVM_USE_LINKER=lld \
        -DCMAKE_C_COMPILER=clang \
        -DCMAKE_CXX_COMPILER=clang++

    ninja -t targets all | grep -i bolt

    sudo ninja -j$(nproc) install-bolt-stripped

    ls -la /usr/local

    llvm-bolt --version
    perf2bolt --version
    llvm-bolt-align --version
fi
