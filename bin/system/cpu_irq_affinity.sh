#!/usr/bin/env bash
set -e

source "$PROJECT_ROOT/bin/system/lib.sh"

dedicate_irq_affinity () {
    # Disable automatic distribution of hardware interrupt handling across CPU cores
    sudo systemctl stop irqbalance

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

    echo "Setting IRQ affinities..."

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

collect_irq_affinities() {
    local -a irqs=()

    for affinity_file in /proc/irq/*/smp_affinity_list; do
        if [[ -f "$affinity_file" ]]; then
            local irq_num="$(echo "$affinity_file" | cut -d'/' -f4)"
            local irq_cpu_list="$(cat "$affinity_file" 2>/dev/null)"
            local parsed_cpu_list="$(parse_cpu_list "$irq_cpu_list")"
            local comma_separated_cpu_list=",${parsed_cpu_list// /,},"
            irqs+=("$irq_num:$comma_separated_cpu_list")
        fi
    done

    echo "${irqs[*]}"
}

list_irq_affinities_for_cpu () {
    local irqs="$1"
    local target_cpu="$2"

    for irq in $irqs; do
        local irq_num="${irq%%:*}"
        local irq_cpus="${irq#*:}"

        if [[ "$irq_cpus" == *",$target_cpu,"* ]]; then
            echo "$irq_num"
        fi
    done
}

analyze_cpu_irq_load () {
    local cpu_range="$1"

    local -a cpu_list=($(parse_cpu_list "$cpu_range"))
    local irq_affininites="$(collect_irq_affinities)"

    local -a cpu_stats=()
    for cpu in "${cpu_list[@]}"; do
        local irq_count="$(list_irq_affinities_for_cpu "$irq_affininites" "$cpu" | grep -c '^')"

        cpu_stats+=("$cpu $irq_count")
    done

    printf "%s\n" "${cpu_stats[@]}" | sort -k2,2n | awk '{print $1 " " $2}'
}

verify_irq_affinities () {
    local target_cpu="$1"

    echo "CPU affinities:"
    local irq_numbers=$(grep -E '^[[:space:]]*[0-9]+:' /proc/interrupts | cut -d':' -f1)
    for irq in $irq_numbers; do
      affinity_file="/proc/irq/$irq/smp_affinity_list"
      echo "CPU affinity file $affinity_file:"
      cat "$affinity_file"
    done

    echo "Affinities for target CPU $target_cpu:"
    local irq_affininites="$(collect_irq_affinities)"
    list_irq_affinities_for_cpu "$irq_affininites" "$target_cpu"

    echo "CPU-Affinity top list:"
    online_cpus="$(cat "/sys/devices/system/cpu/online")"
    analyze_cpu_irq_load "$online_cpus"
}

subcommand="$1"

case "$subcommand" in
    "dedicate")
        dedicate_irq_affinity
        ;;

    "analyze_load")
        cpu_range="$2"

        analyze_cpu_irq_load "$cpu_range"
        ;;

    "verify")
        target_cpu="$2"

        verify_irq_affinities "$target_cpu"
        ;;

    *)
        echo "Invalid subcommand $subcommand"
        exit 1
esac
