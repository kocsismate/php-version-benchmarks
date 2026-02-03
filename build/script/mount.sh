#!/bin/bash
set -euo pipefail

# Detect NVMe
nvme_name="$(lsblk -ndo NAME,MODEL | awk '/Instance Storage/ {print $1; exit}')"
nvme_disk="/dev/$nvme_name"

if [ -z "$nvme_disk" ]; then
  echo "No instance store NVMe found"
  exit 0
fi

echo "Using instance store: $nvme_disk ($nvme_name)"

mount_dir="/mnt/nvme"

sudo mkdir -p "$mount_dir"

sudo mkfs.xfs -f "$nvme_disk"
sudo mount -o noatime,logbufs=8,logbsize=256k "$nvme_disk" "$mount_dir"

move_dir() {
  local src="$1"
  local dest="${mount_dir}$(dirname "$src")"

  if [ -L "$src" ]; then
    echo "[INFO] $src already symlinked, skipping"
    return
  fi

  sudo mkdir -p "$dest"
  sudo mv "$src" "$dest/"
  sudo ln -s "$dest/$(basename "$src")" "$src"
  echo "[INFO] Moved $src to NVMe"
}

move_dir "$PROJECT_ROOT"

sudo chown "$USER" "$mount_dir"
sudo chmod 1775 "$mount_dir"

echo "none" | sudo tee "/sys/block/$nvme_name/queue/scheduler"
#echo "1024" | sudo tee "/sys/block/$nvme_name/queue/nr_requests"
echo "0" | sudo tee "/sys/block/$nvme_name/queue/read_ahead_kb"
echo "2" | sudo tee "/sys/block/$nvme_name/queue/nomerges"
