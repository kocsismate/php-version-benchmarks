#!/usr/bin/env bash
set -e

mkdir -p "$PHP_SOURCE_PATH"

if [ "$1" == "local" ]; then
    if [ -z "$(ls -A $PHP_SOURCE_PATH)" ]; then
        if [ -z "$PHP_BASE_SOURCE_PATH" ]; then
            git clone "$PHP_REPO" "$PHP_SOURCE_PATH"
            (cd $PHP_SOURCE_PATH && git checkout "$PHP_BRANCH")
        else
            echo "Creating source ($PHP_SOURCE_PATH) from base source ($PHP_BASE_SOURCE_PATH)"
            cp -r "$PHP_BASE_SOURCE_PATH/" "$PHP_SOURCE_PATH"
        fi
    else
        (cd $PHP_SOURCE_PATH && git checkout "$PHP_BRANCH")
        #(cd "$PHP_SOURCE_PATH" && git pull origin "$PHP_BRANCH" --rebase)
    fi

    if [ ! -z "$PHP_COMMIT" ]; then
        (cd "$PHP_SOURCE_PATH" && git checkout "$PHP_COMMIT")
    fi
else
    if [ -z "$PHP_BASE_SOURCE_PATH" ]; then
        var="PHP_COMMITS_$PHP_ID"

        ( \
            cd $PHP_SOURCE_PATH && \
            git init && \
            git remote add origin "$PHP_REPO" && \
            git fetch origin "${!var}" && \
            git reset --hard FETCH_HEAD \
        )
    else
        echo "Creating source ($PHP_SOURCE_PATH) from base source ($PHP_BASE_SOURCE_PATH)"
        find "$PHP_BASE_SOURCE_PATH" -name "*.phpt" -type f -delete
        rsync -a "$PHP_BASE_SOURCE_PATH/" "$PHP_SOURCE_PATH"
    fi
fi
