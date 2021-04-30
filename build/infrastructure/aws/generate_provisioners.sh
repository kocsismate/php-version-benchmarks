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

    export GIT_PATH="$PROJECT_ROOT/tmp/$NAME"
    export ECR_REGISTRY_ID="$ecr_registry_id"
    export ECR_REPOSITORY_NAME="$ecr_repository_name"

    remote_config_name=`basename $config`

    PROVISIONER=$(cat <<EOF


    provisioner "remote-exec" {
        inline = [
            "set -e",

            "export CONFIG_FILE=/php-benchmark/config/$remote_config_name",
            ". \$CONFIG_FILE",
            "export \$(cut -d= -f1 \$CONFIG_FILE)",

            "export PROJECT_ROOT=/php-benchmark",
            "export RUN=$RUN",
            "export NOW=$NOW",
            ". \$PROJECT_ROOT/.env",
            "export \$(cut -d= -f1 \$PROJECT_ROOT/.env)",

            "export GIT_PATH=\$PROJECT_ROOT/tmp/$NAME",
            "export ECR_REGISTRY_ID=$ECR_REGISTRY_ID",
            "export ECR_REPOSITORY_NAME=$ECR_REPOSITORY_NAME",

            "\$PROJECT_ROOT/bin/benchmark.sh aws-docker",
        ]
    }

    provisioner "local-exec" {
        command = <<EOP
            set -e

            ssh-keyscan -H "\${aws_instance.client.public_dns}" >> ~/.ssh/known_hosts

            mkdir -p "$PROJECT_ROOT/result/$NOW/$RUN/$NAME"
            scp -i "$PROJECT_ROOT/build/infrastructure/config/\${var.ssh_private_key}" -r "\${var.client_ssh_user}@\${aws_instance.client.public_dns}:/php-benchmark/result/$NOW/$RUN/$NAME" "$PROJECT_ROOT/result/$NOW/$RUN"
        EOP
    }

EOF
)

    export PROVISIONERS="$PROVISIONERS$PROVISIONER"
done

envsubst < $PROJECT_ROOT/build/infrastructure/aws/main.tf.tpl > $PROJECT_ROOT/build/infrastructure/aws/main.tf
