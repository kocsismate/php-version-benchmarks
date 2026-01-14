#!/usr/bin/env bash
set -e

export LC_ALL=C
export PROJECT_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [[ "$1" == "run" ]]; then

    if [[ "$2" == "aws" ]]; then
        INFRA_ENVIRONMENT="aws"
    else
        echo "Available environments: aws"
        exit 1
    fi

    infra_count="$(ls 2>/dev/null -Ubad1 -- $PROJECT_ROOT/config/infra/$INFRA_ENVIRONMENT/*.ini | wc -l)"
    infra_count="$(echo "$infra_count" | awk '{$1=$1;print}')"
    if [ "$infra_count" -eq "0" ]; then
        echo "The $PROJECT_ROOT/config/infra/$INFRA_ENVIRONMENT directory should contain at least one .ini file in order to be able to run the benchmark"
        exit 1
    fi

    php_count="$(ls 2>/dev/null -Ubad1 -- $PROJECT_ROOT/config/php/*.ini | wc -l)"
    php_count="$(echo "$php_count" | awk '{$1=$1;print}')"
    if [ "$php_count" -eq "0" ]; then
        echo "The $PROJECT_ROOT/config/php directory should contain at least one .ini file in order to be able to run the benchmark"
        exit 1
    fi

    test_count="$(ls 2>/dev/null -Ubad1 -- $PROJECT_ROOT/config/test/*.ini | wc -l)"
    test_count="$(echo "$test_count" | awk '{$1=$1;print}')"
    if [ "$test_count" -eq "0" ]; then
        echo "The $PROJECT_ROOT/config/test directory should contain at least one .ini file in order to be able to run the benchmark"
        exit 1
    fi

    export N="${3:-1}"
    NOW="$(TZ=UTC date +'%Y-%m-%d %H:%M:%S')"
    export NOW

    DRY_RUN="0";
    if [[ "$4" == "dry-run" ]]; then
        DRY_RUN="1"
    fi
    export DRY_RUN

    RESULT_ROOT_DIR="${NOW//-/_}"
    RESULT_ROOT_DIR="${RESULT_ROOT_DIR// /_}"
    RESULT_ROOT_DIR="${RESULT_ROOT_DIR//:/_}"
    RESULT_ROOT_DIR="$(echo "$NOW" | cut -c1-4)/$RESULT_ROOT_DIR"
    export RESULT_ROOT_DIR
    export INFRA_ENVIRONMENT

    for infra_config in $PROJECT_ROOT/config/infra/$INFRA_ENVIRONMENT/*.ini; do
        source "$infra_config"
        export $(cut -d= -f1 $infra_config)

        $PROJECT_ROOT/bin/build.sh "local"
    done

    for php_config in $PROJECT_ROOT/config/php/*.ini; do
        source "$php_config"
        if [ -z "$PHP_BASE_ID" ]; then
            export PHP_SOURCE_PATH="$PROJECT_ROOT/tmp/$PHP_ID"
        else
            export PHP_SOURCE_PATH="$PROJECT_ROOT/tmp/$PHP_BASE_ID"
        fi

        export "PHP_COMMITS_$PHP_ID=$(git -C "$PHP_SOURCE_PATH" rev-parse HEAD)"
    done

    for RUN in $(seq "$N"); do
        export RUN

        for infra_config in $PROJECT_ROOT/config/infra/$INFRA_ENVIRONMENT/*.ini; do
            source "$infra_config"
            export $(cut -d= -f1 $infra_config)

            $PROJECT_ROOT/bin/provision.sh
        done
    done

    if [[ "$DRY_RUN" -eq "0" ]]; then
        $PROJECT_ROOT/bin/generate_results.sh "$PROJECT_ROOT/tmp/results/$RESULT_ROOT_DIR" "$PROJECT_ROOT/docs/results/$RESULT_ROOT_DIR" "$NOW"
    fi

elif [[ "$1" == "ssh" ]]; then
    host_dns_file="$PROJECT_ROOT/tmp/host_dns.txt"
    if [ ! -f "$host_dns_file" ]; then
        echo "Instance is not yet running"
        exit 1;
    fi

    private_key_file="$PROJECT_ROOT/tmp/ssh-key.pem"
    if [ ! -f "$private_key_file" ]; then
        echo "Instance is not yet running"
        exit 1;
    fi

    host_dns="$(cat "$host_dns_file")"

    ssh -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=10 -i "$private_key_file" "ec2-user@$host_dns" "$2"

elif [[ "$1" == "bisect" ]]; then

    if [[ $# -ne 2 ]]; then
        echo "Usage: ./benchmark.sh bisect <php_bisect_template_name>"
        exit 1
    fi

    php_bisect_template_name="$2"
    php_bisect_template_file="$PROJECT_ROOT/config/php/$php_bisect_template_name.bisect"
    if [ ! -f "$php_bisect_template_file" ]; then
        echo "The $php_bisect_template_file bisect template file doesn't exist"
        exit 1;
    fi

    source "$php_bisect_template_file"
    export $(cut -d= -f1 $php_bisect_template_file)
    export PHP_SOURCE_PATH="$PROJECT_ROOT/tmp/$PHP_ID"

    if [ ! -z "$PHP_COMMIT" ]; then
        echo "The PHP_COMMIT config option is not supported"
        exit 1;
    fi

    if ! [[ "$PHP_BISECT_PARTS" =~ ^[0-9]+$ ]] || [[ "$PHP_BISECT_PARTS" -lt 2 ]]; then
        echo "PHP_BISECT_PARTS must be an integer >= 2"
        exit 1
    fi

    if [ ! -d "$PHP_SOURCE_PATH" ]; then
        $PROJECT_ROOT/build/script/php_source.sh "local"
    else
        git --git-dir="$PHP_SOURCE_PATH/.git" --work-tree="$PHP_SOURCE_PATH" fetch
    fi

    # Collect commits (oldest -> newest)
    php_bisect_commits=()
    php_bisect_commits+=("$PHP_BISECT_COMMIT_FROM")
    while IFS= read -r commit; do
        php_bisect_commits+=("$commit")
    done < <(git --git-dir="$PHP_SOURCE_PATH/.git" --work-tree="$PHP_SOURCE_PATH" rev-list --ancestry-path --reverse "$PHP_BISECT_COMMIT_FROM..$PHP_BISECT_COMMIT_TO")

    php_bisect_commits_total="${#php_bisect_commits[@]}"
    if [[ "$php_bisect_commits_total" -lt "$PHP_BISECT_PARTS" ]]; then
        echo "Not enough php_bisect_commits ($php_bisect_commits_total) for PHP_BISECT_PARTS=$PHP_BISECT_PARTS"
        exit 1
    fi

    echo "Total php_bisect_commits: $php_bisect_commits_total"
    echo "Generating $PHP_BISECT_PARTS checkpoints"

    php_bisect_source_path="$PHP_SOURCE_PATH"

    # Evenly distributed index
    for ((i=0; i<$PHP_BISECT_PARTS; i++)); do
        i_1="$((i + 1))"
        index="$(( (i * (php_bisect_commits_total - 1) + ($PHP_BISECT_PARTS - 1) / 2) / ($PHP_BISECT_PARTS - 1) ))"
        php_bisect_commit="${php_bisect_commits[$index]}"
        php_bisect_ini_file="${php_bisect_template_file}_${i_1}.ini"
        PHP_SOURCE_PATH="${php_bisect_source_path}_${i_1}"

        cat <<EOF > "$php_bisect_ini_file"
PHP_NAME="$PHP_NAME ${i_1}"
PHP_ID=${PHP_ID}_${i_1}
PHP_BASE_ID=$PHP_BASE_ID

PHP_REPO=$PHP_REPO
PHP_BRANCH=$PHP_BRANCH
PHP_COMMIT=$php_bisect_commit

PHP_JIT=$PHP_JIT
EOF

        echo "Created bisect config \"$PHP_NAME ${i_1}\" for commit $php_bisect_commit"
        echo "Checking out source..."
        rm -rf "$PHP_SOURCE_PATH"
        cp -r "$php_bisect_source_path" "$PHP_SOURCE_PATH"
        git --git-dir="$PHP_SOURCE_PATH/.git" --work-tree="$PHP_SOURCE_PATH" checkout --detach "$php_bisect_commit"
    done

elif [[ "$1" == "help" ]]; then

    echo "Usage: ./benchmark.sh run [environment] [runs] [dry-run]"
    echo ""
    echo "Available runners: aws"

else

    echo 'Available subcommands: "run", "ssh", "bisect", "help"!'
    exit 1

fi
