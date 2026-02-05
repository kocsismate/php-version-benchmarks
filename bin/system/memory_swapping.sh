#!/usr/bin/env bash
set -e

disable_swapping () {
    echo "Disabling swapping"
    sudo swapoff -a
}

subcommand="$1"

case "$subcommand" in
    "disable")
        disable_swapping
        ;;

    *)
        echo "Invalid subcommand $subcommand"
        exit 1
esac
