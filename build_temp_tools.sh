#!/bin/bash
set -euo pipefail

#TODO ADINA rends ce code propre et stérile comme une seringue avant injection d'anesthésiant


LFS=/mnt/lfs

get_version() {
  curr="$(pwd)"
  cd $LFS/sources
  folder=$(ls -d $1*.tar.*)
  folder_with_ver="$(echo ${folder%*.tar.*})"
  echo ${folder_with_ver/"$1-"/""}
  cd "$curr"
}

config_sources() {
  cd $LFS/sources
  echo extracting $1.tar.*
  tar -xf ${1}*.tar.*
  cd "$(ls -d */ | grep ^${1})"
}

clean_sources() {
  cd $LFS/sources
  rm -rf $(ls -d */ | grep ^${1}*)
}

log_compil_end() {
  echo -ne "\n\nCompiling ${1}...done\n"
  sleep 1
}

compile_m4() {
    config_sources m4 xz
    ./configure --prefix=/usr   \
            --host=$LFS_TGT \
            --build=$(build-aux/config.guess)
    make
    make DESTDIR=$LFS install
    clean_sources m4
    log_compil_end m4
}

compile_ncurses() {
    config_sources ncurses gz
    sed -i s/mawk// configure
    mkdir -pv build
    cd build
      ../configure
      make -C include
      make -C progs tic
    cd ..
    ./configure --prefix=/usr                \
            --host=$LFS_TGT              \
            --build=$(./config.guess)    \
            --mandir=/usr/share/man      \
            --with-manpage-format=normal \
            --with-shared                \
            --without-normal             \
            --with-cxx-shared            \
            --without-debug              \
            --without-ada                \
            --disable-stripping          \
            --enable-widec

    make
    make DESTDIR=$LFS TIC_PATH=$(pwd)/build/progs/tic install
    echo "INPUT(-lncursesw)" > $LFS/usr/lib/libncurses.so

    clean_sources ncurses
    log_compil_end ncurses
}

compile_bash() {
    config_sources bash gz
    ./configure --prefix=/usr                      \
            --build=$(sh support/config.guess) \
            --host=$LFS_TGT                    \
            --without-bash-malloc
    make
    make DESTDIR=$LFS install
    ln -sfv bash $LFS/bin/sh
    clean_sources bash
    log_compil_end bash
}

compile_coreutils() {
    config_sources coreutils xz
    ./configure --prefix=/usr                     \
            --host=$LFS_TGT                   \
            --build=$(build-aux/config.guess) \
            --enable-install-program=hostname \
            --enable-no-install-program=kill,uptime \
            gl_cv_macro_MB_CUR_MAX_good=y
    make
    make DESTDIR=$LFS install
    mv -v $LFS/usr/bin/chroot              $LFS/usr/sbin
    mkdir -pv $LFS/usr/share/man/man8
    mv -v $LFS/usr/share/man/man1/chroot.1 $LFS/usr/share/man/man8/chroot.8
    sed -i 's/"1"/"8"/'                    $LFS/usr/share/man/man8/chroot.8
    clean_sources coreutils
    log_compil_end coreutils
}

compile_diffutils() {
    config_sources diffutils xz
    ./configure --prefix=/usr   \
            --host=$LFS_TGT \
            --build=$(./build-aux/config.guess)
    make
    make DESTDIR=$LFS install
    clean_sources diffutils
    log_compil_end diffutils
}

compile_file() {
  config_sources file gz
  mkdir build
  cd build
  ../configure --disable-bzlib      \
                --disable-libseccomp \
                --disable-xzlib      \
                --disable-zlib
  make
  cd ..
  ./configure --prefix=/usr --host=$LFS_TGT --build=$(./config.guess)
  make FILE_COMPILE=$(pwd)/build/src/file
  make DESTDIR=$LFS install
  rm -v $LFS/usr/lib/libmagic.la
  clean_sources file
  log_compil_end file
}

compile_findutils() {
  config_sources findutils xz
  ./configure --prefix=/usr                   \
            --localstatedir=/var/lib/locate \
            --host=$LFS_TGT                 \
            --build=$(build-aux/config.guess)
  make
  make DESTDIR=$LFS install
  clean_sources findutils
  log_compil_end findutils
}

compile_gawk() {
  config_sources gawk xz
  sed -i 's/extras//' Makefile.in
  ./configure --prefix=/usr   \
            --host=$LFS_TGT \
            --build=$(build-aux/config.guess)
  make
  make DESTDIR=$LFS install
  clean_sources gawk
  log_compil_end gawk
}

compile_grep() {
  config_sources grep xz
  ./configure --prefix=/usr   \
            --host=$LFS_TGT \
            --build=$(./build-aux/config.guess)
  make
  make DESTDIR=$LFS install
  clean_sources grep
  log_compil_end grep
}

compile_gzip() {
  config_sources gzip xz
  ./configure --prefix=/usr   \
            --host=$LFS_TGT
  make
  make DESTDIR=$LFS install
  clean_sources gzip
  log_compil_end gzip
}

compile_make() {
  config_sources make gz
  ./configure --prefix=/usr   \
              --without-guile \
              --host=$LFS_TGT \
              --build=$(build-aux/config.guess)
  make
  make DESTDIR=$LFS install
  clean_sources make
  log_compil_end make
}

compile_patch() {
  config_sources patch xz
./configure --prefix=/usr   \
            --host=$LFS_TGT \
            --build=$(build-aux/config.guess)
  make
  make DESTDIR=$LFS install
  clean_sources patch
  log_compil_end patch
}

compile_sed() {
  config_sources sed xz
  ./configure --prefix=/usr   \
            --host=$LFS_TGT \
            --build=$(build-aux/config.guess)
  make
  make DESTDIR=$LFS install
  clean_sources sed
  log_compil_end sed
}

compile_tar() {
  config_sources tar xz
  ./configure --prefix=/usr   \
            --host=$LFS_TGT \
            --build=$(build-aux/config.guess)
  make
  make DESTDIR=$LFS install
  clean_sources tar
  log_compil_end tar
}

compile_xz() {
  config_sources xz xz
  version="$(get_version xz)"
  ./configure --prefix=/usr                     \
              --host=$LFS_TGT                   \
              --build=$(build-aux/config.guess) \
              --disable-static                  \
              --docdir=/usr/share/doc/xz-$version
  make
  make DESTDIR=$LFS install
  rm -v $LFS/usr/lib/liblzma.la
  clean_sources xz
  log_compil_end xz
}

compile_binutils_pass2() {
  config_sources binutils xz
  sed '6009s/$add_dir//' -i ltmain.sh
  mkdir -pv build
  cd build
  ../configure                   \
    --prefix=/usr              \
    --build=$(../config.guess) \
    --host=$LFS_TGT            \
    --disable-nls              \
    --enable-shared            \
    --enable-gprofng=no        \
    --disable-werror           \
    --enable-64-bit-bfd
  make
  make DESTDIR=$LFS install
  rm -v $LFS/usr/lib/lib{bfd,ctf,ctf-nobfd,opcodes,sframe}.{a,la}
  clean_sources binutils
  log_compil_end "binutils (second pass)"
}

compile_gcc_pass2() {
  config_sources gcc xz
  tar -xf ../mpfr-*.tar.xz
  mv -v "$(ls -d mpfr*)" mpfr
  tar -xf ../gmp-*.tar.xz
  mv -v "$(ls -d gmp*)" gmp
  tar -xf ../mpc-*.tar.gz
  mv -v "$(ls -d mpc*)" mpc
  case $(uname -m) in
    x86_64)
      sed -e '/m64=/s/lib64/lib/' -i.orig gcc/config/i386/t-linux64
    ;;
  esac


  sed '/thread_header =/s/@.*@/gthr-posix.h/' \
      -i libgcc/Makefile.in libstdc++-v3/include/Makefile.in
  mkdir -v build
  cd build
  ../configure                                     \
    --build=$(../config.guess)                     \
    --host=$LFS_TGT                                \
    --target=$LFS_TGT                              \
    LDFLAGS_FOR_TARGET=-L$PWD/$LFS_TGT/libgcc      \
    --prefix=/usr                                  \
    --with-build-sysroot=$LFS                      \
    --enable-default-pie                           \
    --enable-default-ssp                           \
    --disable-nls                                  \
    --disable-multilib                             \
    --disable-libatomic                            \
    --disable-libgomp                              \
    --disable-libquadmath                          \
    --disable-libsanitizer                         \
    --disable-libssp                               \
    --disable-libvtv                               \
    --enable-languages=c,c++
  make
  make DESTDIR=$LFS install
  ln -sv gcc $LFS/usr/bin/cc
  clean_sources gcc
  log_compil_end "gcc (second pass)"
}

compile_m4
compile_ncurses
compile_bash
compile_coreutils
compile_diffutils
compile_file
compile_findutils
compile_gawk
compile_grep
compile_gzip
compile_make
compile_patch
compile_sed
compile_tar
compile_xz
compile_binutils_pass2
compile_gcc_pass2


echo -ne "\n\n\nNow run the following commands as root:\n"
echo "$LFS/prepare_chroot.sh"