#!/bin/sh
set -e

mkdir -p "$GIT_PATH"

if [ -z "$(ls -A $GIT_PATH)" ]; then

    git clone --depth "$GIT_DEPT" --single-branch --branch="$GIT_BRANCH" -b "$GIT_BRANCH" "$GIT_REPO" "$GIT_PATH"

else
    echo "Up-to-date"
    #(cd "$GIT_PATH" && git fetch --depth 1 && git reset --hard "origin/$GIT_BRANCH" && git clean -dfx)
fi

if [ ! -z "$GIT_COMMIT" ]; then
    (cd $GIT_PATH && git checkout $GIT_COMMIT)
fi
