#!/usr/bin/env bash
set -e

if [[ "$INFRA_PROVISIONER" == "docker" ]]; then

    tag="$INFRA_DOCKER_REPOSITORY:$PHP_ID-latest"

    cp "$PROJECT_ROOT/.dockerignore" "$PHP_SOURCE_PATH/.dockerignore"
    docker build -f "$PROJECT_ROOT/Dockerfile" -t "$tag" "$PHP_SOURCE_PATH"

    if [[ "$INFRA_ENVIRONMENT" == "aws" ]]; then
        aws ecr-public get-login-password --region "us-east-1" | docker login --username AWS --password-stdin "$INFRA_DOCKER_REGISTRY"
        docker tag "$tag" "$INFRA_DOCKER_REGISTRY/$tag"
        docker push "$INFRA_DOCKER_REGISTRY/$tag"
    fi

fi
