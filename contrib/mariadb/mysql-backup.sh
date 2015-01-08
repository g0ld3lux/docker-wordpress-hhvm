#!/bin/bash
# Backups databases accessible to the regular MySQL user.

set -e -o pipefail

red='\e[0;31m'
green='\e[0;33m'
light_green='\e[1;32m'
NC='\e[0m' # No Color

BACKUP_DIR="${1:-/var/www/backup/$(date +'%Y-%m-%d-%H:%M')}"

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

echo -e "${green}SQL backup: waiting for MariaDB${NC}"
trap "echo -e \"${red}SQL restore: MariaDB is unavailable${NC}\" >&2" EXIT
for I in $(seq 10); do
	if mysql -e 'status' >/dev/null 2>&1; then
		break
	else
		sleep $I
	fi
done
mysql -e 'status' >/dev/null 2>&1
echo -e "${green}SQL backup: MariaDB is available${NC}"
trap - EXIT

UMASK_WAS=$(umask)
umask 0077

if [[ ! -d "${BACKUP_DIR}" ]]; then
	mkdir -p "${BACKUP_DIR}"

	DATABASES=$(echo "SHOW DATABASES;" | mysql --defaults-group-suffix=_user | grep -v -e 'Database' -e 'information_schema')
	for DB in $DATABASES; do
		echo -en "${light_green}backup of: ${DB} - ${NC}"
		mysqldump --create-options --events --routines \
			--add-locks --complete-insert --lock-tables \
			--add-drop-table "${DB}" \
		| plzip -6 > "${BACKUP_DIR}/${DB}.sql.lz" \
		&& echo -e "${green}OK${NC}" || echo -e "${red}FAILED${NC}" >&2
	done

	if [[ -e ${BACKUP_DIR%/*}/latest ]]; then
		rm ${BACKUP_DIR%/*}/latest
	fi
	ln -s ${BACKUP_DIR} ${BACKUP_DIR%/*}/latest
fi

umask $UMASK_WAS
echo -e "${green}DONE${NC}"

