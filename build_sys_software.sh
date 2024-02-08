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

install_gcc() {
  config_sources gcc-13.2.0 xz
  case $(uname -m) in
    x86_64)
      sed -e '/m64=/s/lib64/lib/' \
          -i.orig gcc/config/i386/t-linux64
    ;;
  esac
  mkdir -v build
  cd       build


  ../configure --prefix=/usr            \
            LD=ld                    \
            --enable-languages=c,c++ \
            --enable-default-pie     \
            --enable-default-ssp     \
            --disable-multilib       \
            --disable-bootstrap      \
            --disable-fixincludes    \
            --with-system-zlib
  make
  ulimit -s 32768
  chown -Rv tester .
  su tester -c "PATH=$PATH make -k $MAKEFLAGS check"
  ../contrib/test_summary
  sleep 5
  make install
  chown -v -R root:root \
    /usr/lib/gcc/$(gcc -dumpmachine)/13.2.0/include{,-fixed}
  ln -svr /usr/bin/cpp /usr/lib
  ln -sv gcc.1 /usr/share/man/man1/cc.1


  ln -sfv ../../libexec/gcc/$(gcc -dumpmachine)/13.2.0/liblto_plugin.so \
        /usr/lib/bfd-plugins/
  echo 'int main(){}' > dummy.c
  cc dummy.c -v -Wl,--verbose &> dummy.log
  readelf -l a.out | grep ': /lib'
  sleep 1
  grep -E -o '/usr/lib.*/S?crt[1in].*succeeded' dummy.log
  grep -B4 '^ /usr/include' dummy.log
  sleep 5
  grep 'SEARCH.*/usr/lib' dummy.log |sed 's|; |\n|g'
  sleep 5
  grep "/lib.*/libc.so.6 " dummy.log
  sleep 5
  grep found dummy.log
  sleep 5
  rm -v dummy.c a.out dummy.log
  mkdir -pv /usr/share/gdb/auto-load/usr/lib
  mv -v /usr/lib/*gdb.py /usr/share/gdb/auto-load/usr/lib
  clean_sources gcc-13.2.0
  log_compil_end "gcc"
}

install_pkgconf() {
  config_sources pkgconf-2.0.1 xz
  ./configure --prefix=/usr              \
            --disable-static           \
            --docdir=/usr/share/doc/pkgconf-2.0.1
  make
  make install
  ln -sv pkgconf   /usr/bin/pkg-config
  ln -sv pkgconf.1 /usr/share/man/man1/pkg-config.1
  clean_sources pkgconf-2.0.1
  log_compil_end "pkgconf"
}

install_ncurses() {
  config_sources ncurses-6.4 gz
  ./configure --prefix=/usr           \
            --mandir=/usr/share/man \
            --with-shared           \
            --without-debug         \
            --without-normal        \
            --with-cxx-shared       \
            --enable-pc-files       \
            --enable-widec          \
            --with-pkg-config-libdir=/usr/lib/pkgconfig
  make
  make DESTDIR=$PWD/dest install
  install -vm755 dest/usr/lib/libncursesw.so.6.4 /usr/lib
  rm -v  dest/usr/lib/libncursesw.so.6.4
  cp -av dest/* /
  for lib in ncurses form panel menu ; do
    rm -vf                    /usr/lib/lib${lib}.so
    echo "INPUT(-l${lib}w)" > /usr/lib/lib${lib}.so
    ln -sfv ${lib}w.pc        /usr/lib/pkgconfig/${lib}.pc
  done
  rm -vf                     /usr/lib/libcursesw.so
  echo "INPUT(-lncursesw)" > /usr/lib/libcursesw.so
  ln -sfv libncurses.so      /usr/lib/libcurses.so
  cp -v -R doc -T /usr/share/doc/ncurses-6.4

  # The instructions above don't create non-wide-character Ncurses libraries since no package installed by compiling from sources would link against them at runtime. However, the only known binary-only applications that link against non-wide-character Ncurses libraries require version 5. If you must have such libraries because of some binary-only application or to be compliant with LSB, build the package again with the following commands: 
  make distclean
  ./configure --prefix=/usr    \
              --with-shared    \
              --without-normal \
              --without-debug  \
              --without-cxx-binding \
              --with-abi-version=5
  make sources libs
  cp -av lib/lib*.so.5* /usr/lib
  clean_sources ncurses-6.4
  log_compil_end "ncurses"
}

install_sed() {
  config_sources sed-4.9 xz
  ./configure --prefix=/usr --bindir=/bin
  make
  make html
  chown -Rv tester .
  su tester -c "PATH=$PATH make $MAKEFLAGS check"
  make install
  install -d -m755           /usr/share/doc/sed-4.9
  install -m644 doc/sed.html /usr/share/doc/sed-4.9
  clean_sources sed-4.9
  log_compil_end "sed"
}

install_psmisc() {
  config_sources psmisc-23.6 xz
  ./configure --prefix=/usr
  make
  make check
  make install
  clean_sources psmisc-23.6
  log_compil_end "psmisc"
}

install_gettext() {
  config_sources gettext-0.22 xz
  ./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/gettext-0.22
  make
  make check
  make install
  chmod -v 0755 /usr/lib/preloadable_libintl.so
  clean_sources gettext-0.22
  log_compil_end "gettext"
}

install_bison() {
  config_sources bison-3.8.2 gz
  ./configure --prefix=/usr --docdir=/usr/share/doc/bison-3.8.2
  make
  make check
  make install
  clean_sources bison-3.8.2
  log_compil_end "bison"
}

install_grep() {
  config_sources grep-3.11 xz
  sed -i "s/echo/#echo/" src/egrep.sh
  ./configure --prefix=/usr
  make
  make check
  make install
  clean_sources grep-3.11
  log_compil_end "grep"

}

install_bash() {
  config_sources bash-5.1 gz
  ./configure --prefix=/usr           \
            --docdir=/usr/share/doc/bash-5.1 \
            --without-bash-malloc   \
            --with-installed-readline
  make
  chown -Rv tester .
su -s /usr/bin/expect tester << EOF
set timeout -1
spawn make tests
expect eof
lassign [wait] _ _ _ value
exit $value
EOF
  make install
  clean_sources bash-5.1
  log_compil_end "bash"
  # exec /usr/bin/bash --login

}

install_libtool() {
  config_sources libtool-2.4.7 xz
  ./configure --prefix=/usr
  make
  make -k check TESTSUITEFLAGS="$MAKEFLAGS"
  make install
  rm -fv /usr/lib/libltdl.a
  clean_sources libtool-2.4.7
  log_compil_end "libtool"
}

install_gdbm() {
  config_sources gdbm-1.23 xz
  ./configure --prefix=/usr    \
            --disable-static \
            --enable-libgdbm-compat
  make
  make check
  make install
  clean_sources gdbm-1.23
  log_compil_end "gdbm"
}

install_gperf() {
  config_sources gperf-3.1 gz
  ./configure --prefix=/usr --docdir=/usr/share/doc/gperf-3.1
  make
  make -j1 check
  make install
  clean_sources gperf-3.1
  log_compil_end "gperf"
}

install_expat() {
  config_sources expat-2.5.1 gz
  ./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/expat-2.5.0
  make
  make check
  make install
  install -v -m644 doc/*.{html,css} /usr/share/doc/expat-2.5.1
  clean_sources expat-2.5.1
  log_compil_end "expat"
}

install_inetutils() {
  config_sources inetutils-2.4 xz
  ./configure --prefix=/usr        \
              --bindir=/usr/bin    \
              --localstatedir=/var \
              --disable-logger     \
              --disable-whois      \
              --disable-rcp        \
              --disable-rexec      \
              --disable-rlogin     \
              --disable-rsh        \
              --disable-servers
  make
  make check
  make install
  mv -v /usr/{,s}bin/ifconfig
  clean_sources inetutils-2.4
  log_compil_end "inetutils"
}

install_less() {
  config_sources less-643 gz
  ./configure --prefix=/usr --sysconfdir=/etc
  make
  make check
  make install
  clean_sources less-643
  log_compil_end "less"
}

install_perl() {
  config_sources perl-5.38.0 gz
  export BUILD_ZLIB=False
  export BUILD_BZIP2=0
  sh Configure -des                                         \
              -Dprefix=/usr                                \
              -Dvendorprefix=/usr                          \
              -Dprivlib=/usr/lib/perl5/5.38/core_perl      \
              -Darchlib=/usr/lib/perl5/5.38/core_perl      \
              -Dsitelib=/usr/lib/perl5/5.38/site_perl      \
              -Dsitearch=/usr/lib/perl5/5.38/site_perl     \
              -Dvendorlib=/usr/lib/perl5/5.38/vendor_perl  \
              -Dvendorarch=/usr/lib/perl5/5.38/vendor_perl \
              -Dman1dir=/usr/share/man/man1                \
              -Dman3dir=/usr/share/man/man3                \
              -Dpager="/usr/bin/less -isR"                 \
              -Duseshrplib                                 \
              -Dusethreads
  make
  make  test
  make install
  unset BUILD_ZLIB BUILD_BZIP2
  clean_sources perl-5.38.0
  log_compil_end "perl"
}

install_xml_parser() {
  config_sources XML-Parser-2.46 gz
  perl Makefile.PL
  make
  make test
  make install
  clean_sources XML-Parser-2.46
  log_compil_end "xml_parser"
}

install_intltool() {
  config_sources intltool-0.51.0 gz
  sed -i 's:\\\${:\\\$\\{:' intltool-update.in
  ./configure --prefix=/usr
  make
  make check
  make install
  install -v -Dm644 doc/I18N-HOWTO /usr/share/doc/intltool-0.51.0/I18N-HOWTO
}

install_autoconf() {
  config_sources autoconf-2.71 xz
  sed -e 's/SECONDS|/&SHLVL|/'               \
    -e '/BASH_ARGV=/a\        /^SHLVL=/ d' \
    -i.orig tests/local.at
  ./configure --prefix=/usr
  make
  make check TESTSUITEFLAGS="$MAKEFLAGS"
  make install
  clean_sources autoconf-2.71
  log_compil_end "autoconf"
}

install_automake() {
  config_sources automake-1.16.5 xz
  ./configure --prefix=/usr
  make
  make check
  make install
  clean_sources automake-1.16.5
  log_compil_end "automake"
}

install_openssl() {
  config_sources openssl-3.1.2 gz
  ./config --prefix=/usr --openssldir=/etc/ssl --libdir=lib shared zlib-dynamic
  make
  make test
  make install
  sed -i '/INSTALL_LIBS/s/libcrypto.a libssl.a//' Makefile
  make MANSUFFIX=ssl install
  mv -v /usr/share/doc/openssl /usr/share/doc/openssl-3.1.2
  cp -vfr doc/* /usr/share/doc/openssl-3.1.2
  clean_sources openssl-3.1.2
  log_compil_end "openssl"
}

install_kmod() {
  config_sources kmod-30 xz
./configure --prefix=/usr          \
            --sysconfdir=/etc      \
            --with-openssl         \
            --with-xz              \
            --with-zstd            \
            --with-zlib
  make
  make install

  for target in depmod insmod modinfo modprobe rmmod; do
    ln -sfv ../bin/kmod /usr/sbin/$target
  done

  ln -sfv kmod /usr/bin/lsmod
  clean_sources kmod-30
  log_compil_end "kmod"
}

install_libelf() {
  config_sources elfutils-0.189 bz2
  ./configure --prefix=/usr                \
            --disable-debuginfod         \
            --enable-libdebuginfod=dummy
  make
  make check
  make -C libelf install
  install -vm644 config/libelf.pc /usr/lib/pkgconfig
  rm /usr/lib/libelf.a
  clean_sources elfutils-0.189
  log_compil_end "libelf"
}

install_libffi() {
  config_sources libffi-3.4.4 gz
  ./configure --prefix=/usr          \
            --disable-static       \
            --with-gcc-arch=native
  make
  make check
  make install
  clean_sources libffi-3.4.4
  log_compil_end "libffi"
}

install_python() {
  config_sources Python-3.11.4 xz
  ./configure --prefix=/usr        \
            --enable-shared      \
            --with-system-expat  \
            --with-system-ffi    \
            --enable-optimizations
  make
  make install

# As we use LFS to build our own distro, we depart from the book and still want to check pip updates
#   cat > /etc/pip.conf << EOF
# [global]
# root-user-action = ignore
# disable-pip-version-check = true
# EOF
  install -v -dm755 /usr/share/doc/python-3.11.4/html

  tar --strip-components=1  \
      --no-same-owner       \
      --no-same-permissions \
      -C /usr/share/doc/python-3.11.4/html \
      -xvf ../python-3.11.4-docs-html.tar.bz2

  clean_sources Python-3.11.4
  log_compil_end "python"
}

install_flit_core() {
  config_sources flit-core-3.9.0 gz
  pip3 wheel -w dist --no-build-isolation --no-deps $PWD
  pip3 install --no-index --no-user --find-links dist flit_core
  clean_sources flit-core-3.9.0
  log_compil_end "flit_core"
}

install_wheel() {
  config_sources wheel-0.37.0 gz
  pip3 wheel -w dist --no-build-isolation --no-deps $PWD
  pip3 install --no-index --no-user --find-links dist wheel
  clean_sources wheel-0.37.0
  log_compil_end "wheel"
}

install_ninja() {
  config_sources ninja-1.11.1 gz
  # Ninja can use more jobs than the system can handle, as it focuses on speed. The number of jobs can be set with the NINJAJOBS environment variable. If it is not set, Ninja will use the number of available CPU cores.
  # export NINJAJOBS=4
  sed -i '/int Guess/a \
    int   j = 0;\
    char* jobs = getenv( "NINJAJOBS" );\
    if ( jobs != NULL ) j = atoi( jobs );\
    if ( j > 0 ) return j;\
  ' src/ninja.cc
  python3 configure.py --bootstrap
  install -vm755 ninja /usr/bin/
  install -vDm644 misc/bash-completion /usr/share/bash-completion/completions/ninja
  install -vDm644 misc/zsh-completion  /usr/share/zsh/site-functions/_ninja
  clean_sources ninja-1.11.1
  log_compil_end "ninja"
}

install_meson() {
  config_sources meson-1.2.1 gz
  pip3 wheel -w dist --no-build-isolation --no-deps $PWD
  pip3 install --no-index --find-links dist meson
  install -vDm644 data/shell-completions/bash/meson /usr/share/bash-completion/completions/meson
  install -vDm644 data/shell-completions/zsh/_meson /usr/share/zsh/site-functions/_meson
  clean_sources meson-1.2.1
  log_compil_end "meson"
}

install_coreutils() {
  config_sources coreutils-9.3 xz
  patch -Np1 -i ../coreutils-9.3-i18n-1.patch
  autoreconf -fiv
  FORCE_UNSAFE_CONFIGURE=1 ./configure \
            --prefix=/usr            \
            --enable-no-install-program=kill,uptime
  make
  make NON_ROOT_USERNAME=tester check-root
  groupadd -g 102 dummy -U tester
  chown -Rv tester .
  su tester -c "PATH=$PATH make RUN_EXPENSIVE_TESTS=yes check"
  groupdel dummy
  make install
  mv -v /usr/bin/chroot /usr/sbin
  mv -v /usr/share/man/man1/chroot.1 /usr/share/man/man8/chroot.8
  sed -i 's/"1"/"8"/' /usr/share/man/man8/chroot.8
  clean_sources coreutils-9.3
  log_compil_end "coreutils"
}

install_check() {
  config_sources check-0.15.2 gz
  ./configure --prefix=/usr --disable-static
  make
  make check
  make docdir=/usr/share/doc/check-0.15.2 install
  clean_sources check-0.15.2
  log_compil_end "check"

}

install_diffutils() {
  config_sources diffutils-3.10 xz
  ./configure --prefix=/usr
  make
  make check
  make install
  clean_sources diffutils-3.10
  log_compil_end "diffutils"
}

install_gawk() {
  config_sources gawk-5.2.2 xz
  sed -i 's/extras//' Makefile.in
  ./configure --prefix=/usr
  make
  chown -Rv tester .
  su tester -c "PATH=$PATH make check"
  make LN='ln -f' install
  ln -sv gawk.1 /usr/share/man/man1/awk.1
  mkdir -pv                                   /usr/share/doc/gawk-5.2.2
  cp    -v doc/{awkforai.txt,*.{eps,pdf,jpg}} /usr/share/doc/gawk-5.2.2
  clean_sources gawk-5.2.2
  log_compil_end "gawk"
}

install_find_utils() {
  config_sources findutils-4.9.0 xz
  ./configure --prefix=/usr --localstatedir=/var/lib/locate
  make
  chown -Rv tester .
  su tester -c "PATH=$PATH make check"
  make install
  clean_sources findutils-4.9.0
  log_compil_end "findutils"
}

install_groff() {
  config_sources groff-1.23.0 gz
  PAGE=A4 ./configure --prefix=/usr
  make check
  make install
  clean_sources groff-1.23.0
  log_compil_end groff
}

install_grub() {
  config_sources grub-2.06 xz
  unset {C,CPP,CXX,LD}FLAGS
  patch -Np1 -i ../grub-2.06-upstream_fixes-1.patch
  ./configure --prefix=/usr          \
            --sysconfdir=/etc      \
            --disable-efiemu       \
            --disable-werror
  make
  make install
  mv -v /etc/bash_completion.d/grub /usr/share/bash-completion/completions
  clean_sources grub-2.06
  log_compil_end "grub"
}

install_gzip() {
  config_sources gzip-1.12 xz
  ./configure --prefix=/usr
  make
  make check
  make install
  clean_sources gzip-1.12
  log_compil_end "gzip"
}

install_iproute() {
  config_sources iproute2-6.4.0 xz
  sed -i /ARPD/d Makefile
  rm -fv man/man8/arpd.8
  make NETNS_RUN_DIR=/run/netns
  make SBINDIR=/usr/sbin install
  mkdir -pv             /usr/share/doc/iproute2-6.4.0
  cp -v COPYING README* /usr/share/doc/iproute2-6.4.0
  clean_sources iproute2-6.4.0
  log_compil_end "iproute"
}

install_kbd() {
  config_sources kbd-2.6.1 xz
  patch -Np1 -i ../kbd-2.6.1-backspace-1.patch
  sed -i '/RESIZECONS_PROGS=/s/yes/no/' configure
  sed -i 's/resizecons.8 //' docs/man/man8/Makefile.in
  ./configure --prefix=/usr --disable-vlock
  make
  make check
  make install
  cp -R -v docs/doc -T /usr/share/doc/kbd-2.6.1
  clean_sources kbd-2.6.1
  log_compil_end "kbd"
}


install_libpipeline() {
  config_sources libpipeline-1.5.7 gz
  ./configure --prefix=/usr
  make
  make check
  make install
  clean_sources libpipeline-1.5.7
  log_compil_end "libpipeline"
}


install_make() {
  config_sources make-4.4.1 gz
  ./configure --prefix=/usr
  make
  chown -Rv tester .
  su tester -c "PATH=$PATH make check"
  make install
  clean_sources make-4.4.1
  log_compil_end "make"
}

install_patch() {
  config_sources patch-2.7.6 xz
  ./configure --prefix=/usr
  make
  make check
  make install
  clean_sources patch-2.7.6
  log_compil_end "patch"
}

install_tar() {
  config_sources tar-1.35 xz
  FORCE_UNSAFE_CONFIGURE=1  \
    ./configure --prefix=/usr
  make
  make check TESTFLAGS="$MAKEFLAGS"
  make install
  make -C doc install-html docdir=/usr/share/doc/tar-1.35
  clean_sources tar-1.35
  log_compil_end "tar"
}

install_texinfo() {
  config_sources texinfo-7.0.3 xz
  ./configure --prefix=/usr
  make
  make check
  make install
  make TEXMF=/usr/share/texmf install-tex
  cd /usr/share/info
  rm -v dir
  for f in *
    do install-info $f dir 2>/dev/null
  done
  cd /sources
  clean_sources texinfo-7.0.3
  log_compil_end "texinfo"
}

install_vim() {
  config_sources vim-9.0.1667 gz
  echo '#define SYS_VIMRC_FILE "/etc/vimrc"' >> src/feature.h
  ./configure --prefix=/usr
  make
  chown -Rv tester .
  su tester -c "LANG=en_US.UTF-8 make -j1 test" &> vim-test.log
  make install
  ln -sv vim /usr/bin/vi
  for L in  /usr/share/man/{,*/}man1/vim.1; do
    ln -sv vim.1 $(dirname $L)/vi.1
  done
  ln -sv ../vim/vim90/doc /usr/share/doc/vim-9.0.1677
cat > /etc/vimrc << "EOF"
" Begin /etc/vimrc

" Ensure defaults are set before customizing settings, not after
source $VIMRUNTIME/defaults.vim
let skip_defaults_vim=1

set nocompatible
set backspace=2
set mouse=
set spelllang=en,fr
set spell
syntax on
if (&term == "xterm") || (&term == "putty")
  set background=dark
endif

" End /etc/vimrc
EOF
  clean_sources vim-9.0.1667
  log_compil_end "vim"
}

install_markupsafe() {
  config_sources MarkupSafe-2.1.3 gz
  pip3 wheel -w dist --no-build-isolation --no-deps $PWD
  pip3 install --no-index --no-user --find-links dist Markupsafe
  clean_sources MarkupSafe-2.1.3
  log_compil_end "markupsafe"
}

install_jinja() {
  config_sources Jinja2-3.1.2 gz
  pip3 wheel -w dist --no-build-isolation --no-deps $PWD
  pip3 install --no-index --no-user --find-links dist Jinja2
  clean_sources Jinja2-3.1.2
  log_compil_end "jinja"
}

install_udev_systemd_254() {
  #TODO: might have to modify this if want to install systemd
  config_sources systemd-254 gz
  sed -i -e 's/GROUP="render"/GROUP="video"/' \
        -e 's/GROUP="sgx", //' rules.d/50-udev-default.rules.in
  sed '/systemd-sysctl/s/^/#/' -i rules.d/99-systemd.rules.in
  mkdir -p build
  cd       build

  meson setup \
        --prefix=/usr                 \
        --buildtype=release           \
        -Dmode=release                \
        -Ddev-kvm-mode=0660           \
        -Dlink-udev-shared=false      \
        ..
  ninja udevadm systemd-hwdb \
      $(grep -o -E "^build (src/libudev|src/udev|rules.d|hwdb.d)[^:]*" \
        build.ninja | awk '{ print $2 }')                              \
      $(realpath libudev.so --relative-to .)
  rm rules.d/90-vconsole.rules
  install -vm755 -d {/usr/lib,/etc}/udev/{hwdb,rules}.d
  install -vm755 -d /usr/{lib,share}/pkgconfig
  install -vm755 udevadm                     /usr/bin/
  install -vm755 systemd-hwdb                /usr/bin/udev-hwdb
  ln      -svfn  ../bin/udevadm              /usr/sbin/udevd
  cp      -av    libudev.so{,*[0-9]}         /usr/lib/
  install -vm644 ../src/libudev/libudev.h    /usr/include/
  install -vm644 src/libudev/*.pc            /usr/lib/pkgconfig/
  install -vm644 src/udev/*.pc               /usr/share/pkgconfig/
  install -vm644 ../src/udev/udev.conf       /etc/udev/
  install -vm644 rules.d/* ../rules.d/{*.rules,README} /usr/lib/udev/rules.d/
  install -vm644 hwdb.d/*  ../hwdb.d/{*.hwdb,README}   /usr/lib/udev/hwdb.d/
  install -vm755 $(find src/udev -type f | grep -F -v ".") /usr/lib/udev
  tar -xvf ../../udev-lfs-20230818.tar.xz
  make -f udev-lfs-20230818/Makefile.lfs install
  tar -xf ../../systemd-man-pages-254.tar.xz                            \
    --no-same-owner --strip-components=1                              \
    -C /usr/share/man --wildcards '*/udev*' '*/libudev*'              \
                                  '*/systemd-'{hwdb,udevd.service}.8
  sed 's/systemd\(\\\?-\)/udev\1/' /usr/share/man/man8/systemd-hwdb.8   \
                                > /usr/share/man/man8/udev-hwdb.8
  sed 's|lib.*udevd|sbin/udevd|'                                        \
      /usr/share/man/man8/systemd-udevd.service.8                       \
    > /usr/share/man/man8/udevd.8
  rm  /usr/share/man/man8/systemd-*.8
  udev-hwdb update
  clean_sources systemd-254
  log_compil_end "udev_systemd_254"
}

install_man_db() {
  # TODO: might have to modify this if want to install systemd
  config_sources man-db-2.11.2 xz
  ./configure --prefix=/usr                         \
            --docdir=/usr/share/doc/man-db-2.11.2 \
            --sysconfdir=/etc                     \
            --disable-setuid                      \
            --enable-cache-owner=bin              \
            --with-browser=/usr/bin/lynx          \
            --with-vgrind=/usr/bin/vgrind         \
            --with-grap=/usr/bin/grap             \
            --with-systemdtmpfilesdir=            \
            --with-systemdsystemunitdir=
  make
  make -k check
  make install
  clean_sources man-db-2.11.2
  log_compil_end man-db
}

install_procps_ng() {
  config_sources procps-ng-4.0.3 xz
  ./configure --prefix=/usr                           \
            --docdir=/usr/share/doc/procps-ng-4.0.3 \
            --disable-static                        \
            --disable-kill
  make
  make check
  make install
  clean_sources procps-ng-4.0.3
  log_compil_end procps_ng
}

install_util_linux() {
  config_sources util-linux-2.39.1 xz
  sed -i '/test_mkfds/s/^/#/' tests/helpers/Makemodule.am
  ./configure ADJTIME_PATH=/var/lib/hwclock/adjtime \
            --bindir=/usr/bin    \
            --libdir=/usr/lib    \
            --runstatedir=/run   \
            --sbindir=/usr/sbin  \
            --disable-chfn-chsh  \
            --disable-login      \
            --disable-nologin    \
            --disable-su         \
            --disable-setpriv    \
            --disable-runuser    \
            --disable-pylibmount \
            --disable-static     \
            --without-python     \
            --without-systemd    \
            --without-systemdsystemunitdir \
            --docdir=/usr/share/doc/util-linux-2.39.1
  make
  # Can be dangerous for the system, better to run it as booted or a vm
  # chown -Rv tester .
  # su tester -c "make -k check"
  make install
  clean_sources util-linux-2.39.1
  log_compil_end util_linux
}

install_e2fsprogs() {
  config_sources e2fsprogs-1.47.0 gz
  mkdir -v build
  cd       build
  ../configure --prefix=/usr           \
              --sysconfdir=/etc       \
              --enable-elf-shlibs     \
              --disable-libblkid      \
              --disable-libuuid       \
              --disable-uuidd         \
              --disable-fsck
  make
  make check
  make install
  rm -fv /usr/lib/{libcom_err,libe2p,libext2fs,libss}.a
  gunzip -v /usr/share/info/libext2fs.info.gz
  makeinfo -o      doc/com_err.info ../lib/et/com_err.texinfo
  install -v -m644 doc/com_err.info /usr/share/info
  install-info --dir-file=/usr/share/info/dir /usr/share/info/com_err.info
  sed 's/metadata_csum_seed,//' -i /etc/mke2fs.conf
  clean_sources e2fsprogs-1.47.0
  log_compil_end e2fsprogs
}

install_sysklogd() {
  config_sources sysklogd-1.5.1 gz
  sed -i '/Error loading kernel symbols/{n;n;d}' ksym_mod.c
  sed -i 's/union wait/int/' syslogd.c
  make
  make BINDIR=/sbin install
cat > /etc/syslog.conf << "EOF"
# Begin /etc/syslog.conf

auth,authpriv.* -/var/log/auth.log
*.*;auth,authpriv.none -/var/log/sys.log
daemon.* -/var/log/daemon.log
kern.* -/var/log/kern.log
mail.* -/var/log/mail.log
user.* -/var/log/user.log
*.emerg *

# End /etc/syslog.conf
EOF
  clean_sources sysklogd-1.5.1
  log_compil_end sysklogd
}

install_sysvinit() {
  config_sources sysvinit-3.07 xz
  patch -Np1 -i ../sysvinit-3.07-consolidated-1.patch
  make
  make install
  clean_sources sysvinit-3.07
  log_compil_end sysvinit
}

cleanup() {
  rm -rf /tmp/*
  find /usr/lib /usr/libexec -name \*.la -delete
  find /usr -depth -name $(uname -m)-lfs-linux-gnu\* | xargs rm -rf
  userdel -r tester
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
install_gcc
install_pkgconf
install_ncurses
install_sed
install_psmisc
install_gettext
install_bison
install_grep
install_bash
install_libtool
install_gdbm
install_gperf
install_expat
install_inetutils
install_less
install_perl
install_xml_parser
install_intltool
install_autoconf
install_automake
install_openssl
install_kmod
install_libelf
install_libffi
install_python
install_flit_core
install_wheel
install_ninja
install_meson
install_coreutils
install_check
install_diffutils
install_gawk
install_findutils
install_groff
install_grub
install_gzip
install_iproute
install_kbd
install_libpipeline
install_make
install_patch
install_tar
install_texinfo
install_vim
install_markupsafe
install_jinja
install_udev_systemd_254
install_man_db
install_procps_ng
install_util_linux
install_e2fsprogs
install_sysklogd
install_sysvinit