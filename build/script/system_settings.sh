#!/usr/bin/env bash
set -e

set_boot_parameters () {
    echo "Isolating CPU core $last_cpu"
    replacement="isolcpus=$last_cpu nohz_full=$last_cpu rcu_nocbs=$last_cpu"

    if [[ "$INFRA_DISABLE_DEEPER_C_STATES" == "1" ]]; then
        echo "Disabling deeper sleep states"
        replacement="$replacement intel_idle.max_cstate=1 processor.max_cstate=1"
    else
        echo "Skipped disabling deeper sleep states"
    fi

    sudo sed -i "s/quiet\"/quiet $replacement\"/" /etc/default/grub

    sudo grub2-mkconfig -o /boot/grub2/grub.cfg
}

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
    core=0

    # Calculate affinity mask for the core (2^core in hex)
    mask=$((1 << core))
    hex_mask=$(printf '%x\n' $mask)

    echo "Setting all IRQ affinities to CPU core $core (mask 0x$hex_mask)"

    # Get all IRQ numbers from /proc/interrupts (skip lines without IRQ numbers)
    irq_numbers=$(grep '[0-9]\+:' /proc/interrupts | cut -d':' -f1)

    set +e

    for irq in $irq_numbers; do
        affinity_file="/proc/irq/$irq/smp_affinity"
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

    numa_file="/sys/devices/system/cpu/cpu${last_cpu}/numa_node"

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

    cgroup_path="/sys/fs/cgroup/bench"
    sudo mkdir -p "$cgroup_path"

    # Assign isolated cores to the cgroup
    echo "Assigning isolated core to the bench cgroup"
    echo "$last_cpu" | sudo tee $cgroup_path/cpuset.cpus > /dev/null
    echo "$numa_node" | sudo tee $cgroup_path/cpuset.mems > /dev/null
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
}

disable_selinux_checks () {
    sudo setenforce 0
}

unlimit_stack () {
    echo "$INFRA_IMAGE_USER soft stack unlimited" | sudo tee -a /etc/security/limits.conf > /dev/null
    echo "$INFRA_IMAGE_USER hard stack unlimited" | sudo tee -a /etc/security/limits.conf > /dev/null
}

set_unlimited_stack () {
    sudo ulimit -s unlimited
}
}

verify_boot_parameters () {
    echo "Boot settings:"
    sudo cat /etc/default/grub
}

verify () {
    verify_boot_parameters

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

        local policy_line="$(echo "$info" | grep "current policy:")"
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
        turbo_file="/sys/devices/system/cpu/intel_pstate/no_turbo"

        if [[ ! -f "$turbo_file" ]]; then
          echo "Error: Turbo boost is enabled"
          exit 1
        fi

        turbo_status=$(cat "$turbo_file")

        if [[ "$turbo_status" != "1" ]]; then
          echo "Error: Turbo boost is enabled"
          exit 1
        fi

       echo "OK: Turbo boost is disabled."
    fi

    # Verify if hyperthreading is disabled
    if [[ "$INFRA_DISABLE_HYPER_THREADING" == "1" ]]; then
        # Count logical CPUs
        logical_cpus=$(grep -c ^processor /proc/cpuinfo)

        # Count physical cores (unique physical_id + core_id pairs)
        physical_cores=$(awk '/physical id/ {phy=$4} /core id/ {print phy"."$4}' /proc/cpuinfo | sort -u | wc -l)

        if (( logical_cpus > physical_cores )); then
          echo "Error: Hyperthreading is enabled: there are $logical_cpus logical CPUs, and $physical_cores physical ones)"
          exit 1
       fi

       echo "OK: Hyperthreading is disabled."
    fi

    echo "Online CPUs:"
    cat /sys/devices/system/cpu/online

    echo "CPU affinities:"
    irq_numbers=$(grep '[0-9]\+:' /proc/interrupts | cut -d':' -f1)
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

    echo "TOP 25 processes:"
    ps -eo pid,ppid,cmd,%cpu,%mem --sort=-%cpu | head -n 26
}

disable_hyper_threading

cpu_count="$(nproc)"
last_cpu="$((cpu_count-1))"

echo "CPU core count: $cpu_count"
echo "Benchmark is assigned to CPU core $last_cpu"

if [[ "$1" == "boot" ]]; then
    set_boot_parameters
    unlimit_stack

    verify_boot_parameters
elif [[ "$1" == "before_benchmark" ]]; then
    lock_cpu_frequency
    disable_turbo_boost
    dedicate_irq
    assign_cpu_core_to_cgroup
    disable_aslr
    stop_unnecessary_services
    disable_selinux_checks
    set_unlimited_stack

    verify
else
    echo "Invalid system setting type parameter"
    exit 1
fi
