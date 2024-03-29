#!/usr/bin/env bash
set -e

if [ ! -d "$1" ]; then
    exit
fi

if [ -z "$(ls -A $1)" ]; then
    exit
fi

for dir in $1/*/
do
    dir=${dir%*/}
    dirname="${dir##*/}"

    mkdir -p "$2_$dirname"

    cp "$1/$dirname/environment.tsv" "$2_$dirname/environment.tsv"

    cp "$1/$dirname/result.md" "$2_$dirname/result.md"
    cp "$1/$dirname/result.tsv" "$2_$dirname/result.tsv"
done

database_dir="$PROJECT_ROOT/docs/results"
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
