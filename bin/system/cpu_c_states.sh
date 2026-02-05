#!/usr/bin/env bash
set -e

limit_c_states () {
    if [[ "$INFRA_DISABLE_DEEPER_C_STATES" == "1" ]]; then
        echo "intel_idle.max_cstate=1 processor.max_cstate=1"
    fi
}

verify_c_states_limit () {
    if [[ "$INFRA_DISABLE_DEEPER_C_STATES" == "1" ]]; then
        local max_c_state="$(cat /sys/module/intel_idle/parameters/max_cstate)"
        if [[ "$max_c_state" != "1" ]]; then
          echo "Error: CPU C-state is incorrect ($max_c_state)"
          exit 1
        fi

        echo "OK: CPU C-state is correctly set"
    fi
}

subcommand="$1"

case "$subcommand" in
    "limit")
        limit_c_states
        ;;

    "verify")
        verify_c_states_limit
        ;;

    *)
        echo "Invalid subcommand $subcommand"
        exit 1
esac
