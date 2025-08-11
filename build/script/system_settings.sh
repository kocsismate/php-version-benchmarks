#!/usr/bin/env bash
set -e

dedicate_irq () {
    # CPU core to dedicate (1 = CPU1)
    core=1

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

if [[ "$INFRA_DISABLE_HYPER_THREADING" == "1" ]]; then
    for cpunum in $(cat /sys/devices/system/cpu/cpu*/topology/thread_siblings_list | cut -s -d, -f2- | tr ',' '\n' | sort -un); do
        echo 0 | sudo tee /sys/devices/system/cpu/cpu$cpunum/online;
    done
    echo "Disabled hyper threading"
else
    echo "Skipped disabling hyper threading"
fi

if [[ "$INFRA_DISABLE_TURBO_BOOST" == "1" ]]; then
    sudo sh -c 'echo 1 > /sys/devices/system/cpu/intel_pstate/no_turbo'
    echo "Disabled turbo boost"
else
    echo 'Skipped disabling turbo boost'
fi

# Disable ASLR based on https://github.com/php/php-src/pull/13769
sudo sysctl -w kernel.randomize_va_space=0

# Stop unnecessary background services - list based on sudo systemctl list-units --type=service --state=running
sudo service auditd stop # logs system calls and security events
sudo systemctl stop chronyd # time synchronization daemon
sudo service docker stop # Docker service
sudo systemctl stop containerd.service # container service
sudo cp -f $PROJECT_ROOT/build/journald.conf /etc/systemd/journald.conf
sudo service systemd-journald restart
sudo systemctl stop irqbalance # Disable automatic distribution of hardware interrupt handling across CPU cores
dedicate_irq

# Verify CPU, kernel, and OS config
echo 'Grub:'
sudo cat /etc/default/grub

echo 'ASLR:'
sudo cat /proc/sys/kernel/randomize_va_space

echo 'CPU affinities:'
irq_numbers=$(grep '[0-9]\+:' /proc/interrupts | cut -d':' -f1)
for irq in $irq_numbers; do
  affinity_file="/proc/irq/$irq/smp_affinity"
  echo "CPU affinity file $affinity_file:"
  cat "$affinity_file"
done
