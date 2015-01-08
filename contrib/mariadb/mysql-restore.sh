#!/bin/bash
# Creates users and restores data from backups.

set -e -o pipefail

red='\e[0;31m'
green='\e[0;33m'
light_green='\e[1;32m'
NC='\e[0m' # No Color

BACKUP_DIR="${1:-/var/www/backup/latest}"

if [[ ! -e ~/.my.cnf && -v MYSQL_PORT_3306_TCP_ADDR ]]; then
	echo "[client]" > ~/.my.cnf
	chmod 0600 ~/.my.cnf

	echo "host=${MYSQL_PORT_3306_TCP_ADDR}" >> ~/.my.cnf
	echo "port=${MYSQL_PORT_3306_TCP_PORT}" >> ~/.my.cnf
	if [[ -v MYSQL_ENV_MYSQL_ROOT_PASSWORD ]]; then
		echo "user=root" >> ~/.my.cnf
		echo "password=${MYSQL_ENV_MYSQL_ROOT_PASSWORD}" >> ~/.my.cnf
	else
		echo "user=${MYSQL_ENV_MYSQL_USER}" >> ~/.my.cnf
		echo "password=${MYSQL_ENV_MYSQL_PASSWORD}" >> ~/.my.cnf
	fi
	echo "max-allowed-packet=1G" >> ~/.my.cnf
	echo "" >> ~/.my.cnf
	echo "[mysqldump]" >> ~/.my.cnf
	echo "host=${MYSQL_PORT_3306_TCP_ADDR}" >> ~/.my.cnf
	echo "port=${MYSQL_PORT_3306_TCP_PORT}" >> ~/.my.cnf
	echo "user=root" >> ~/.my.cnf
	echo "password=${MYSQL_ENV_MYSQL_ROOT_PASSWORD}" >> ~/.my.cnf
	echo "max-allowed-packet=1G" >> ~/.my.cnf
        echo "" >> ~/.my.cnf
        echo "[client_user]" >> ~/.my.cnf
        echo "host=${MYSQL_PORT_3306_TCP_ADDR}" >> ~/.my.cnf
        echo "port=${MYSQL_PORT_3306_TCP_PORT}" >> ~/.my.cnf
        echo "user=${MYSQL_ENV_MYSQL_USER}" >> ~/.my.cnf
        echo "password=${MYSQL_ENV_MYSQL_PASSWORD}" >> ~/.my.cnf
        echo "max-allowed-packet=1G" >> ~/.my.cnf
fi

echo -e "${green}SQL restore: waiting for MariaDB${NC}"
trap "echo -e \"${red}SQL restore: MariaDB is unavailable${NC}\" >&2" EXIT
for I in $(seq 10); do
	if mysql -e 'status' >/dev/null 2>&1; then
		break
	else
		sleep $I
	fi
done
mysql -e 'status' >/dev/null 2>&1
echo -e "${green}SQL restore: MariaDB became available${NC}"
trap - EXIT

if [[ ! -e ${BACKUP_DIR} ]]; then
	echo -e "${light_green}... no backups in ${BACKUP_DIR}, skipping${NC}"
	exit 0
fi

echo -e "${green}restore data from backup${NC}"
for DBFILE in "${BACKUP_DIR}"/*.sql.lz; do
	if [[ ! -e "${DBFILE}" ]]; then
		continue
	fi
	FNAME=${DBFILE##*/}
	DBNAME=${FNAME%%.*}

	# create the schema
	if mysql -e "SHOW DATABASES LIKE '${DBNAME}'" | grep -q -F "${DBNAME}"; then
		echo -e "${light_green}... exists: ${DBNAME}${NC}"
	else
		echo -e "${light_green}... create: ${DBNAME}${NC}"
		mysql <<-EOSQL
			CREATE DATABASE IF NOT EXISTS ${DBNAME};
			GRANT ALL ON ${DBNAME}.* TO '${MYSQL_ENV_MYSQL_USER}'@'%';
			FLUSH PRIVILEGES;
		EOSQL
	fi

	# fill it from backup if empty
	if mysql -e "USE ${DBNAME}; SHOW TABLES" | grep -q -F "Tables_in"; then
		echo -e "${light_green}... has data, skipping: ${DBNAME}${NC}"
	else
		echo -e "${light_green}... is empty, will restore: ${DBNAME}${NC}"
		plzip -cdk "${DBFILE}" \
		| sed -e '/^\/\*\!50001 CREATE ALGORITHM/d' \
			-e '/^\/\*\!50013 DEFINER=/d' \
			-e '/^\/\*\!50001 VIEW /s:VIEW:CREATE VIEW:' \
		| mysql --defaults-group-suffix=_user ${DBNAME}
	fi
done

echo -e "${green}DONE${NC}"

