#!/usr/bin/env bash
set -e

dry_run="$1"
tmp_path="$2"
result_path="$3"
now="$4"

if [[ "$dry_run" == "1" ]]; then
    exit 0
fi

if [ ! -d "$tmp_path" ]; then
    exit 1
fi

if [ -z "$(ls -A "$tmp_path")" ]; then
    exit 1
fi

for dir in $tmp_path/*/
do
    dir="${dir%*/}"
    dirname="${dir##*/}"

    mkdir -p "${result_path}_$dirname"

    cp "$tmp_path/$dirname/environment.tsv" "${result_path}_$dirname/environment.tsv"

    cp "$tmp_path/$dirname/result.md" "${result_path}_$dirname/result.md"
    cp "$tmp_path/$dirname/result.tsv" "${result_path}_$dirname/result.tsv"
done

year="$(echo "$now" | cut -c 1-4)"
database_dir="$PROJECT_ROOT/docs/results/$year"
database_file="$database_dir/database.tsv"

: > "$database_file"

for dir in $database_dir/*/
do
    dir="${dir%*/}"

    if test -f "$dir/environment.tsv"; then
        cat "$dir/environment.tsv" >> "$database_file"
    fi

    if test -f "$dir/result.tsv"; then
        cat "$dir/result.tsv" >> "$database_file"
    fi

    printf "\n" >> "$database_file"
done
