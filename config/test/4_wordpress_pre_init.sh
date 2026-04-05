#!/usr/bin/env bash
set -e

sudo systemctl start containerd.service
sudo service docker start

db_container_id="$(docker ps -aqf "name=wordpress_db")"
sudo cgexec -g cpuset:mysql \
    docker start "$db_container_id"

$PROJECT_ROOT/build/script/wait_for_mysql.sh "wordpress_db" "wordpress" "wordpress" "wordpress" "60"
