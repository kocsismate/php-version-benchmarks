#!/usr/bin/env bash
set -e

if [ ! -d "$1" ]; then
    exit 1
fi

if [ -z "$(ls -A $1)" ]; then
    exit 1
fi

for dir in $1/*/
do
    dir=${dir%*/}
    dirname="${dir##*/}"

    mkdir -p "${2}_$dirname"

    cp "$1/$dirname/environment.tsv" "${2}_$dirname/environment.tsv"

    cp "$1/$dirname/result.md" "${2}_$dirname/result.md"
    cp "$1/$dirname/result.tsv" "${2}_$dirname/result.tsv"
done

year="$(echo "$NOW" | cut -c 1-4)"
database_dir="$PROJECT_ROOT/docs/results/$year"
database_file="$database_dir/database.tsv"

: > "$database_file"

for dir in $database_dir/*/
do
    dir=${dir%*/}

    if test -f "$dir/environment.tsv"; then
        cat "$dir/environment.tsv" >> "$database_file"
    fi

    if test -f "$dir/result.tsv"; then
        cat "$dir/result.tsv" >> "$database_file"
    fi

    printf "\n" >> "$database_file"
done
