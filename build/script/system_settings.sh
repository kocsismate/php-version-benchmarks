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

    echo "Isolating L3 cache for CPU $PHP_CPU"

    pqos -s

    sudo mkdir -p /sys/fs/resctrl || true
    sudo mount -t resctrl resctrl /sys/fs/resctrl || true

    # 1st class (COS1) gets 4 cache lanes
    sudo pqos -I -e "llc:1=0xf" || true
    # The CPU core running PHP is assigned to these lanes
    sudo pqos -I -a "llc:1=$PHP_CPU" || true
}

disable_turbo_boost () {
    if [[ "$INFRA_DISABLE_TURBO_BOOST" == "1" ]]; then
        echo "Disabling turbo boost"
        sudo sh -c 'echo 1 > /sys/devices/system/cpu/intel_pstate/no_turbo'
    else
        echo "Skipped disabling turbo boost"
    fi
}

first_cpu_from_list () {
    local cpu_list="$1"

    echo "$cpu_list" | sed 's/-.*//' | sed 's/,.*//'
}

dedicate_irq () {
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
        fi

        if [ ! -w "$affinity_file" ]; then
            echo "Warning: Affinity list file $affinity_file isn't writable, skipping IRQ $irq"
        fi

        local cpu_list="$(IFS=,; echo "${cpus[*]}")"

        if echo "$cpu_list" | sudo tee "$affinity_file" > /dev/null; then
            echo "Successfully set IRQ $irq affinity to CPU core(s) $cpu_list"
        else
            echo "Error: Affinity file $affinity_file couldn't be written, skipping IRQ $irq"
        fi
    done
}

cpu_to_numa_node () {
    local cpu_list="$1"
    local first_cpu="$(first_cpu_from_list "$cpu_list")"

    for node in /sys/devices/system/node/node*; do
        if awk -v cpu="$first_cpu" '
            {
              n=split($0,a,",")
              for(i=1;i<=n;i++){
                if(a[i] ~ "-"){
                  split(a[i],r,"-")
                  if(cpu>=r[1] && cpu<=r[2]) exit 0
                } else {
                  if(cpu==a[i]) exit 0
                }
              }
              exit 1
            }' "$node/cpulist"
        then
            basename "$node" | sed 's/node//'
            return 0
        fi
    done

    echo "0"
}

assign_cpu_cores_to_cgroup () {
    local cpu_list="$1"
    local cgroup_name="$2"

    local numa_node="$(cpu_to_numa_node "$cpu_list")"

    echo "CPU core(s) $cpu_list belong(s) to NUMA node $numa_node."

    # Enable cpuset controller
    echo "+cpuset" | sudo tee /sys/fs/cgroup/cgroup.subtree_control > /dev/null

    local cgroup_path="/sys/fs/cgroup/$cgroup_name"
    sudo mkdir -p "$cgroup_path"

    echo "Assigning CPU(s) $cpu_list to cgroup $cgroup_name"
    echo "$cpu_list" | sudo tee "$cgroup_path/cpuset.cpus" > /dev/null
    echo "$numa_node" | sudo tee "$cgroup_path/cpuset.mems" > /dev/null
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
    sudo cp -f "$PROJECT_ROOT/build/journald.conf" "/etc/systemd/journald.conf" # optimize journald config
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
    echo "Isolating CPU core $MYSQL_CPUS and $PHP_CPU"
    local replacement="isolcpus=$MYSQL_CPUS,$PHP_CPU nohz_full=$MYSQL_CPUS,$PHP_CPU rcu_nocbs=$MYSQL_CPUS,$PHP_CPU nokaslr resctrl rdt=cmt,l3cat,l3mon,mba"

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
    if [[ "$isolated_cpu_core" != "$MYSQL_CPUS,$PHP_CPU" ]]; then
        echo "Error: CPU isolation error ($isolated_cpu_core)"
        exit 1
    fi

    local no_hz_cpu_core="$(cat /sys/devices/system/cpu/nohz_full)"
    if [[ "$no_hz_cpu_core" != "$MYSQL_CPUS,$PHP_CPU" ]]; then
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

    echo "NUMA settings:"
    lscpu | grep NUMA

    cgroup_path="/sys/fs/cgroup/mysql"
    echo "Cgroup CPU setting:"
    cat $cgroup_path/cpuset.cpus
    echo "Cgroup memory setting:"
    cat $cgroup_path/cpuset.mems

    cgroup_path="/sys/fs/cgroup/php"
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

    echo "CPU temperatures:"
    echo "$([ -f /sys/class/thermal/thermal_zone0/temp ] && echo "scale=2; $(cat /sys/class/thermal/thermal_zone0/temp) / 1000" | bc || echo "N/A") °C"
}

MYSQL_CPUS="2"

function check_cpu_cores () {
    disable_hyper_threading

    CPU_COUNT="$(nproc)"
    if [[ "$CPU_COUNT" -lt "4" ]]; then
        echo "At least 4 physical CPU cores are required to run the benchmark ($CPU_COUNT is used)"
        exit 1
    fi

    PHP_CPU="$(( CPU_COUNT - 1 ))"

    echo "CPU core count: $CPU_COUNT"
    echo "MySQL is assigned to CPU core $MYSQL_CPUS"
    echo "PHP is assigned to CPU core $PHP_CPU"
}

if [[ "$1" == "before_kernel_reload" ]]; then
    check_cpu_cores
    unlimit_stack
    unlimit_memory
    reload_kernel
elif [[ "$1" == "after_kernel_reload" ]]; then
    $PROJECT_ROOT/build/script/mount.sh
    assign_cpu_cores_to_cgroup "$MYSQL_CPUS" "mysql"
elif [[ "$1" == "before_benchmark" ]]; then
    check_cpu_cores
    lock_cpu_frequency
    isolate_cpu_l3_cache
    disable_turbo_boost
    dedicate_irq
    assign_cpu_cores_to_cgroup "$PHP_CPU" "php"
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
