#!/usr/bin/env bash
set -e

disable_hyper_threading () {
    if [[ "$INFRA_DISABLE_HYPER_THREADING" == "1" ]]; then
        echo "Disabling hyperthreading"

        for cpu in $(lscpu -p=CPU,CORE,SOCKET | grep -v '^#' | awk -F, '{core[$2]++; if(core[$2]>1) print $1}'); do
            echo "Disabling CPU core $cpu"
            echo 0 | sudo tee /sys/devices/system/cpu/cpu$cpu/online > /dev/null
        done
    else
        echo "Skipped disabling hyperthreading"
    fi
}

lock_cpu_frequency () {
    if [[ "$INFRA_LOCK_CPU_FREQUENCY" == "1" ]]; then
        cpu_base_frequency_khz="$(cat /sys/devices/system/cpu/cpu0/cpufreq/base_frequency)"
        cpu_base_frequency_mhz="$(( cpu_base_frequency_khz / 1000 ))"

        echo "Locking CPU frequency to $cpu_base_frequency_mhz MHz"
        sudo cpupower frequency-set --min "${cpu_base_frequency_mhz}MHz" --max "${cpu_base_frequency_mhz}MHz" -g performance

        echo "performance" | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference > /dev/null || true
    else
        echo "Skipped locking CPU frequency"
    fi
}

isolate_cpu_l3_cache () {
    local cpu_rdt_support="$(grep -E "rdt_a|cat_l3|cat_l2|mba|cmt|mbm" "/proc/cpuinfo" || true)"
    if [[ -z "$cpu_rdt_support" ]]; then
        echo "Isolating L3 cache is not supported, skipping"
        return
    fi

    local resctrl_supported="$(grep resctrl /proc/filesystems || true)"
    if [[ -z "$resctrl_supported" ]]; then
        echo "Isolating L3 cache is not supported, skipping"
        return
    fi

    echo "Isolating L3 cache for CPU $last_cpu"

    pqos -s

    sudo mkdir -p /sys/fs/resctrl || true
    sudo mount -t resctrl resctrl /sys/fs/resctrl || true

    # 1st class (COS1) gets 4 cache lanes
    sudo pqos -I -e "llc:1=0xf" || true
    # The CPU core running PHP is assigned to these lanes
    sudo pqos -I -a "llc:1=$last_cpu" || true
}

disable_turbo_boost () {
    if [[ "$INFRA_DISABLE_TURBO_BOOST" == "1" ]]; then
        echo "Disabling turbo boost"
        sudo sh -c 'echo 1 > /sys/devices/system/cpu/intel_pstate/no_turbo'
    else
        echo "Skipped disabling turbo boost"
    fi
}

dedicate_irq () {
    sudo systemctl stop irqbalance # Disable automatic distribution of hardware interrupt handling across CPU cores

    # CPU core to dedicate (1 = CPU1)
    local core=0

    # Calculate affinity mask for the core (2^core in hex)
    local mask="$((1 << core))"
    local hex_mask="$(printf '%x\n' $mask)"

    echo "Setting all IRQ affinities to CPU core $core (mask 0x$hex_mask)"

    # Get all IRQ numbers from /proc/interrupts (skip lines without IRQ numbers)
    local irq_numbers="$(grep '[0-9]\+:' /proc/interrupts | cut -d':' -f1)"

    set +e

    for irq in $irq_numbers; do
        local affinity_file="/proc/irq/$irq/smp_affinity"
        if [ -f "$affinity_file" ]; then
            if echo "$hex_mask" | sudo tee "$affinity_file" > /dev/null; then
                echo "Successfully set IRQ $irq affinity to CPU core $core"
            else
                echo "Warning: Affinity file $affinity_file isn't writable, skipping IRQ $irq"
            fi
        else
            echo "Warning: Affinity file $affinity_file doesn't exist, skipping IRQ $irq"
        fi
    done

    set -e
}

assign_cpu_core_to_cgroup () {
    echo "NUMA settings:"
    lscpu | grep NUMA

    local numa_file="/sys/devices/system/cpu/cpu${last_cpu}/numa_node"

    if [[ -f "$numa_file" ]]; then
        numa_node=$(cat "$numa_file")
    else
        echo "Warning: NUMA information file $numa_file does not exist."
        numa_node=0
    fi

    if [[ "$numa_node" == "-1" ]]; then
      echo "CPU core $last_cpu is not assigned to any NUMA node (likely single NUMA node system)."
      numa_node=0
    else
      echo "CPU core $last_cpu belongs to NUMA node $numa_node."
    fi

    # Create dedicated cgroup for the benchmark
    echo "+cpuset" | sudo tee /sys/fs/cgroup/cgroup.subtree_control > /dev/null

    local cgroup_path="/sys/fs/cgroup/bench"
    sudo mkdir -p "$cgroup_path"

    # Assign isolated cores to the cgroup
    echo "Assigning isolated core to the bench cgroup"
    echo "$last_cpu" | sudo tee $cgroup_path/cpuset.cpus > /dev/null
    echo "$numa_node" | sudo tee $cgroup_path/cpuset.mems > /dev/null
}

disable_swapping () {
    echo "Disabling swapping"
    sudo swapoff -a
}

disable_aslr () {
    # Based on https://github.com/php/php-src/pull/13769
    echo "Disabling ASLR"
    sudo sysctl -w kernel.randomize_va_space=0
}

stop_unnecessary_services () {
    # list based on sudo systemctl list-units --type=service --state=running
    echo "Stop unnecessary background services"
    sudo service auditd stop # logs system calls and security events
    sudo systemctl stop chronyd # time synchronization daemon
    sudo service docker stop # Docker service
    sudo systemctl stop containerd.service # container service
    sudo cp -f $PROJECT_ROOT/build/journald.conf /etc/systemd/journald.conf # optimize journald config
    sudo service systemd-journald restart
    sudo sysctl -w kernel.nmi_watchdog=0
    echo "0" | sudo tee /sys/kernel/mm/ksm/run > /dev/null || true
}

disable_selinux_checks () {
    sudo setenforce 0
}

unlimit_stack () {
    echo "$USER soft stack unlimited" | sudo tee -a /etc/security/limits.conf > /dev/null
    echo "$USER hard stack unlimited" | sudo tee -a /etc/security/limits.conf > /dev/null
}

unlimit_memory () {
    echo "$USER soft memlock unlimited" | sudo tee -a /etc/security/limits.conf > /dev/null
    echo "$USER hard memlock unlimited" | sudo tee -a /etc/security/limits.conf > /dev/null
}

reload_kernel () {
    echo "Isolating CPU core $last_cpu"
    local replacement="isolcpus=$last_cpu nohz_full=$last_cpu rcu_nocbs=$last_cpu resctrl rdt=cmt,l3cat,l3mon,mba"

    if [[ "$INFRA_DISABLE_DEEPER_C_STATES" == "1" ]]; then
        echo "Disabling deeper sleep states"
        replacement="${replacement} intel_idle.max_cstate=1 processor.max_cstate=1"
    else
        echo "Skipped disabling deeper sleep states"
    fi

    sudo kexec -l /boot/vmlinuz-$(uname -r) \
        --initrd=/boot/initramfs-$(uname -r).img \
        --append="$(cat /proc/cmdline) $replacement"
}

set_unlimited_stack () {
    sudo ulimit -s unlimited
}

set_huge_pages () {
    echo "1024" | sudo tee -a /proc/sys/vm/nr_hugepages > /dev/null

    local user_group
    user_group="$(id -g "$USER")"
    sudo sysctl -w "vm.hugetlb_shm_group=$user_group"

    echo "never" | sudo tee /sys/kernel/mm/transparent_hugepage/enabled > /dev/null
    echo "never" | sudo tee /sys/kernel/mm/transparent_hugepage/defrag > /dev/null
}

config_perf_stat () {
    sudo sysctl -w kernel.perf_event_paranoid=-1
    sudo sysctl -w kernel.kptr_restrict=0
}

verify () {
    local isolated_cpu_core="$(cat /sys/devices/system/cpu/isolated)"
    if [[ "$isolated_cpu_core" != "$last_cpu" ]]; then
        echo "Error: CPU isolation error ($isolated_cpu_core)"
        exit 1
    fi

    local no_hz_cpu_core="$(cat /sys/devices/system/cpu/nohz_full)"
    if [[ "$no_hz_cpu_core" != "$last_cpu" ]]; then
        echo "Error: CPU NO HZ isolation error ($no_hz_cpu_core)"
        exit 1
    fi

    echo "OK: CPU isolation is correct"

    # Verify if CPU frequency is locked
    cpupower frequency-info
    if [[ "$INFRA_LOCK_CPU_FREQUENCY" == "1" ]]; then
        local info="$(cpupower frequency-info)"

        if echo "$info" | grep -q "The governor \"performance\""; then
            echo "OK: CPU governor is performance"
        else
            echo "Error: CPU governor isn't performance!"
            exit 1
        fi

        local policy_line="$(echo "$info" | grep "current policy:" || true)"
        if [ -z "$policy_line" ]; then
            echo "Error: No CPU governor policy is available"
            exit 1
        fi

        local cpu_min_frequency="$(echo "$policy_line" | sed -E 's/.*within (.*) and .*/\1/' | xargs)"
        local cpu_max_frequency="$(echo "$policy_line" | sed -E 's/.*and (.*)\./\1/' | xargs)"

        if [ "$cpu_min_frequency" == "$cpu_max_frequency" ]; then
            echo "OK: Minimum and maximum frequency are correct ($cpu_max_frequency)"
        else
            echo "Error: Minimum and maximum CPU frequency differ ($cpu_min_frequency and $cpu_max_frequency)"
            exit 1
        fi
    fi

    # Verify if turbo boost is disabled
    if [[ "$INFRA_DISABLE_TURBO_BOOST" == "1" ]]; then
        # Path to the Turbo Boost control file
        local turbo_file="/sys/devices/system/cpu/intel_pstate/no_turbo"

        if [[ ! -f "$turbo_file" ]]; then
          echo "Error: Turbo boost is enabled"
          exit 1
        fi

        local turbo_status="$(cat "$turbo_file")"

        if [[ "$turbo_status" != "1" ]]; then
          echo "Error: Turbo boost is enabled"
          exit 1
        fi

       echo "OK: Turbo boost is disabled."
    fi

    # Verify if hyperthreading is disabled
    if [[ "$INFRA_DISABLE_HYPER_THREADING" == "1" ]]; then
        # Count logical CPUs
        local logical_cpus="$(grep -c ^processor /proc/cpuinfo)"

        # Count physical cores (unique physical_id + core_id pairs)
        local physical_cores="$(awk '/physical id/ {phy=$4} /core id/ {print phy"."$4}' /proc/cpuinfo | sort -u | wc -l)"

        if (( logical_cpus > physical_cores )); then
          echo "Error: Hyperthreading is enabled: there are $logical_cpus logical CPUs, and $physical_cores physical ones)"
          exit 1
       fi

       echo "OK: Hyperthreading is disabled."
    fi

    # Verify if C-state is correctly set
    if [[ "$INFRA_DISABLE_DEEPER_C_STATES" == "1" ]]; then
        local max_c_state="$(cat /sys/module/intel_idle/parameters/max_cstate)"
        if [[ "$max_c_state" != "1" ]]; then
          echo "Error: CPU C-state is incorrect ($max_c_state)"
          exit 1
        fi

        echo "OK: CPU C-state is correctly set"
    fi

    echo "Online CPUs:"
    cat /sys/devices/system/cpu/online

    echo "CPU affinities:"
    irq_numbers=$(grep -E '^[[:space:]]*[0-9]+:' /proc/interrupts | cut -d':' -f1)
    for irq in $irq_numbers; do
      affinity_file="/proc/irq/$irq/smp_affinity"
      echo "CPU affinity file $affinity_file:"
      cat "$affinity_file"
    done

    cgroup_path="/sys/fs/cgroup/bench"
    echo "Cgroup CPU setting:"
    cat $cgroup_path/cpuset.cpus
    echo "Cgroup memory setting:"
    cat $cgroup_path/cpuset.mems

    echo "ASLR:"
    sudo cat /proc/sys/kernel/randomize_va_space

    echo "System limits:"
    ulimit -a

    echo "Huge pages:"
    cat /proc/meminfo | grep "Huge"

    echo "TOP 25 processes:"
    ps -eo pid,ppid,cmd,%cpu,%mem --sort=-%cpu | head -n 26

    echo "CPU temperature:"
    echo "$([ -f /sys/class/thermal/thermal_zone0/temp ] && echo "scale=2; $(cat /sys/class/thermal/thermal_zone0/temp) / 1000" | bc || echo "N/A") °C"
}

disable_hyper_threading

cpu_count="$(nproc)"
last_cpu="$((cpu_count-1))"

echo "CPU core count: $cpu_count"
echo "Benchmark is assigned to CPU core $last_cpu"

if [[ "$1" == "boot" ]]; then
    unlimit_stack
    unlimit_memory
    reload_kernel
elif [[ "$1" == "before_benchmark" ]]; then
    lock_cpu_frequency
    isolate_cpu_l3_cache
    disable_turbo_boost
    dedicate_irq
    assign_cpu_core_to_cgroup
    disable_swapping
    disable_aslr
    stop_unnecessary_services
    disable_selinux_checks
    set_unlimited_stack
    set_huge_pages
    config_perf_stat

    verify
else
    echo "Invalid system setting type parameter"
    exit 1
fi
