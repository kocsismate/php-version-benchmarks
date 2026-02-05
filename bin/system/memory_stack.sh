#!/usr/bin/env bash
set -e

unlimit_stack () {
    echo "$USER soft stack unlimited" | sudo tee -a /etc/security/limits.conf > /dev/null
    echo "$USER hard stack unlimited" | sudo tee -a /etc/security/limits.conf > /dev/null
}

set_unlimited_stack () {
     sudo ulimit -s unlimited
}

subcommand="$1"

case "$subcommand" in
    "unlimit")
        unlimit_stack
        ;;

    "set")
        set_unlimited_stack
        ;;

    *)
        echo "Invalid subcommand $subcommand"
        exit 1
esac
