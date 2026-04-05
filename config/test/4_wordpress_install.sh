#!/usr/bin/env bash
set -e

wordpress_url="https://github.com/kocsismate/benchmarking-wordpress-6.9"
wordpress_mysql_version="8.4.8"
wordpress_dir="$PROJECT_ROOT/app/wordpress"
wordpress_tmp_dir="$PROJECT_ROOT/tmp/app/wordpress"

if [[ -d "$wordpress_dir" ]]; then
    echo "Wordpress is already installed"
    exit
fi

mkdir -p "$wordpress_dir"
mkdir -p "$wordpress_tmp_dir"

git clone --depth=1 "$wordpress_url" "$wordpress_dir"

mysql_address="127.0.0.1"
mysql_container="wordpress_db"
mysql_db="wordpress"
mysql_user="wordpress"
mysql_password="wordpress"
mysql_timeout=60
mysql_data_path="$wordpress_tmp_dir/mysql-data"
mysql_config_path="$PROJECT_ROOT/build/mysql"

sudo mkdir -p "$mysql_data_path"
sudo chown $(id -u):$(id -g) "$mysql_data_path"

MYSQL_CPUS="2"

sudo cgexec -g cpuset:mysql \
    docker run \
    --name "$mysql_container" \
    --user "$(id -u):$(id -g)" \
    -v $mysql_data_path:/var/lib/mysql \
    -v $mysql_config_path:/etc/mysql/conf.d \
    --network "host" \
    --cpuset-cpus="$MYSQL_CPUS" \
    --memory="4G" \
    -e "MYSQL_ROOT_PASSWORD=root" \
    -e "MYSQL_DATABASE=$mysql_db" \
    -e "MYSQL_USER=$mysql_user" \
    -e "MYSQL_PASSWORD=$mysql_password" \
    -d mysql:$wordpress_mysql_version

$PROJECT_ROOT/build/script/wait_for_mysql.sh "$mysql_container" "$mysql_db" "$mysql_user" "$mysql_password" "$mysql_timeout"

sudo docker logs "$mysql_container"

sudo docker run --rm \
    --name "wordpress_cli" \
    --volume "$PROJECT_ROOT:/code" \
    --user "$(id -u):$(id -g)" \
    --network "host" \
    -e "WORDPRESS_DB_HOST=$mysql_address" \
    setup bash -c "\
        set -e
        php /code/app/wordpress/wp-cli.phar core install \
            --path=/code/app/wordpress/ \
            --allow-root --url=localhost --title=Wordpress \
            --admin_user=wordpress --admin_password=wordpress --admin_email=benchmark@php.net"

sed -i "s/\t\terror_reporting( E_CORE_ERROR | E_CORE_WARNING | E_COMPILE_ERROR | E_ERROR | E_WARNING | E_PARSE | E_USER_ERROR | E_USER_WARNING | E_RECOVERABLE_ERROR );/\t\terror_reporting( E_ALL );/g" "$wordpress_dir/wp-includes/load.php"
sed -i "s/\terror_reporting( E_CORE_ERROR | E_CORE_WARNING | E_COMPILE_ERROR | E_ERROR | E_WARNING | E_PARSE | E_USER_ERROR | E_USER_WARNING | E_RECOVERABLE_ERROR );/\terror_reporting( E_ALL );/g" "$wordpress_dir/wp-load.php"
