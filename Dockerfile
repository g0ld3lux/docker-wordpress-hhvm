# Webserver and HHVM, ready for Wordpress.
# This is used to test plugins such as CDN Linker.

FROM blitznote/debootstrap-amd64:16.04
MAINTAINER W. Mark Kubacki <wmark@hurrikane.de>

RUN printf "deb [arch=$(dpkg --print-architecture) trusted=yes] https://s.blitznote.com/debs/ubuntu/$(dpkg --print-architecture)/ all/" > /etc/apt/sources.list.d/blitznote.list \
 && printf 'Package: *\nPin: origin "s.blitznote.com"\nPin-Priority: 510\n' > /etc/apt/preferences.d/prefer-blitznote

# In order to avoid creating a single very large layer
# this has intentionally been split.

RUN /usr/bin/get-gpg-key 0xcbcb082a1bb943db | apt-key add \
 && printf "deb [arch=$(dpkg --print-architecture)] http://ftp.igh.cnrs.fr/pub/mariadb/repo/10.1/ubuntu wily main" > /etc/apt/sources.list.d/mariadb.list \
 && apt-get -q update \
 && env DEBIAN_FRONTEND=noninteractive apt-get -y install \
      --no-install-recommends \
      mariadb-client \
 && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Subversion is needed for Wordpress, and GIT for some plugins.
RUN apt-get -q update \
 && env DEBIAN_FRONTEND=noninteractive apt-get -y install \
      --no-install-recommends \
      subversion git nginx-light redis-server fcron \
      rsync plzip less unzip patch file psmisc tree \
      openssl \
 && gpasswd -a fcron users \
 && rm /usr/sbin/nginx \
 && curl --silent --show-error --fail --location --compressed \
      --header "Accept: application/octet-stream" \
      --pinnedpubkey "sha256//fxBZ92Ul/3NOZJsiNJLhv5wHfywCe9PZvHWI6rd6frU=" \
      -o /usr/sbin/nginx \
      https://s.blitznote.com/debs/ubuntu/$(dpkg --print-architecture)/nginx \
 && ((file /usr/sbin/nginx | grep -q -F gzip && mv /usr/sbin/nginx /usr/sbin/nginx.gz && gunzip /usr/sbin/nginx.gz) || true) \
 && chmod a+x /usr/sbin/nginx \
 && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Some manual steps because this is xenial, and HHVM depends on some packages only available to Ubuntu Wily.
RUN curl -o /tmp/libgnutls-deb0-28.deb -fsSL \
      http://de.archive.ubuntu.com/ubuntu/pool/main/g/gnutls28/libgnutls-deb0-28_3.3.15-5ubuntu2_$(dpkg --print-architecture).deb \
 && dpkg --install /tmp/libgnutls-deb0-28.deb && rm /tmp/libgnutls-deb0-28.deb \
 && printf "/usr/lib\n" >> /etc/ld.so.conf.d/xxx99.conf \
 && printf "\nPackage: libvpx2\nStatus: install ok installed\nVersion: 1.4.0-4\nDepends: libvpx3\nArchitecture: $(dpkg --print-architecture)\nDescription: alias for libvpx3\nMaintainer: Nobody <noreply@blitznote.de>\n\n" >> /var/lib/dpkg/status \
    && ln -s libvpx.so.3     /usr/lib/x86_64-linux-gnu/libvpx.so.2 \
    && ln -s libvpx.so.3.0   /usr/lib/x86_64-linux-gnu/libvpx.so.2.0 \
    && ln -s libvpx.so.3.0.0 /usr/lib/x86_64-linux-gnu/libvpx.so.2.0.0 \
 && apt-get -q update \
 && env DEBIAN_FRONTEND=noninteractive apt-get -y -f install \
 && env DEBIAN_FRONTEND=noninteractive apt-get -y install \
      --no-install-recommends \
      imagemagick-common fonts-dejavu-core libmagickcore-6.q16-2 libmagickwand-6.q16-2 \
      binutils libglib2.0-0 libc-client2007e \
      libboost-system1.58.0 libboost-regex1.58.0 libboost-filesystem1.58.0 libboost-program-options1.58.0 \
      libboost-thread1.58.0 libboost-context1.58.0 \
 && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN /usr/bin/get-gpg-key 0x5a16e7281be7a449 | apt-key add \
 && printf "deb [arch=$(dpkg --print-architecture)] http://dl.hhvm.com/ubuntu wily-lts-3.12 main" > /etc/apt/sources.list.d/hhvm.list \
 && apt-get -q update \
 && env DEBIAN_FRONTEND=noninteractive apt-get -y install \
      --no-install-recommends \
      hhvm \
 && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Wordpress
RUN useradd -u 1001 -s /bin/bash -g users -G fcron,www-data -M --home-dir=/home/owner -N -c "webspace owner" owner \
 && mkdir -p /var/www/html \
 && curl --silent --show-error --fail --location \
      --header "Accept: application/tar+gzip, application/x-gzip, application/octet-stream" \
      --pinnedpubkey "sha256//SU4VjMOqJpxC5lQIW5u1X4ogo0sitEsI1fD/FyF44+g=" \
      https://wordpress.org/latest.tar.gz \
    | tar --no-same-owner --strip=1 -C /var/www/html -zx \
 && mkdir -p /var/www/html/wp-content/uploads \
 && chmod 0755 \
      /var/www/html/wp-content/plugins \
      /var/www/html/wp-content/themes \
      /var/www/html/wp-content/uploads \
 && sed -i \
      -e "/^define.'DB_NAME'/c define('DB_NAME', getenv('MYSQL_ENV_MYSQL_DATABASE'));" \
      -e "/^define.'DB_USER'/c define('DB_USER', getenv('MYSQL_ENV_MYSQL_USER'));" \
      -e "/^define.'DB_PASSWORD'/c define('DB_PASSWORD', getenv('MYSQL_ENV_MYSQL_PASSWORD'));" \
      -e "/^define.'DB_HOST'/c define('DB_HOST', getenv('MYSQL_PORT_3306_TCP_ADDR').':'.getenv('MYSQL_PORT_3306_TCP_PORT'));" \
      /var/www/html/wp-config-sample.php \
 && sed -i \
      -e "/<input name=.dbname./s:value=\"[^\"]*\":value=\"<?php echo getenv('MYSQL_ENV_MYSQL_DATABASE'); ?>\":" \
      -e "/<input name=.uname./s:value=\"[^\"]*\":value=\"<?php echo getenv('MYSQL_ENV_MYSQL_USER'); ?>\":" \
      -e "/<input name=.pwd./s:value=\"[^\"]*\":value=\"<?php echo getenv('MYSQL_ENV_MYSQL_PASSWORD'); ?>\":" \
      -e "/<input name=.dbhost./s:value=\"[^\"]*\":value=\"<?php echo getenv('MYSQL_PORT_3306_TCP_ADDR').'\:'.getenv('MYSQL_PORT_3306_TCP_PORT'); ?>\":" \
      /var/www/html/wp-admin/setup-config.php \
 && chown -R owner:www-data /var/www/html \
 && egrep -m 1 "^.wp_version" /var/www/html/wp-includes/version.php | tr -d "$;' " | sed -e 's:wp_:wordpress.:'

# … and plugins
RUN curl --silent --show-error --fail --location \
      --header "Accept: application/zip" \
      --pinnedpubkey "sha256//SU4VjMOqJpxC5lQIW5u1X4ogo0sitEsI1fD/FyF44+g=" \
      -o /tmp/mailgun.zip \
      $(curl -sSfL https://api.wordpress.org/plugins/info/1.0/mailgun.json | jq -r '.download_link') \
 && unzip /tmp/mailgun.zip -d /var/www/html/wp-content/plugins/ && rm /tmp/mailgun.zip \
 && cd /var/www/html/wp-content/plugins \
 && git clone --depth=1 https://github.com/wmark/CDN-Linker.git \
 && rm -rf CDN-Linker/.git CDN-Linker/test CDN-Linker/test.php \
 && chown -R owner:www-data /var/www/html/wp-content/plugins

# configuration, start, backup and restore scripts
ADD contrib/fcrontab /usr/contrib/fcrontab
ADD contrib/mariadb/ /usr/contrib/mariadb/
ADD contrib/nginx/ /etc/nginx/
ADD contrib/runit-bootstrap.sh /sbin/runit-bootstrap.sh
ADD contrib/runit/ /etc/service

# dummy certificates (for testing) and a last test
RUN mkdir -p /etc/ssl/web && chmod 0750 /etc/ssl/web \
 && openssl ecparam -name prime256v1 -genkey -out "/etc/ssl/web/web.key" \
 && openssl req -new -x509 -nodes -batch -sha256 \
      -subj "/CN=autogenerated.local" -days 1 \
      -key "/etc/ssl/web/web.key" \
      -out "/etc/ssl/web/web.crt-bundle" \
 && chmod 0600 "/etc/ssl/web/web.key" \
 && /usr/sbin/nginx -t \
 && /usr/bin/hhvm --version \
 && rm "/etc/ssl/web/web.key" "/etc/ssl/web/web.crt-bundle"

# 80    for HTTP, 443 for HTTPS
# 6379  for the included Redis instance
# 9000  is the HHVM server port
EXPOSE 80 443 6379 9000
VOLUME /var/www/backup /var/www/html /var/log
CMD ["/sbin/runit-bootstrap.sh"]
