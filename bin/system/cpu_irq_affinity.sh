#!/usr/bin/env bash
set -e

source $PROJECT_ROOT/bin/system/lib.sh

dedicate_irq_affinity () {
    sudo systemctl stop irqbalance # Disable automatic distribution of hardware interrupt handling across CPU cores

    local -a cpus=()

    if ls /sys/devices/system/node/node* &>/dev/null; then
         for node in /sys/devices/system/node/node*; do
            local node_id="${node##*node}"
            local cpu_list="$(<"$node/cpulist")"
            local first_cpu="$(first_cpu_from_list "$cpu_list")"
            if [[ "$first_cpu" == "0" ]]; then
                first_cpu="$(( first_cpu + 1 ))"
            fi

            cpus+=("$first_cpu")
        done
    else
        cpus+=("1")
    fi

    # Get all IRQ numbers from /proc/interrupts (skip lines without IRQ numbers)
    local irq_numbers="$(grep -E 'nvme|eth|ena|ens|enp' /proc/interrupts | cut -d':' -f1)"

    for irq in $irq_numbers; do
        local affinity_file="/proc/irq/$irq/smp_affinity_list"
        if [ ! -f "$affinity_file" ]; then
            echo "Warning: Affinity list file $affinity_file doesn't exist, skipping IRQ $irq"
            continue
        fi

        local cpu_list="$(IFS=,; echo "${cpus[*]}")"

        if echo "$cpu_list" | sudo tee "$affinity_file" > /dev/null 2>&1; then
            echo "Successfully set IRQ $irq"
        else
            echo "Skip: IRQ $irq is read-only or kernel-locked"
        fi
    done
}

verify_irq_affinity_dedication () {
    echo "CPU affinities:"
    local irq_numbers=$(grep -E '^[[:space:]]*[0-9]+:' /proc/interrupts | cut -d':' -f1)
    for irq in $irq_numbers; do
      affinity_file="/proc/irq/$irq/smp_affinity"
      echo "CPU affinity file $affinity_file:"
      cat "$affinity_file"
    done
}

subcommand="$1"

case "$subcommand" in
    "dedicate")
        dedicate_irq_affinity
        ;;

    "verify")
        verify_irq_affinity_dedication
        ;;

    *)
        echo "Invalid subcommand $subcommand"
        exit 1
esac
