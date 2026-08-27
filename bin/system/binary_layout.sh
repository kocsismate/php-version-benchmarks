#!/usr/bin/env bash
set -e

display_memory_layout () {
    binary="$1"
    name="$2"
    commit="$3"

    echo "Binary section overview of $name (commit: $commit):"

    size "$binary" --format=SysV

    echo "Binary section details of $name (commit: $commit):"

    objdump -h "$binary"
}

subcommand="$1"

case "$subcommand" in
    "display")
        binary="$2"
        name="$3"
        commit="$4"
        display_memory_layout "$binary" "$name" "$commit"
        ;;

    *)
        echo "Invalid subcommand $subcommand" >&2
        exit 1
esac
