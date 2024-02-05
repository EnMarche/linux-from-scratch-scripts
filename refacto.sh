#!/bin/bash

configure_and_make() {
    local package=$1
    local version=$2
    local compression=$3
    shift 3
    local extra_args=("$@")

    config_sources "$package-$version" "$compression"

    case "$package" in
        "ncurses")
            sed -i s/mawk// configure
            mkdir -pv build
            cd build
            ../configure
            make -C include
            make -C progs tic
            cd ..
            ;;
    esac

    ./configure --prefix=/usr \
                --host=$LFS_TGT \
                --build=$(build-aux/config.guess) \
                "${extra_args[@]}"

    make
    make DESTDIR=$LFS install

    case "$package" in
        "coreutils")
            mv -v $LFS/usr/bin/chroot              $LFS/usr/sbin
            mkdir -pv $LFS/usr/share/man/man8
            mv -v $LFS/usr/share/man/man1/chroot.1 $LFS/usr/share/man/man8/chroot.8
            sed -i 's/"1"/"8"/'                    $LFS/usr/share/man/man8/chroot.8
            ;;
        "file")
            make FILE_COMPILE=$(pwd)/build/src/file
            rm -v $LFS/usr/lib/libmagic.la
            ;;
        "ncurses")
            echo "INPUT(-lncursesw)" > $LFS/usr/lib/libncurses.so
            ;;
    esac

    clean_sources "$package-$version"
    log_compil_end "$package"
}

compile_m4() {
    configure_and_make "m4" "1.4.19" "xz"
}

compile_ncurses() {
    configure_and_make "ncurses" "6.4" "gz" \
                       --mandir=/usr/share/man \
                       --with-manpage-format=normal \
                       --with-shared \
                       --without-normal \
                       --with-cxx-shared \
                       --without-debug \
                       --without-ada \
                       --disable-stripping \
                       --enable-widec
}

compile_bash() {
    configure_and_make "bash" "5.2.15" "gz" \
                       --without-bash-malloc
    ln -sfv bash $LFS/bin/sh
}

compile_coreutils() {
    configure_and_make "coreutils" "9.3" "xz" \
                       --enable-install-program=hostname \
                       --enable-no-install-program=kill,uptime \
                       gl_cv_macro_MB_CUR_MAX_good=y
}

compile_diffutils() {
    configure_and_make "diffutils" "3.10" "xz"
}

compile_file() {
    configure_and_make "file" "5.45" "gz" \
                       --disable-bzlib \
                       --disable-libseccomp \
                       --disable-xzlib \
                       --disable-zlib
}

compile_findutils() {
    configure_and_make "findutils" "4.9.0" "xz" \
                       --localstatedir=/var/lib/locate
}

compile_gawk() {
    configure_and_make "gawk" "5.2.2" "xz" \
                       --sed -i 's/extras//' Makefile.in
}

compile_grep() {
    configure_and_make "grep" "3.11" "xz"
}

compile_gzip() {
    configure_and_make "gzip" "1.12" "xz"
}

compile_make() {
    configure_and_make "make" "4.4.1" "gz" \
                       --without-guile
}

compile_patch() {
    configure_and_make "patch" "2.7.6" "xz"
}

compile_sed() {
    configure_and_make "sed" "4.9" "xz"
}

compile_tar() {
    configure_and_make "tar" "1.35" "xz"
}

compile_xz() {
    configure_and_make "xz" "5.4.4" "xz" \
                       --disable-static \
                       --docdir=/usr/share/doc/xz-5.4.4
}

compile_binutils_pass2() {
    configure_and_make "binutils" "2.41" "xz" \
                       --disable-nls \
                       --enable-shared \
                       --enable-gprofng=no \
                       --disable-werror \
                       --enable-64-bit-bfd
    rm -v $LFS/usr/lib/lib{bfd,ctf,ctf-nobfd,opcodes,sframe}.{a,la}
    log_compil_end "binutils (second pass)"
}

compile_gcc_pass2() {
    configure_and_make "gcc" "13.2.0" "xz" \
                       --enable-default-pie \
                       --enable-default-ssp \
                       --disable-nls \
                       --disable-multilib \
                       --disable-libatomic \
                       --disable-libgomp \
                       --disable-libquadmath \
                       --disable-libsanitizer \
                       --disable-libssp \
                       --disable-libvtv \
                       --enable-languages=c,c++
    ln -sv gcc $LFS/usr/bin/cc
    log_compil_end "gcc (second pass)"
}

# Example usage:
# compile_m4
# compile_ncurses
# compile_bash
# compile_coreutils
# compile_diffutils
# compile_file
# compile_findutils
# compile_gawk
# compile_grep
# compile_gzip
# compile_make
# compile_patch
# compile_sed
# compile_tar
# compile_xz
# compile_binutils_pass2
# compile_gcc_pass2
