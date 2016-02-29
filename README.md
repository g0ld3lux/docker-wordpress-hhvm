Nginx, Redis, Wordpress, HHVM
=============================

**HHVM** runs **Wordpress** behind **Nginx**/BoringSSL.
Comes with plugin for/from **Mailgun.org**, and **CDN Linker**, which caches to **Redis** if you enable that.

[![](https://badge.imagelayers.io/wmark/wordpress-hhvm:latest.svg)](https://imagelayers.io/?images=wmark/wordpress-hhvm:latest 'Get your own badge on imagelayers.io')

Starting the container triggers database(s) restore from backups (if available and need be),
and creates daily backups to another volume (listed below).
*Cron daemon* is **fcron**.

Usage
-----

Wordpress takes its data needed to connect to MariaDB/MySQL through environment variables,
as provided by Docker image *MariaDB*.

Start with:

```bash
/bin/docker run --rm --name my_mariadb \
  -e MYSQL_ROOT_PASSWORD=YYYYYYYYYYY \
  -e MYSQL_USER=myuser -e MYSQL_PASSWORD=mypasswd \
  -e MYSQL_DATABASE=my_wp \
  -v /var/customer/me/mysql:/var/lib/mysql \
  "mariadb:10.1"
```

And finally (all volumes are optional):

```bash
/bin/docker run --rm --name my_web \
  --link "my_mariadb:MYSQL" \
  -p 80:80 -p 443:443 \
  -v /var/customer/me/backup:/var/www/backup \
  -v /var/customer/me/log:/var/log \
  -v /var/customer/me/hhvm-cache:/var/cache/hhvm \
  wmark/wordpress-hhvm
```

Notable volumes:

 1. `/etc/ssl` — for your own SSL certificates (web.key is the private key, web.crt your certificate followed by your issuer's)
 2. `/etc/nginx/vhosts.d` — customize Nginx' settings, add your own domain name
 3. `/var/www/html` — this directory gets served by Nginx/HHVM/PHP
 4. `/var/cache/hhvm` — HHVM stores its compiled-PHP–files here
 5. `/var/www/backup` — daily backups of the MySQL or MariaDB database(s) go here, the latest is symlinked as `latest`
 6. `/var/log` — logfiles
 7. `/etc/fcrontab` — not really a directory, but in case you want other cronjobs: inject that file
