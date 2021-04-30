#!/usr/bin/env bash
set -e

if [[ "$1" == "local-docker" ]]; then

    mkdir -p "$GIT_PATH"

    if [ -z "$(ls -A $GIT_PATH)" ]; then
        git clone --depth "$GIT_DEPT" --single-branch --branch="$GIT_BRANCH" "$GIT_REPO" "$GIT_PATH"
    else
        echo "Up-to-date"
        #(cd "$GIT_PATH" && git fetch --depth "$GIT_DEPT" && git reset --hard "origin/$GIT_BRANCH" && git clean -dfx)
    fi

    if [ ! -z "$GIT_COMMIT" ]; then
        (cd $GIT_PATH && git checkout $GIT_COMMIT)
    fi

elif [[ "$1" == "aws-docker" ]]; then

    mkdir -p "$GIT_PATH"

    #sudo ssh -o StrictHostKeyChecking=no git@github.com
    git clone --depth "$GIT_DEPT" --single-branch --branch="$GIT_BRANCH" "$GIT_REPO" "$GIT_PATH"

    if [ ! -z "$GIT_COMMIT" ]; then
        (cd $GIT_PATH && git checkout $GIT_COMMIT)
    fi

else

    echo 'Available options: "local-docker", "aws-docker"!'
    exit 1

fi
