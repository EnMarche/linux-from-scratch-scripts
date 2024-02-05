#!/bin/bash

set -euo pipefail

config_sources() {
  cd /sources
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

build_man_pages() {
  config_sources man-pages-6.05.01 xz
  rm -v man3/crypt*
  make prefix=/usr install
  clean_sources
  log_compil_end "man-pages"
}

setup_iana_etc() {
  config_sources iana-etc-20230810 gz
  cp services protocols /etc
  clean_sources iana-etc-20230810
}

generate_locales() {
  mkdir -pv /usr/lib/locale
  localedef -i POSIX -f UTF-8 C.UTF-8 2> /dev/null || true
  localedef -i cs_CZ -f UTF-8 cs_CZ.UTF-8
  localedef -i de_DE -f ISO-8859-1 de_DE
  localedef -i de_DE@euro -f ISO-8859-15 de_DE@euro
  localedef -i de_DE -f UTF-8 de_DE.UTF-8
  localedef -i el_GR -f ISO-8859-7 el_GR
  localedef -i en_GB -f ISO-8859-1 en_GB
  localedef -i en_GB -f UTF-8 en_GB.UTF-8
  localedef -i en_HK -f ISO-8859-1 en_HK
  localedef -i en_PH -f ISO-8859-1 en_PH
  localedef -i en_US -f ISO-8859-1 en_US
  localedef -i en_US -f UTF-8 en_US.UTF-8
  localedef -i es_ES -f ISO-8859-15 es_ES@euro
  localedef -i es_MX -f ISO-8859-1 es_MX
  localedef -i fa_IR -f UTF-8 fa_IR
  localedef -i fr_FR -f ISO-8859-1 fr_FR
  localedef -i fr_FR@euro -f ISO-8859-15 fr_FR@euro
  localedef -i fr_FR -f UTF-8 fr_FR.UTF-8
  localedef -i is_IS -f ISO-8859-1 is_IS
  localedef -i is_IS -f UTF-8 is_IS.UTF-8
  localedef -i it_IT -f ISO-8859-1 it_IT
  localedef -i it_IT -f ISO-8859-15 it_IT@euro
  localedef -i it_IT -f UTF-8 it_IT.UTF-8
  localedef -i ja_JP -f EUC-JP ja_JP
  localedef -i ja_JP -f SHIFT_JIS ja_JP.SJIS 2> /dev/null || true
  localedef -i ja_JP -f UTF-8 ja_JP.UTF-8
  localedef -i nl_NL@euro -f ISO-8859-15 nl_NL@euro
  localedef -i ru_RU -f KOI8-R ru_RU.KOI8-R
  localedef -i ru_RU -f UTF-8 ru_RU.UTF-8
  localedef -i se_NO -f UTF-8 se_NO.UTF-8
  localedef -i ta_IN -f UTF-8 ta_IN.UTF-8
  localedef -i tr_TR -f UTF-8 tr_TR.UTF-8
  localedef -i zh_CN -f GB18030 zh_CN.GB18030
  localedef -i zh_HK -f BIG5-HKSCS zh_HK.BIG5-HKSCS
  localedef -i zh_TW -f UTF-8 zh_TW.UTF-8

  make localedata/install-locales

  localedef -i POSIX -f UTF-8 C.UTF-8 2> /dev/null || true
  localedef -i ja_JP -f SHIFT_JIS ja_JP.SJIS 2> /dev/null || true
}

add_timezone_data() {
  tar -xf ../../tzdata2023c.tar.gz

  ZONEINFO=/usr/share/zoneinfo
  mkdir -pv $ZONEINFO/{posix,right}

  for tz in etcetera southamerica northamerica europe africa antarctica  \
            asia australasia backward; do
      zic -L /dev/null   -d $ZONEINFO       ${tz}
      zic -L /dev/null   -d $ZONEINFO/posix ${tz}
      zic -L leapseconds -d $ZONEINFO/right ${tz}
  done

  cp -v zone.tab zone1970.tab iso3166.tab $ZONEINFO
  zic -d $ZONEINFO -p America/New_York
  unset ZONEINFO
}

add_nsswitch_conf() {
  cat > /etc/nsswitch.conf << EOF
# Begin /etc/nsswitch.conf

passwd: files
group: files
shadow: files

hosts: files dns
networks: files

protocols: files
services: files
ethers: files
rpc: files

# End /etc/nsswitch.conf
EOF
}

setup_dynamic_loader() {
cat > /etc/ld.so.conf << "EOF"
# Begin /etc/ld.so.conf
/usr/local/lib
/opt/lib

EOF

cat >> /etc/ld.so.conf << "EOF"
# Add an include directory
include /etc/ld.so.conf.d/*.conf

EOF
mkdir -pv /etc/ld.so.conf.d
}

install_glibc() {
  config_sources glibc-2.38 xz

  patch -Np1 -i ../glibc-2.38-fhs-1.patch
  patch -Np1 -i ../glibc-2.38-memalign_fix-1.patch

  mkdir -v build
  cd       build

  echo "rootsbindir=/usr/sbin" > configparms

  ../configure --prefix=/usr                            \
             --disable-werror                         \
             --enable-kernel=4.14                     \
             --enable-stack-protector=strong          \
             --with-headers=/usr/include              \
             libc_cv_slibdir=/usr/lib

  make
  make check
  touch /etc/ld.so.conf
  sed '/test-installation/s@$(PERL)@echo not running@' -i ../Makefile
  make install
  sed '/RTLDLIST=/s@/usr@@g' -i /usr/bin/ldd

  cp -v ../nscd/nscd.conf /etc/nscd.conf
  mkdir -pv /var/cache/nscd

  generate_locales
  add_nsswitch_conf
  add_timezone_data
  setup_dynamic_loader

  log_compil_end "glibc"

}

install_zlib() {
  config_sources zlib-1.2.13 xz
  ./configure --prefix=/usr
  make
  make check
  make install
  rm -fv /usr/lib/libz.a
  clean_sources zlib-1.2.13
  log_compil_end "zlib"

}

install_bzip2() {
  config_sources bzip2-1.0.8 gz

  patch -Np1 -i ../bzip2-1.0.8-install_docs-1.patch
  sed -i 's@\(ln -s -f \)$(PREFIX)/bin/@\1@' Makefile
  sed -i "s@(PREFIX)/man@(PREFIX)/share/man@g" Makefile
  make -f Makefile-libbz2_so
  make clean
  make
  make PREFIX=/usr install
  cp -av libbz2.so.* /usr/lib
  ln -sv libbz2.so.1.0.8 /usr/lib/libbz2.so

  cp -v bzip2-shared /usr/bin/bzip2
  for i in /usr/bin/{bzcat,bunzip2}; do
    ln -sfv bzip2 $i
  done
  rm -fv /usr/lib/libbz2.a
  clean_sources bzip2-1.0.8
  log_compil_end "bzip2"
}

install_xz() {
  config_sources xz-5.4.4 xz
  ./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/xz-5.4.4
  make
  make check
  make install
  clean_sources xz-5.4.4
  log_compil_end "xz"
}

install_zstd() {
  config_sources zstd-1.5.5 gz
  make prefix=/usr
  make check
  make prefix=/usr install
  rm -v /usr/lib/libzstd.a
  clean_sources zstd-1.5.5
  log_compil_end "zstd"
}

install_file() {
  config_sources file-5.45 gz
  ./configure --prefix=/usr
  make
  make check
  make install
  clean_sources file-5.45
  log_compil_end "file"
}

install_readline() {
  config_sources readline-8.2 gz
  sed -i '/MV.*old/d' Makefile.in
  sed -i '/{OLDSUFF}/c:' support/shlib-install
  patch -Np1 -i ../readline-8.2-upstream_fix-1.patch
  ./configure --prefix=/usr    \
            --disable-static \
            --with-curses    \
            --docdir=/usr/share/doc/readline-8.2
  make SHLIB_LIBS="-L/tools/lib -lncursesw"
  make SHLIB_LIBS="-L/tools/lib -lncursesw" install
  install -v -m644 doc/*.{ps,pdf,html,dvi} /usr/share/doc/readline-8.2
  clean_sources readline-8.2
  log_compil_end "readline"
}

install_m4() {
  config_sources m4-1.4.19 xz
  ./configure --prefix=/usr
  make
  make check
  make install
  clean_sources m4-1.4.19
  log_compil_end "m4"
}

install_bc() {
  config_sources bc-6.6.0 xz
  CC=gcc ./configure --prefix=/usr -G -O3 -r
  make
  make test
  make install
  clean_sources bc-6.6.0
  log_compil_end "bc"
}

install_flex() {
  config_sources flex-2.6.4 xz

  ./configure --prefix=/usr \
            --docdir=/usr/share/doc/flex-2.6.4 \
            --disable-static

  make
  make check
  make install

  ln -sv flex   /usr/bin/lex
  ln -sv flex.1 /usr/share/man/man1/lex.1

  clean_sources flex-2.6.4
  log_compil_end "flex"
}

install_tcl() {
  config_sources tcl8.6.13 gz
  SRCDIR=$(pwd)
  cd unix
  ./configure --prefix=/usr           \
              --mandir=/usr/share/man
  make

  sed -e "s|$SRCDIR/unix|/usr/lib|" \
      -e "s|$SRCDIR|/usr/include|"  \
      -i tclConfig.sh

  sed -e "s|$SRCDIR/unix/pkgs/tdbc1.1.5|/usr/lib/tdbc1.1.5|" \
      -e "s|$SRCDIR/pkgs/tdbc1.1.5/generic|/usr/include|"    \
      -e "s|$SRCDIR/pkgs/tdbc1.1.5/library|/usr/lib/tcl8.6|" \
      -e "s|$SRCDIR/pkgs/tdbc1.1.5|/usr/include|"            \
      -i pkgs/tdbc1.1.5/tdbcConfig.sh

  sed -e "s|$SRCDIR/unix/pkgs/itcl4.2.3|/usr/lib/itcl4.2.3|" \
      -e "s|$SRCDIR/pkgs/itcl4.2.3/generic|/usr/include|"    \
      -e "s|$SRCDIR/pkgs/itcl4.2.3|/usr/include|"            \
      -i pkgs/itcl4.2.3/itclConfig.sh

  unset SRCDIR

  make test
  make install
  chmod -v u+w /usr/lib/libtcl8.6.so
  make install-private-headers
  ln -sfv tclsh8.6 /usr/bin/tclsh
  mv /usr/share/man/man3/{Thread,Tcl_Thread}.3
  cd ..
  tar -xf ../tcl8.6.13-html.tar.gz --strip-components=1
  mkdir -v -p /usr/share/doc/tcl-8.6.13
  cp -v -r  ./html/* /usr/share/doc/tcl-8.6.13
  clean_sources tcl8.6.13
  log_compil_end "tcl"
}

install_expect() {
  config_sources expect5.45.4 gz
  ./configure --prefix=/usr           \
            --with-tcl=/usr/lib     \
            --enable-shared         \
            --mandir=/usr/share/man \
            --with-tclinclude=/usr/include
  make
  make test
  make install
  ln -svf expect5.45.4/libexpect5.45.4.so /usr/lib
  clean_sources expect5.45.4
  log_compil_end "expect"
}

install_dejagnu() {
  config_sources dejagnu-1.6.3 gz
  mkdir -v build
  cd       build
  ../configure --prefix=/usr
  makeinfo --html --no-split -o doc/dejagnu.html ../doc/dejagnu.texi
  makeinfo --plaintext       -o doc/dejagnu.txt  ../doc/dejagnu.texi
  make install
  install -v -dm755  /usr/share/doc/dejagnu-1.6.3
  install -v -m644   doc/dejagnu.{html,txt} /usr/share/doc/dejagnu-1.6.3
  make check
  clean_sources dejagnu-1.6.3
  log_compil_end "dejagnu"
}

install_binutils() {
  config_sources binutils-2.41 xz
  mkdir -v build
  cd       build
  ../configure --prefix=/usr       \
             --sysconfdir=/etc   \
             --enable-gold       \
             --enable-ld=default \
             --enable-plugins    \
             --enable-shared     \
             --disable-werror    \
             --enable-64-bit-bfd \
             --with-system-zlib
  make tooldir=/usr
  make -k check
  make tooldir=/usr install
  rm -fv /usr/lib/lib{bfd,ctf,ctf-nobfd,gprofng,opcodes,sframe}.a
  clean_sources binutils-2.41
  log_compil_end "binutils"

}

install_gmp() {
  config_sources gmp-6.3.0 xz

  # if it fails with error "Illegal instruction", retry with --host=none-linux-gnu
  ./configure --prefix=/usr    \
            --enable-cxx     \
            --disable-static \
            --docdir=/usr/share/doc/gmp-6.3.0
  make
  make html
  make check 2>&1 | tee gmp-check-log
  awk '/# PASS:/{total+=$3} ; END{print total}' gmp-check-log
  make install
  make install-html
  clean_sources gmp-6.3.0
  log_compil_end "gmp"
}

install_mpfr() {
  config_sources mpfr-4.2.0 xz
  sed -e 's/+01,234,567/+1,234,567 /' \
    -e 's/13.10Pd/13Pd/'            \
    -i tests/tsprintf.c
  ./configure --prefix=/usr        \
            --disable-static     \
            --enable-thread-safe \
            --docdir=/usr/share/doc/mpfr-4.2.0
  make
  make html
  make check
  make install
  make install-html
  clean_sources mpfr-4.2.0
  log_compil_end "mpfr"
}

install_mpc() {
  config_sources mpc-1.3.1 gz
  ./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/mpc-1.3.1
  make
  make html
  make check
  make install
  make install-html
  clean_sources mpc-1.3.1
  log_compil_end "mpc"
}

install_attr() {
  config_sources attr-2.5.1 gz
  ./configure --prefix=/usr     \
            --disable-static  \
            --sysconfdir=/etc \
            --docdir=/usr/share/doc/attr-2.5.1
  make
  make check
  make install
  clean_sources attr-2.5.1
  log_compil_end "attr"
}

install_acl() {
  config_sources acl-2.3.1 xz
  ./configure --prefix=/usr         \
            --disable-static      \
            --docdir=/usr/share/doc/acl-2.3.1
  make
  make install
  clean_sources acl-2.3.1
  log_compil_end "acl"
}

install_libcap() {
  config_sources libcap-2.69 xz
  sed -i '/install -m.*STA/d' libcap/Makefile
  make prefix=/usr lib=lib
  make test
  make prefix=/usr lib=lib install
  clean_sources libcap-2.69
  log_compil_end "libcap"
}

install_libxcrypt() {
  config_sources libxcrypt-4.4.36 xz
  ./configure --prefix=/usr                \
            --enable-hashes=strong,glibc \
            --enable-obsolete-api=glibc  \
            --disable-static             \
            --disable-failure-tokens
  make
  cp -av .libs/libcrypt.so.1* /usr/lib
  make check
  make install
  clean_sources libxcrypt-4.4.36
  log_compil_end "libxcrypt"
}

install_shadow() {
  # TODO: install cracklib to ensure strong password https://www.linuxfromscratch.org/lfs/view/stable/chapter08/shadow.html
  config_sources shadow-4.13 xz
  sed -i 's/groups$(EXEEXT) //' src/Makefile.in
  find man -name Makefile.in -exec sed -i 's/groups\.1 / /'   {} \;
  find man -name Makefile.in -exec sed -i 's/getspnam\.3 / /' {} \;
  find man -name Makefile.in -exec sed -i 's/passwd\.5 / /'   {} \;
  sed -e 's:#ENCRYPT_METHOD DES:ENCRYPT_METHOD YESCRYPT:' \
    -e 's:/var/spool/mail:/var/mail:'                   \
    -e '/PATH=/{s@/sbin:@@;s@/bin:@@}'                  \
    -i etc/login.defs

  touch /usr/bin/passwd
  ./configure --sysconfdir=/etc   \
            --disable-static    \
            --with-{b,yes}crypt \
            --with-group-name-max-length=32
  make
  make exec_prefix=/usr install
  make -C man install-man
  pwconv
  grpconv
  mkdir -p /etc/default
  useradd -D --gid 999
  sed -i '/MAIL/s/yes/no/' /etc/default/useradd
  echo "root:root" | chpasswd
  clean_sources shadow-4.13
  log_compil_end "shadow"
}

build_man_pages
setup_iana_etc
install_glibc
install_zlib
install_bzip2
install_xz
install_zstd
install_file
install_readline
install_m4
install_bc
install_flex
install_tcl
install_expect
install_binutils
install_gmp
install_mpfr
install_mpc
install_attr
install_acl
install_libcap
install_libxcrypt
install_shadow