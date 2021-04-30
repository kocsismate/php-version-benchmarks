#!/usr/bin/env bash
set -e

if [[ "$1" == "local-docker" ]]; then

    cp "$PROJECT_ROOT/.dockerignore" "$GIT_PATH/.dockerignore"
    docker build -f "$PROJECT_ROOT/Dockerfile" -t "php-benchmark-fpm:$NAME-latest" "$GIT_PATH"

elif [[ "$1" == "aws-docker" ]]; then

    while IFS='= ' read var val; do
        if [[ $var == \#* ]]; then
            continue
        elif [[ $val ]]; then
            declare "$var=${val//\"}"
        fi
    done < "$PROJECT_ROOT/build/infrastructure/config/aws.tfvars"

    export GIT_PATH="$PROJECT_ROOT/tmp/$NAME"
    export COMMIT_HASH=`git -C $GIT_PATH rev-parse HEAD`
    export ECR_REGISTRY_ID="$ecr_registry_id"
    export ECR_REPOSITORY_NAME="$ecr_repository_name"

    cp "$PROJECT_ROOT/.dockerignore" "$GIT_PATH/.dockerignore"
    docker build -f "$PROJECT_ROOT/Dockerfile" -t "$ECR_REPOSITORY_NAME:$NAME-latest" "$GIT_PATH"

    aws ecr-public get-login-password --region "us-east-1" | docker login --username AWS --password-stdin "$ECR_REGISTRY_ID"
    docker tag "$ECR_REPOSITORY_NAME:$NAME-latest" "$ECR_REGISTRY_ID/$ECR_REPOSITORY_NAME:$NAME-latest"
    docker push "$ECR_REGISTRY_ID/$ECR_REPOSITORY_NAME:$NAME-latest"

fi

