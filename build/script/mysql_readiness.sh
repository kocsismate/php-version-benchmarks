#!/usr/bin/env bash

set -e

mysql_container="$1"
mysql_db="$2"
mysql_user="$3"
mysql_password="$4"
mysql_timeout="$5"

echo "Waiting for MySQL container to become ready..."

start_time="$(date +%s)"

while true; do
    if docker exec "$mysql_container" \
        mysql -u"$mysql_user" -p"$mysql_password" -e "SELECT 1" "$mysql_db" >/dev/null 2>&1; then
        echo "MySQL is ready in $(( now - start_time )) seconds"
        break
    fi

    now="$(date +%s)"
    if (( now - start_time > mysql_timeout )); then
        echo "Error: MySQL did not become ready within $mysql_timeout seconds"
        exit 1
    fi

    sleep 1
done
