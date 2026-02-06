#!/usr/bin/env bash
set -e

disable_cpu_hyper_threading () {
    if [[ "$INFRA_DISABLE_HYPER_THREADING" == "1" ]]; then
        echo "Disabling hyperthreading..."

        for cpu in $(lscpu -p=CPU,CORE,SOCKET | grep -v '^#' | awk -F, '{core[$2]++; if(core[$2]>1) print $1}'); do
            echo "Disabling CPU core $cpu..."
            echo 0 | sudo tee /sys/devices/system/cpu/cpu$cpu/online > /dev/null
        done
    else
        echo "Skipped disabling hyperthreading"
    fi
}

verify_cpu_hyper_threading () {
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
}

subcommand="$1"

case "$subcommand" in
    "disable")
        disable_cpu_hyper_threading
        ;;

    "verify")
        verify_cpu_hyper_threading
        ;;

    *)
        echo "Invalid subcommand $subcommand"
        exit 1
esac
