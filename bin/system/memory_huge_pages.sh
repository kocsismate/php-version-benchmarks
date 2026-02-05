#!/usr/bin/env bash
set -e

unlimit_huge_pages () {
    echo "$USER soft memlock unlimited" | sudo tee -a /etc/security/limits.conf > /dev/null
    echo "$USER hard memlock unlimited" | sudo tee -a /etc/security/limits.conf > /dev/null
}

create_huge_pages () {
    echo "1024" | sudo tee -a /proc/sys/vm/nr_hugepages > /dev/null

    local user_group="$(id -g "$USER")"
    sudo sysctl -w "vm.hugetlb_shm_group=$user_group"

    echo "never" | sudo tee /sys/kernel/mm/transparent_hugepage/enabled > /dev/null
    echo "never" | sudo tee /sys/kernel/mm/transparent_hugepage/defrag > /dev/null
}

verify_huge_pages () {
    echo "Huge pages:"
    cat /proc/meminfo | grep "Huge"
}

subcommand="$1"

case "$subcommand" in
    "unlimit")
        unlimit_huge_pages
        ;;

    "create")
        create_huge_pages
        ;;

    "verify")
        verify_huge_pages
        ;;

    *)
        echo "Invalid subcommand $subcommand"
        exit 1
esac
