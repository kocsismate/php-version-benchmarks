#!/usr/bin/env bash
set -e

dry_run="false"
if [[ "$DRY_RUN" == "1" ]]; then
    dry_run="true"
fi

use_dedicated_instance="false"
if [[ "$INFRA_DEDICATED_INSTANCE" == "1" ]]; then
    use_dedicated_instance="true"
fi

disable_hyper_threading="false"
if [[ "$INFRA_DISABLE_HYPER_THREADING" == "1" ]]; then
    disable_hyper_threading="true"
fi

lock_cpu_frequency="false"
if [[ "$INFRA_LOCK_CPU_FREQUENCY" == "1" ]]; then
    lock_cpu_frequency="true"
fi

disable_deeper_c_states="false"
if [[ "$INFRA_DISABLE_DEEPER_C_STATES" == "1" ]]; then
    disable_deeper_c_states="true"
fi

disable_turbo_boost="false"
if [[ "$INFRA_DISABLE_TURBO_BOOST" == "1" ]]; then
    disable_turbo_boost="true"
fi

measure_instruction_count="false"
if [[ "$INFRA_MEASURE_INSTRUCTION_COUNT" == "1" ]]; then
    measure_instruction_count="true"
fi

debug_environment="false"
if [[ "$INFRA_DEBUG_ENVIRONMENT" == "1" ]]; then
    debug_environment="true"
fi

php_commits=""
for php_config in $PROJECT_ROOT/config/php/*.ini; do
    source $php_config
    var="PHP_COMMITS_$PHP_ID"
    php_commits="${php_commits}export $var=${!var};"
done

cat << EOF > "$PROJECT_ROOT/build/infrastructure/config/custom.tfvars"
runs = $N
run = $RUN
now = "$NOW"
dry_run = $dry_run
result_root_dir = "$RESULT_ROOT_DIR"
local_project_root = "$PROJECT_ROOT"
php_commits = "$php_commits"

instance_type = "$INFRA_INSTANCE_TYPE"
image_architecture = "$INFRA_ARCHITECTURE"
use_dedicated_instance = $use_dedicated_instance
disable_deeper_c_states = $disable_deeper_c_states
disable_hyper_threading = $disable_hyper_threading
lock_cpu_frequency = $lock_cpu_frequency
disable_turbo_boost = $disable_turbo_boost

infra_id = "$INFRA_ID"
infra_name = "$INFRA_NAME"
environment = "$INFRA_ENVIRONMENT"
workspace = "$INFRA_WORKSPACE"
runner = "$INFRA_RUNNER"
measure_instruction_count = "$measure_instruction_count"
debug_environment = "$debug_environment"
docker_registry = "$INFRA_DOCKER_REGISTRY"
docker_repository = "$INFRA_DOCKER_REPOSITORY"
EOF

STATE_CONFIG_FILE="$PROJECT_ROOT/build/infrastructure/config/state.config"
rm -f "$STATE_CONFIG_FILE"

TF_VARS_FILE="$PROJECT_ROOT/build/infrastructure/config/aws.tfvars"

grep "access_key =" "$TF_VARS_FILE" >> "$STATE_CONFIG_FILE"
grep "secret_key =" "$TF_VARS_FILE" >> "$STATE_CONFIG_FILE"
grep "region =" "$TF_VARS_FILE" >> "$STATE_CONFIG_FILE"
bucket="$(grep "state_bucket =" "$TF_VARS_FILE")"
echo "${bucket/state_bucket/bucket}" >> "$STATE_CONFIG_FILE"
echo "key = \"$INFRA_WORKSPACE.tfstate\"" >> "$STATE_CONFIG_FILE"
