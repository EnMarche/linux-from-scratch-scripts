#!/bin/bash
set -euo pipefail

LFS=/mnt/lfs
LFS_FILE=$HOME/lfs_disk
LFS_PASSWORD=pass

create_fake_partition() {
    dd if=/dev/zero of=$LFS_FILE bs=1G count=20
    echo "Creating fake partition...done"
    mkfs.ext4 $LFS_FILE
}

mount_fake_partition() {
    mkdir -pv $LFS
    mount -v -t ext4 $LFS_FILE $LFS
    echo "Mounting fake partition...done"
}

setup_md5sums() {
    cd /$LFS/sources
    wget https://www.linuxfromscratch.org/lfs/view/stable/md5sums --output-file=md5sums
    pushd $LFS/sources
        md5sum -c md5sums
    popd
    chown root:root $LFS/sources/*
    echo "Setting up md5sums...done"
}

install_packages() {
    mkdir -v $LFS/sources
    chmod -v a+wt $LFS/sources
    cd $LFS
    wget https://www.linuxfromscratch.org/lfs/view/stable/wget-list-sysv --output-file=wget-log-sysv
    wget --input-file=wget-list-sysv --continue --directory-prefix=$LFS/sources
    setup_md5sums
}

construct_final_lfs() {
    mkdir -pv $LFS/{etc,var} $LFS/usr/{bin,lib,sbin}

    for i in bin lib sbin; do
    ln -sv usr/$i $LFS/$i
    done

    case $(uname -m) in
    x86_64) mkdir -pv $LFS/lib64 ;;
    esac

    mkdir -pv $LFS/tools
}

create_lfs_user() {
    groupadd lfs
    useradd -s /bin/bash -g lfs -m -k /dev/null lfs
    echo $LFS_PASSWORD | passwd lfs --stdin
}

setup_env() {
    cat > ~/.bash_profile << EOF
    exec env -i HOME=$HOME TERM=$TERM PS1='\u:\w\$ ' /bin/bash
EOF


    cat > ~/.bashrc << EOF
    set +h
    umask 022
    LFS=/mnt/lfs
    LC_ALL=POSIX
    LFS_TGT=$(uname -m)-lfs-linux-gnu
    PATH=/usr/bin
    if [ ! -L /bin ]; then PATH=/bin:$PATH; fi
    PATH=$LFS/tools/bin:$PATH
    CONFIG_SITE=$LFS/usr/share/config.site
    export LFS LC_ALL LFS_TGT PATH CONFIG_SITE
EOF

    source ~/.bash_profile
    echo "Setting up environment...done"
}

create_fake_partition
mount_fake_partition
install_packages
construct_final_lfs
echo $LFS_PASSWORD | su lfs || true
setup_env