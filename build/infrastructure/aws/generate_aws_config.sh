#!/usr/bin/env bash
set -e

use_dedicated_host="false"
if [[ "$INFRA_DEDICATED_HOST" == "1" ]]; then
    use_dedicated_host="true"
fi

disable_turbo_boost="false"
if [[ "$INFRA_DISABLED_TURBO_BOOST" == "1" ]]; then
    disable_turbo_boost="true"
fi

cat << EOF > "$PROJECT_ROOT/build/infrastructure/config/custom.tfvars"
runs = $N
run = $RUN
now = "$NOW"
result_root_dir = "$RESULT_ROOT_DIR"
local_project_root = "$PROJECT_ROOT"

instance_type = "$INFRA_INSTANCE_TYPE"
image_architecture = "$INFRA_ARCHITECTURE"
use_dedicated_host = $use_dedicated_host
disable_turbo_boost = $disable_turbo_boost

infra_name = "$INFRA_NAME"
environment = "$INFRA_ENVIRONMENT"
provisioner = "$INFRA_PROVISIONER"
docker_registry = "$INFRA_DOCKER_REGISTRY"
docker_repository = "$INFRA_DOCKER_REPOSITORY"
EOF
