#!/bin/sh

/usr/contrib/mariadb/mysql-restore.sh &

export | grep -v -e MYSQL_ROOT_PASSWORD > /etc/envvars
exec /usr/sbin/runsvdir-start
