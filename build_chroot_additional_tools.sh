#!/bin/bash

set -euo pipefail

config_sources() {
  cd /sources
  echo extracting "$1.tar.*"
  tar -xf "$(ls ${1}*.tar.*)"
  cd "$(ls -d */ | grep ${1})"
}

get_version() {
  curr="$(pwd)"
  cd /sources
  folder=$(ls -d $1*.tar.*)
  folder_with_ver="$(echo ${folder%*.tar.*})"
  echo ${folder_with_ver/"$1-"/""}
  cd "$curr"
}

clean_sources() {
  cd /sources
  rm -rf "$(ls -d */ | grep ${1}*)"
}

log_compil_end() {
  echo -ne "\n\nCompiling ${1}...done\n"
  sleep 1
}

build_gettext() {
  config_sources gettext
  ./configure --disable-shared
  make
  cp -v gettext-tools/src/{msgfmt,msgmerge,xgettext} /usr/bin
  clean_sources gettext
  log_compil_end gettext
}

build_bison() {
  config_sources bison
  version="$(get_version bison)"
  ./configure --prefix=/usr \
            --docdir=/usr/share/doc/bison-$version
  make
  make install
  clean_sources bison
  log_compil_end bison
}

build_perl() {
  config_sources perl
  major_version="$(echo $version | cut -d. -f1,2)"

  sh Configure -des                                        \
             -Dprefix=/usr                               \
             -Dvendorprefix=/usr                         \
             -Duseshrplib                                \
             -Dprivlib=/usr/lib/perl5/$major_version/core_perl     \
             -Darchlib=/usr/lib/perl5/$major_version/core_perl     \
             -Dsitelib=/usr/lib/perl5/$major_version/site_perl     \
             -Dsitearch=/usr/lib/perl5/$major_version/site_perl    \
             -Dvendorlib=/usr/lib/perl5/$major_version/vendor_perl \
             -Dvendorarch=/usr/lib/perl5/$major_version/vendor_perl
  make
  make install
  clean_sources perl
  log_compil_end perl
}

build_python() {
  config_sources Python
  ./configure --prefix=/usr   \
            --enable-shared \
            --without-ensurepip
  make
  make install
  clean_sources Python
  log_compil_end python
}

build_texinfo() {
  config_sources texinfo
  ./configure --prefix=/usr
  make
  make install
  clean_sources texinfo
  log_compil_end texinfo
}


build_util_linux() {
  config_sources util-linux
  version="$(get_version util-linux)"
./configure ADJTIME_PATH=/var/lib/hwclock/adjtime    \
            --libdir=/usr/lib    \
            --runstatedir=/run   \
            --docdir=/usr/share/doc/util-linux-$version \
            --disable-chfn-chsh  \
            --disable-login      \
            --disable-nologin    \
            --disable-su         \
            --disable-setpriv    \
            --disable-runuser    \
            --disable-pylibmount \
            --disable-static     \
            --without-python
  make
  make install
  clean_sources util-linux
  log_compil_end util-linux
}

cleanup() {
  rm -rf /usr/share/{info,man,doc}/*
  find /usr/{lib,libexec} -name \*.la -delete
  rm -rf /tools
}

build_gettext
build_bison
build_perl
build_python
build_texinfo
build_util_linux

cleanup


echo -ne "\n\n\nNow would be a good time to backup the LFS partition\n"
echo "You can do this by running the following command, as root (not chroot):"
echo "/backup.sh -b"
exit 0