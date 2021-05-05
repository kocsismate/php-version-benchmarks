#!/usr/bin/env bash
set -e

use_dedicated_instance="false"
if [[ "$INFRA_DEDICATED_INSTANCE" == "1" ]]; then
    use_dedicated_instance="true"
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
result_root_dir = "$RESULT_ROOT_DIR"
local_project_root = "$PROJECT_ROOT"
php_commits = "$php_commits"

instance_type = "$INFRA_INSTANCE_TYPE"
image_architecture = "$INFRA_ARCHITECTURE"
use_dedicated_instance = $use_dedicated_instance
disable_turbo_boost = $disable_turbo_boost

infra_name = "$INFRA_NAME"
environment = "$INFRA_ENVIRONMENT"
provisioner = "$INFRA_PROVISIONER"
docker_registry = "$INFRA_DOCKER_REGISTRY"
docker_repository = "$INFRA_DOCKER_REPOSITORY"
EOF
