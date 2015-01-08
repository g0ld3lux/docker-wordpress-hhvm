#!/bin/bash

set -e -x -o pipefail

baseimage="blitznote/debootstrap-amd64:16.04"
chost="x86_64-linux-gnu"
case $(dpkg --print-architecture) in
  i386|i686)
    baseimage="blitznote/debootstrap-i386:16.04"
    chost="i386-linux-gnu"
  ;;
esac

docker pull "$baseimage"

WORKDIR="$(mktemp -t -d $(realpath --relative-to=.. .).XXXXXX)"
cp Dockerfile "$WORKDIR"/
cp -ra contrib "$WORKDIR"/
(cd "$WORKDIR"; \
sed -i \
  -e "/^FROM/c\FROM $baseimage" \
  -e "s#dl.hhvm.com#mirror.yourwebhoster.eu/hhvm#g" \
  -e "s#https://#http://#g" \
  -e "s:x86_64-linux-gnu:${chost}:g" \
  Dockerfile && \
sed -i \
  -e "/api.wordpress/s#http://#https://#" \
  -e "/git clone/s#http://#https://#" \
  Dockerfile && \
docker build --rm \
  --build-arg=http_proxy=$(/usr/share/squid-deb-proxy-client/apt-avahi-discover) \
  -t "local/wordpress-hhvm" .)

docker run --rm "local/wordpress-hhvm" dpkg-query -f '${Status}\t${Package}\t${Version}\n' -W \
| awk '/^install ok installed/{print $4,"\t",$5}' >build.manifest

rm -rf "$WORKDIR"
