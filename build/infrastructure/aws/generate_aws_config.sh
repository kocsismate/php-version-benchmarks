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

disable_deeper_c_states="false"
if [[ "$INFRA_DISABLE_DEEPER_C_STATES" == "1" ]]; then
    disable_deeper_c_states="true"
fi

disable_turbo_boost="false"
if [[ "$INFRA_DISABLE_TURBO_BOOST" == "1" ]]; then
    disable_turbo_boost="true"
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
disable_turbo_boost = $disable_turbo_boost

infra_id = "$INFRA_ID"
infra_name = "$INFRA_NAME"
environment = "$INFRA_ENVIRONMENT"
runner = "$INFRA_RUNNER"
measure_instruction_count = "$INFRA_MEASURE_INSTRUCTION_COUNT"
docker_registry = "$INFRA_DOCKER_REGISTRY"
docker_repository = "$INFRA_DOCKER_REPOSITORY"
EOF
