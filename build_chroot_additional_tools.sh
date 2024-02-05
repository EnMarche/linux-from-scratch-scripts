#!/bin/bash

set -euo pipefail

config_sources() {
  cd /sources
  pwd
  echo extracting $1.tar.$2
  tar -xf ${1}.tar.${2}
  cd ${1}
}

clean_sources() {
  cd /sources
  rm -rf ${1}
}

log_compil_end() {
  echo -ne "\n\nCompiling ${1}...done\n"
  sleep 1
}

build_gettext() {
  config_sources gettext-0.22 xz
  ./configure --disable-shared
  make
  cp -v gettext-tools/src/{msgfmt,msgmerge,xgettext} /usr/bin
  clean_sources gettext-0.22
  log_compil_end gettext
}

build_bison() {
  config_sources bison-3.8.2 xz
  ./configure --prefix=/usr \
            --docdir=/usr/share/doc/bison-3.8.2
  make
  make install
  clean_sources bison-3.8.2
  log_compil_end bison
}

build_perl() {
  config_sources perl-5.38.0 xz
  sh Configure -des                                        \
             -Dprefix=/usr                               \
             -Dvendorprefix=/usr                         \
             -Duseshrplib                                \
             -Dprivlib=/usr/lib/perl5/5.38/core_perl     \
             -Darchlib=/usr/lib/perl5/5.38/core_perl     \
             -Dsitelib=/usr/lib/perl5/5.38/site_perl     \
             -Dsitearch=/usr/lib/perl5/5.38/site_perl    \
             -Dvendorlib=/usr/lib/perl5/5.38/vendor_perl \
             -Dvendorarch=/usr/lib/perl5/5.38/vendor_perl
  make
  make install
  clean_sources perl-5.38.0
  log_compil_end perl
}

build_python() {
  config_sources Python-3.11.4 xz
  ./configure --prefix=/usr   \
            --enable-shared \
            --without-ensurepip
  make
  make install
  clean_sources Python-3.11.4
  log_compil_end python
}

build_texinfo() {
  config_sources texinfo-7.0.3 xz
  ./configure --prefix=/usr
  make
  make install
  clean_sources texinfo-7.0.3
  log_compil_end texinfo
}


build_util_linux() {
  config_sources util-linux-2.39.1 xz
./configure ADJTIME_PATH=/var/lib/hwclock/adjtime    \
            --libdir=/usr/lib    \
            --runstatedir=/run   \
            --docdir=/usr/share/doc/util-linux-2.39.1 \
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
  clean_sources util-linux-2.39.1
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
echo "You can do this by running the following command:"
