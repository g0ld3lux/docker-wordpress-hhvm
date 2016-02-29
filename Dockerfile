# Webserver and HHVM, ready for Wordpress.
# This is used to test plugins such as CDN Linker.

FROM blitznote/debootstrap-amd64:16.04
MAINTAINER W. Mark Kubacki <wmark@hurrikane.de>

RUN printf "deb [arch=$(dpkg --print-architecture) trusted=yes] https://s.blitznote.com/debs/ubuntu/$(dpkg --print-architecture)/ all/" > /etc/apt/sources.list.d/blitznote.list \
 && printf 'Package: *\nPin: origin "s.blitznote.com"\nPin-Priority: 510\n' > /etc/apt/preferences.d/prefer-blitznote

# In order to avoid creating a single very large layer 
# this has intentionally been split.

RUN apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 \
      0xcbcb082a1bb943db \
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
 && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Some manual steps because this is xenial, and HHVM depends on some packages only available to Ubuntu Wily.
RUN curl -o /tmp/libgnutls-deb0-28.deb -fsSL \
      http://de.archive.ubuntu.com/ubuntu/pool/main/g/gnutls28/libgnutls-deb0-28_3.3.15-5ubuntu2_$(dpkg --print-architecture).deb \
 && dpkg --install /tmp/libgnutls-deb0-28.deb && rm /tmp/libgnutls-deb0-28.deb \
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

RUN apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 \
      0x5a16e7281be7a449 \
 && printf "deb [arch=$(dpkg --print-architecture)] http://dl.hhvm.com/ubuntu wily-lts-3.12 main" > /etc/apt/sources.list.d/hhvm.list \
 && apt-get -q update \
 && env DEBIAN_FRONTEND=noninteractive apt-get -y install \
      --no-install-recommends \
      hhvm \
 && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# XXX: Add Wordpress and plugins.

# XXX: Add configuration files.

# 80    for HTTP, 443 for HTTPS
# 6379  for the included Redis instance
# 9000  is the HHVM server port
EXPOSE 80 443 6379 9000
VOLUME /var/www/backup /var/www/html /var/log /etc/ssl/web
# CMD ["/usr/sbin/runit-bootstrap.sh"]
