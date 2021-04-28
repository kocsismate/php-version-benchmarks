#!/usr/bin/env bash
set -e

PROVISIONERS=""

for config in $PROJECT_ROOT/config/*.ini; do
    source "$config"
    if [[ "$ENABLED" == "0" ]]; then
        continue
    fi

    while IFS='= ' read var val; do
        if [[ $var == \#* ]]; then
            continue
        elif [[ $val ]]; then
            declare "$var=${val//\"}"
        fi
    done < "$PROJECT_ROOT/build/infrastructure/config/aws.tfvars"

    export GIT_PATH="$PROJECT_ROOT/tmp/$GIT_BRANCH"
    export COMMIT_HASH=`git -C $GIT_PATH rev-parse HEAD`
    export ECR_REGISTRY_ID="$ecr_registry_id"
    export ECR_REPOSITORY_NAME="$ecr_repository_name"

    cp "$PROJECT_ROOT/.dockerignore" "$GIT_PATH/.dockerignore"
    docker build -f "$PROJECT_ROOT/Dockerfile" -t "$ECR_REPOSITORY_NAME:$NAME-latest" "$GIT_PATH"

    aws ecr-public get-login-password --region "us-east-1" | docker login --username AWS --password-stdin "$ECR_REGISTRY_ID"
    docker tag "$ECR_REPOSITORY_NAME:$NAME-latest" "$ECR_REGISTRY_ID/$ECR_REPOSITORY_NAME:$NAME-latest"
    docker push "$ECR_REGISTRY_ID/$ECR_REPOSITORY_NAME:$NAME-latest"

    remote_config_name=`basename $config`

    PROVISIONER=$(cat <<EOF


    provisioner "remote-exec" {
        inline = [
            "set -e",

            "export CONFIG_FILE=/php-benchmark/config/$remote_config_name",
            ". \$CONFIG_FILE",
            "export \$(cut -d= -f1 \$CONFIG_FILE)",

            "export PROJECT_ROOT=/php-benchmark",
            ". \$PROJECT_ROOT/.env",
            "export \$(cut -d= -f1 \$PROJECT_ROOT/.env)",

            "export GIT_PATH=\$PROJECT_ROOT/tmp/$NAME",
            "export ECR_REGISTRY_ID=$ECR_REGISTRY_ID",
            "export ECR_REPOSITORY_NAME=$ECR_REPOSITORY_NAME",

            "\$PROJECT_ROOT/bin/provision.sh aws-docker",
        ]
    }

    provisioner "local-exec" {
        command = <<EOP
            set -e

            CONFIG_FILE="$config"
            source "$config"
            benchmark_uri="\${aws_instance.client.public_dns}"

            ssh-keyscan -H "\${aws_instance.host.public_dns}" >> ~/.ssh/known_hosts
            SSH_CMD="export PROJECT_ROOT='/php-benchmark/'; export benchmark_uri='\${aws_instance.client.public_dns}'; export NAME='$NAME'; export PHP_OPCACHE=$PHP_OPCACHE; export PHP_PRELOADING=$PHP_PRELOADING; export PHP_JIT=$PHP_JIT; export AB_REQUESTS=$AB_REQUESTS; export AB_CONCURRENCY=$AB_CONCURRENCY; /php-benchmark/bin/benchmark.sh aws-docker"
            ssh -i "$PROJECT_ROOT/build/infrastructure/config/\${var.ssh_private_key}" "\${var.host_ssh_user}@\${aws_instance.host.public_dns}" "\$SSH_CMD"

            mkdir -p "$PROJECT_ROOT/tmp/result/$NAME"
            scp -i "$PROJECT_ROOT/build/infrastructure/config/\${var.ssh_private_key}" -r "\${var.host_ssh_user}@\${aws_instance.host.public_dns}:/php-benchmark/tmp/result/$NAME" "$PROJECT_ROOT/tmp/result/"
        EOP
    }

    provisioner "remote-exec" {
        inline = [
            "set -e",

            "export PROJECT_ROOT=/php-benchmark",
            "/php-benchmark/bin/deprovision.sh aws-docker",
        ]
    }

EOF
)

    export PROVISIONERS="$PROVISIONERS$PROVISIONER"
done

envsubst < $PROJECT_ROOT/build/infrastructure/aws/main.tf.tpl > $PROJECT_ROOT/build/infrastructure/aws/main.tf
