#!/usr/bin/env bash
set -euo pipefail

detect_nvme () {
    local nvme_name="$(lsblk -ndo NAME,MODEL | awk '/Instance Storage/ {print $1; exit}')"
    local nvme_disk="/dev/$nvme_name"
    local mount_dir="/mnt/nvme"

    if [[ -z "$nvme_name" ]]; then
      echo "No instance store NVMe found"
      exit 0
    fi

    echo "Using instance store: $nvme_disk ($nvme_name)"

    # Get the controller name from the device name: e.g. nvm1n1 -> nvme1
    local controller_name="${nvme_name%n*}"

    local nvme_numa="$(cat "/sys/class/nvme/$controller_name/device/numa_node")"
    [[ "$nvme_numa" == "-1" ]] && nvme_numa=0
    echo "NVMe NUMA node: $nvme_numa"

    echo "export BENCH_NVME_NAME=$nvme_name" >> "$DOT_ENV_FILE"
    echo "export BENCH_NVME_DISK=$nvme_disk" >> "$DOT_ENV_FILE"
    echo "export BENCH_NVME_MOUNT_DIR=$mount_dir" >> "$DOT_ENV_FILE"
    echo "export BENCH_NVME_NUMA=$nvme_numa" >> "$DOT_ENV_FILE"
}

move_dir () {
    local mount_dir="$1"
    local src="$2"
    local dest="${mount_dir}$(dirname "$src")"

    if [[ -L "$src" ]]; then
        echo "[INFO] $src already symlinked, skipping"
        return
    fi

    sudo mkdir -p "$dest"
    sudo mv "$src" "$dest/"
    sudo ln -s "$dest$(basename "$src")" "$src"
    echo "[INFO] Moved $src to NVMe"
}

mount_nvme () {
    local nvme_name="$1"
    local nvme_disk="$2"
    local mount_dir="$3"

    if [[ -z "$nvme_name" ]]; then
      echo "No instance store NVMe found"
      exit 0
    fi

    echo "Using instance store: $nvme_disk ($nvme_name)"

    sudo mkdir -p "$mount_dir"
    sudo mkfs.xfs -f "$nvme_disk"
    sudo mount -o noatime,logbufs=8,logbsize=256k "$nvme_disk" "$mount_dir"

    move_dir "$mount_dir" "$PROJECT_ROOT"

    sudo chown "$USER" "$mount_dir"
    sudo chmod 1775 "$mount_dir"

    echo "none" | sudo tee "/sys/block/$nvme_name/queue/scheduler" > /dev/null
    echo "0" | sudo tee "/sys/block/$nvme_name/queue/read_ahead_kb" > /dev/null
    echo "2" | sudo tee "/sys/block/$nvme_name/queue/nomerges" > /dev/null
}

subcommand="$1"

case "$subcommand" in
    "detect")
        detect_nvme
        ;;

    "mount")
        nvme_name="$2"
        nvme_disk="$3"
        mount_dir="$4"
        mount_nvme "$nvme_name" "$nvme_disk" "$mount_dir"
        ;;

    *)
        echo "Invalid subcommand $subcommand"
        exit 1
esac
