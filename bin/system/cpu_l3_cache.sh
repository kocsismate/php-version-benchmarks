#!/usr/bin/env bash
set -e

enable_l3_cache_isolation () {
    echo "rdt=cmt,l3cat,l3mon,mba"
}

isolate_l3_cache () {
    local cpu_rdt_support="$(grep -E "rdt_a|cat_l3|cat_l2|mba|cmt|mbm" "/proc/cpuinfo" || true)"
    if [[ -z "$cpu_rdt_support" ]]; then
        echo "Isolating L3 cache is not supported, skipping"
        return 0
    fi

    local resctrl_supported="$(grep resctrl /proc/filesystems || true)"
    if [[ -z "$resctrl_supported" ]]; then
        echo "Isolating L3 cache is not supported, skipping"
        return 0
    fi

    echo "Isolating L3 cache for CPU $PHP_CPU"

    pqos -s

    sudo mkdir -p /sys/fs/resctrl || true
    sudo mount -t resctrl resctrl /sys/fs/resctrl || true

    # 1st class (COS1) gets 4 cache lanes
    sudo pqos -I -e "llc:1=0xf" || true
    # The CPU core running PHP is assigned to these lanes
    sudo pqos -I -a "llc:1=$PHP_CPU" || true
}

subcommand="$1"

case "$subcommand" in
    "enable")
        enable_l3_cache_isolation
        ;;

    "isolate")
        isolate_l3_cache
        ;;

    *)
        echo "Invalid subcommand $subcommand"
        exit 1
esac
