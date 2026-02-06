#!/usr/bin/env bash
set -e

source $PROJECT_ROOT/bin/system/lib.sh

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

create_cgroup () {
    local cgroup_name="$1"
    local cpu_list="$2"

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

verify_cgroup () {
    local cgroup_name="$1"

    local cgroup_path="/sys/fs/cgroup/$cgroup_name"

    echo "Cgroup $cgroup_name settings:"
    printf "CPU cores: %s\n" "$(cat "$cgroup_path/cpuset.cpus")"
    printf "NUMA node: %s\n" "$(cat "$cgroup_path/cpuset.mems")"
}

subcommand="$1"
cgroup_name="$2"
cpu_list="$3"

case "$subcommand" in
    "create")
        create_cgroup "$cgroup_name" "$cpu_list"
        ;;

    "verify")
        verify_cgroup "$cgroup_name"
        ;;

    *)
        echo "Invalid subcommand $subcommand"
        exit 1
esac
