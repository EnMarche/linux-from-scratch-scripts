#!/bin/bash
set -euo pipefail

LFS_USER=lfs
LFS=/mnt/lfs



compile_binutils() {
    cd $LFS/sources
    tar -xf binutils-2.41.tar.xz
    cd binutils-2.41
    mkdir -v build
    cd build
    ../configure --prefix=$LFS/tools \
             --with-sysroot=$LFS \
             --target=$LFS_TGT   \
             --disable-nls       \
             --enable-gprofng=no \
             --disable-werror
    make
    make install
    cd ../..
    rm -rf binutils-2.41
    echo "Compiling binutils...done"
}

install_cross_gcc() {
    cd $LFS/sources

    tar -xf ../mpfr-4.2.0.tar.xz
    mv -v mpfr-4.2.0 mpfr
    tar -xf ../gmp-6.3.0.tar.xz
    mv -v gmp-6.3.0 gmp
    tar -xf ../mpc-1.3.1.tar.gz
    mv -v mpc-1.3.1 mpc

    case $(uname -m) in x86_64)
        sed -e '/m64=/s/lib64/lib/' \
            -i.orig gcc/config/i386/t-linux64
        ;;
    esac

    mkdir -v build
    cd       build

    ../configure                 \
    --target=$LFS_TGT         \
    --prefix=$LFS/tools       \
    --with-glibc-version=2.38 \
    --with-sysroot=$LFS       \
    --with-newlib             \
    --without-headers         \
    --enable-default-pie      \
    --enable-default-ssp      \
    --disable-nls             \
    --disable-shared          \
    --disable-multilib        \
    --disable-threads         \
    --disable-libatomic       \
    --disable-libgomp         \
    --disable-libquadmath     \
    --disable-libssp          \
    --disable-libvtv          \
    --disable-libstdcxx       \
    --enable-languages=c,c++

    make && make install

    cd ..
    cat gcc/limitx.h gcc/glimits.h gcc/limity.h > \
    `dirname $($LFS_TGT-gcc -print-libgcc-file-name)`/include/limits.h

    echo "Installing cross gcc...done"

}

compile_binutils
install_cross_gcc