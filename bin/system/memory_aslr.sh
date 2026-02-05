#!/usr/bin/env bash
set -e

disable_aslr () {
    echo "Disabling ASLR"
    sudo sysctl -w kernel.randomize_va_space=0
}

verify_aslr () {
    echo "ASLR:"
    sudo cat /proc/sys/kernel/randomize_va_space
}

subcommand="$1"

case "$subcommand" in
    "disable")
        disable_aslr
        ;;

    "verify")
        verify_aslr
        ;;

    *)
        echo "Invalid subcommand $subcommand"
        exit 1
esac
