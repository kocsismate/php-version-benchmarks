#!/usr/bin/env bash
set -euo pipefail

move_dir () {
    local mount_dir="$1"
    local src="$2"
    local dest
    dest="${mount_dir}$(dirname "$src")"

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
    local target_numa="$1"
    local mount_dir="/mnt/nvme"
    local nvme_name=""

    while IFS= read -r candidate; do
        local candidate_disk="/dev/$candidate"

        if grep -q "^${candidate_disk}" /proc/mounts; then
            echo "Skipping $candidate_disk: has mounted partitions"
            continue
        fi

        if [[ -n "$target_numa" ]]; then
            local controller_name="${candidate%n*}"
            local candidate_numa
            candidate_numa="$(cat "/sys/class/nvme/$controller_name/device/numa_node")"
            [[ "$candidate_numa" == "-1" ]] && candidate_numa=0

            if [[ "$candidate_numa" != "$target_numa" ]]; then
                echo "Skipping $candidate_disk: NUMA node $candidate_numa != $target_numa"
                continue
            fi
        fi

        nvme_name="$candidate"
        break
    done < <(lsblk -ndo NAME,MODEL | awk '/Instance Storage/ {print $1}')

    if [[ -z "$nvme_name" ]]; then
        echo "No instance store NVMe found"
        exit 0
    fi

    local nvme_disk="/dev/$nvme_name"

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
    "mount")
        target_numa="$2"
        mount_nvme "$target_numa"
        ;;

    *)
        echo "Invalid subcommand $subcommand"
        exit 1
esac
