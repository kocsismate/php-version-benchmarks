#!/usr/bin/env bash
set -e

stop_unnecessary_services () {
    # list based on sudo systemctl list-units --type=service --state=running
    echo "Stopping unnecessary background services..."
    sudo service auditd stop # logs system calls and security events
    sudo systemctl stop chronyd # time synchronization daemon
    sudo service docker stop # Docker service
    sudo systemctl stop containerd.service # container service
    sudo cp -f "$PROJECT_ROOT/build/journald.conf" "/etc/systemd/journald.conf" # optimize journald config
    sudo service systemd-journald restart
    sudo sysctl -w kernel.nmi_watchdog=0
    echo "0" | sudo tee /sys/kernel/mm/ksm/run > /dev/null || true

    sync; echo 3 | sudo tee /proc/sys/vm/drop_caches > /dev/null
}

disable_selinux_checks () {
    sudo setenforce 0
}

reload_kernel () {
    local replacement="nokaslr resctrl"
    replacement="${replacement} $($PROJECT_ROOT/bin/system/cpu_c_states.sh "limit")"
    replacement="${replacement} $($PROJECT_ROOT/bin/system/cpu_isolation.sh "isolate" "$BENCH_PHP_CPU,$BENCH_MYSQL_CPU")"
    replacement="${replacement} $($PROJECT_ROOT/bin/system/cpu_l3_cache.sh "enable")"

    echo "Updating kernel params: $replacement"

    sudo kexec -l /boot/vmlinuz-$(uname -r) \
        --initrd=/boot/initramfs-$(uname -r).img \
        --append="$(cat /proc/cmdline) $replacement"
}

config_perf_stat () {
    sudo sysctl -w kernel.perf_event_paranoid=-1
    sudo sysctl -w kernel.kptr_restrict=0
}

verify () {
    # Verify if CPU cores are isolated
    $PROJECT_ROOT/bin/system/cpu_isolation.sh "verify" "$BENCH_PHP_CPU,$BENCH_MYSQL_CPU"

    # Verify if CPU frequency is locked
    $PROJECT_ROOT/bin/system/cpu_frequency.sh "verify"

    # Verify if turbo boost is disabled
    $PROJECT_ROOT/bin/system/cpu_turbo_boost.sh "verify"

    # Verify if hyperthreading is disabled
    $PROJECT_ROOT/bin/system/cpu_hyper_threading.sh "verify"

    # Verify if C-states are correctly set
    $PROJECT_ROOT/bin/system/cpu_c_states.sh "verify"

    echo "Online CPUs:"
    cat /sys/devices/system/cpu/online

    $PROJECT_ROOT/bin/system/cpu_irq_affinity.sh "verify" "$BENCH_PHP_CPU"

    $PROJECT_ROOT/bin/system/process_cgroup.sh "verify" "php"
    $PROJECT_ROOT/bin/system/process_cgroup.sh "verify" "mysql"

    echo "NUMA settings:"
    lscpu | grep NUMA

    $PROJECT_ROOT/bin/system/memory_aslr.sh "verify"

    echo "System limits:"
    ulimit -a

    $PROJECT_ROOT/bin/system/memory_huge_pages.sh "verify"

    echo "TOP 25 processes:"
    ps -eo pid,ppid,cmd,%cpu,%mem --sort=-%cpu | head -n 26

    echo "CPU temperatures:"
    $PROJECT_ROOT/bin/system/cpu_temp_pretty.sh "$BENCH_PHP_CPU"
}

step="$1"

if [[ "$step" == "step1" ]]; then

    $PROJECT_ROOT/bin/system/storage_nvme.sh "detect"
    source "$DOT_ENV_FILE"
    $PROJECT_ROOT/bin/system/memory_stack.sh "unlimit"
    $PROJECT_ROOT/bin/system/memory_huge_pages.sh "unlimit"
    stop_unnecessary_services
    $PROJECT_ROOT/bin/system/cpu_selection.sh "select" "$BENCH_NVME_NUMA"
    source "$DOT_ENV_FILE"
    reload_kernel

elif [[ "$step" == "step2" ]]; then

    $PROJECT_ROOT/bin/system/storage_nvme.sh "mount" "$BENCH_NVME_NAME" "$BENCH_NVME_DISK" "$BENCH_NVME_MOUNT_DIR"
    $PROJECT_ROOT/bin/system/process_cgroup.sh "create" "mysql" "$BENCH_MYSQL_CPU"

elif [[ "$step" == "step3" ]]; then

    $PROJECT_ROOT/bin/system/cpu_hyper_threading.sh "disable"
    $PROJECT_ROOT/bin/system/cpu_turbo_boost.sh "disable"
    $PROJECT_ROOT/bin/system/cpu_frequency.sh "lock"
    $PROJECT_ROOT/bin/system/cpu_irq_affinity.sh "dedicate"
    $PROJECT_ROOT/bin/system/cpu_l3_cache.sh "isolate" "$BENCH_PHP_CPU"
    $PROJECT_ROOT/bin/system/process_cgroup.sh "create" "php" "$BENCH_PHP_CPU"
    $PROJECT_ROOT/bin/system/memory_swapping.sh "disable"
    $PROJECT_ROOT/bin/system/memory_aslr.sh "disable"
    stop_unnecessary_services
    disable_selinux_checks
    $PROJECT_ROOT/bin/system/memory_stack.sh "set"
    $PROJECT_ROOT/bin/system/memory_huge_pages.sh "create"
    config_perf_stat

    verify
else

    echo "Invalid system setting type parameter"
    exit 1

fi
