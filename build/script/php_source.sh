#!/usr/bin/env bash
set -e

mkdir -p "$PHP_SOURCE_PATH"

if [ -z "$(ls -A $PHP_SOURCE_PATH)" ]; then
    git clone --depth "$PHP_CLONE_DEPT" --single-branch --branch="$PHP_BRANCH" "$PHP_REPO" "$PHP_SOURCE_PATH"
else
    echo "Up-to-date"
    #(cd "$PHP_SOURCE_PATH" && git fetch --depth "$GIT_DEPT" && git reset --hard "origin/$GIT_BRANCH" && git clean -dfx)
fi

if [ ! -z "$PHP_COMMIT" ]; then
    (cd $PHP_SOURCE_PATH && git checkout $PHP_COMMIT)
fi
