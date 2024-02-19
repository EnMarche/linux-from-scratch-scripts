#!/bin/bash
set -euo pipefail

LFS_USER=lfs
LFS=/mnt/lfs

get_version() {
  curr="$(pwd)"
  cd $LFS/sources
  folder=$(ls -d $1*.tar.*)
  folder_with_ver="$(echo ${folder%*.tar.*})"
  echo ${folder_with_ver/"$1-"/""}
  cd "$curr"
}

compile_binutils() {
    version="$(get_version binutils)"
    cd $LFS/sources
    tar -xf binutils-$version.tar.xz
    cd binutils-$version
    mkdir -pv build
    cd build
    ../configure --prefix=$LFS/tools \
             --with-sysroot=$LFS \
             --target=$LFS_TGT   \
             --disable-nls       \
             --enable-gprofng=no \
             --disable-werror
    make
    make install
    cd $LFS/sources
    rm -rf binutils-$version
    echo -ne "\n\nCompiling binutils...done\n"
    sleep 1
}

install_cross_gcc() {
    # cd $LFS/sources
    # version="$(get_version gcc)"
    # glibc_version="$(get_version glibc)"
    # tar -xf ./gcc-*.tar.xz
    # cd gcc-$version
    # tar -xf ../mpfr-*.tar.xz
    # mv -v "$(ls -d mpfr-*)" mpfr
    # tar -xf ../gmp-*.tar.xz
    # mv -v "$(ls -d gmp-*)" gmp
    # tar -xf ../mpc-*.tar.gz
    # mv -v "$(ls -d mpc-*)" mpc

    # case $(uname -m) in x86_64)
    #     sed -e '/m64=/s/lib64/lib/' \
    #         -i.orig gcc/config/i386/t-linux64
    #     ;;
    # esac

    # mkdir -pv build
    # cd       build

    # ../configure                 \
    # --target=$LFS_TGT         \
    # --prefix=$LFS/tools       \
    # --with-glibc-version=$glibc_version \
    # --with-sysroot=$LFS       \
    # --with-newlib             \
    # --without-headers         \
    # --enable-default-pie      \
    # --enable-default-ssp      \
    # --disable-nls             \
    # --disable-shared          \
    # --disable-multilib        \
    # --disable-threads         \
    # --disable-libatomic       \
    # --disable-libgomp         \
    # --disable-libquadmath     \
    # --disable-libssp          \
    # --disable-libvtv          \
    # --disable-libstdcxx       \
    # --enable-languages=c,c++

    # make && make install

    # cd ..
    # cat gcc/limitx.h gcc/glimits.h gcc/limity.h > \
    # `dirname $($LFS_TGT-gcc -print-libgcc-file-name)`/include/limits.h
    # cd $LFS/sources
    rm -rf gcc-*.tar.*
    echo -ne "\n\nInstalling cross gcc...done\n"
    sleep 1

}

install_linux_headers() {
    cd $LFS/sources
    tar -xf linux-*.tar.xz
    cd "$(ls -d */ | grep linux-)"
    make mrproper
    make headers
    find usr/include -type f ! -name '*.h' -delete
    cp -rv usr/include $LFS/usr
    cd $LFS/sources
    rm -rf "$(ls -d */ | grep linux-)"
    echo -ne "\n\nInstalling linux headers...done\n"
    sleep 1
}

install_glibc() {
    version="$(get_version glibc)"
    cd $LFS/sources
    tar -xf glibc-$version.tar.xz
    cd glibc-$version

    case $(uname -m) in
        i?86)   ln -sfv ld-linux.so.2 $LFS/lib/ld-lsb.so.3
        ;;
        x86_64) ln -sfv ../lib/ld-linux-x86-64.so.2 $LFS/lib64
                ln -sfv ../lib/ld-linux-x86-64.so.2 $LFS/lib64/ld-lsb-x86-64.so.3
        ;;
    esac

    patch -Np1 -i ../glibc-$version-fhs-1.patch
    mkdir -pv build
    cd build
    echo "rootsbindir=/usr/sbin" > configparms
    ../configure                             \
      --prefix=/usr                      \
      --host=$LFS_TGT                    \
      --build=$(../scripts/config.guess) \
      --enable-kernel=4.14               \
      --with-headers=$LFS/usr/include    \
      libc_cv_slibdir=/usr/lib

    make
    make DESTDIR=$LFS install
    sed '/RTLDLIST=/s@/usr@@g' -i $LFS/usr/bin/ldd
    echo 'int main(){}' | $LFS_TGT-gcc -xc -
    readelf -l a.out | grep ld-linux
    rm -v a.out
    cd $LFS/sources
    rm -rf glibc-$version
    echo -ne "\n\nInstalling glibc...done\n"
    sleep 1
}

install_lib_stdc++() {
    cd $LFS/sources
    gcc_version="$(get_version gcc)"
    tar -xf gcc-$gcc_version.tar.xz
    cd gcc-$gcc_version
    mkdir -v build
    cd       build
    ../libstdc++-v3/configure           \
    --host=$LFS_TGT                 \
    --build=$(../config.guess)      \
    --prefix=/usr                   \
    --disable-multilib              \
    --disable-nls                   \
    --disable-libstdcxx-pch         \
    --with-gxx-include-dir=/tools/$LFS_TGT/include/c++/$gcc_version
    ../libstdc++-v3/configure           \
    --host=$LFS_TGT                 \
    --build=$(../config.guess)      \
    --prefix=/usr                   \
    --disable-multilib              \
    --disable-nls                   \
    --disable-libstdcxx-pch         \
    --with-gxx-include-dir=/tools/$LFS_TGT/include/c++/$gcc_version

    make DESTDIR=$LFS install
    cd $LFS/sources
    rm -rf gcc-$gcc_version
    rm -v $LFS/usr/lib/lib{stdc++,stdc++fs,supc++}.la
}

# compile_binutils
install_cross_gcc
install_linux_headers
install_glibc
install_lib_stdc++

echo -ne "\n\n\nNow run the following commands:\n"
echo "$LFS/build_temp_tools.sh"
