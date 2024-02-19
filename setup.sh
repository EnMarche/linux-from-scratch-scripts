#!/bin/bash
set -euo pipefail

# TODO: check if user has prerequisites https://www.linuxfromscratch.org/lfs/view/stable/partintro/generalinstructions.html

usage() {
    echo "Usage: $0 [OPTIONS]" 1>&2;
    echo -ne "Options:\n  -c  Cleanup \$LFS partition before starting script\n"
    echo -ne "  -s  Skip installation of sources\n"
}


if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi


CLEANUP=false
SKIP_INSTALL_PACKAGES=false


while getopts ":cs" opt; do
  case ${opt} in
    c )
      CLEANUP=true
      # Do something here when option -c is passed
      ;;
    s )
      SKIP_INSTALL_PACKAGES=true
      ;;
    \? )
      echo "Invalid option: $OPTARG" 1>&2
      usage
      exit 1
      ;;
    : )
      echo "Option -$OPTARG requires an argument" 1>&2
      usage
      exit 1
      ;;
  esac
done

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

HOME=$(eval  echo ~$SUDO_USER)
LFS=/mnt/lfs
LFS_FILE=$HOME/lfs_disk
LFS_USER=lfs
LFS_PASSWORD=pass





cleanup() {
    rm -rf $LFS/* $LFS/.*
}

create_fake_partition() {
    if [ ! -f "$LFS_FILE" ]; then
        echo creating partition, do not interupt
        dd if=/dev/zero of=$LFS_FILE bs=1G count=20
        mkfs.ext4 $LFS_FILE
        chown $SUDO_USER:$SUDO_USER $LFS_FILE
        echo "Creating fake partition...done"
    fi
}

mount_fake_partition() {
    mkdir -pv $LFS
    if mountpoint $LFS; then
        echo partition already mounted
    else
        mount -v -t ext4 $LFS_FILE $LFS
        echo "Mounting fake partition...done"
    fi
}

setup_md5sums() {
    cd $LFS/sources
    wget https://www.linuxfromscratch.org/lfs/view/systemd/md5sums
    cd $LFS/sources
        md5sum -c md5sums
    cd $LFS
    echo "Setting up md5sums...done"
}

install_packages() {
    echo "Installing packages..."
    echo "$SKIP_INSTALL_PACKAGES"
    if [ "$SKIP_INSTALL_PACKAGES" == "false" ]; then
        rm -rf $LFS/sources
        mkdir -v $LFS/sources
        chmod -v a+wt $LFS/sources
        cd $LFS
        wget https://www.linuxfromscratch.org/lfs/view/systemd/wget-list-systemd --output-file=wget-log-sysv
        wget --input-file=wget-list-systemd --continue --directory-prefix=$LFS/sources
        setup_md5sums
        chown root:root $LFS/sources/*
    fi
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
    groupadd $LFS_USER || true
    useradd -s /bin/bash -g $LFS_USER -m -k /dev/null $LFS_USER || true
    echo $LFS_USER:$LFS_PASSWORD | chpasswd
    # I added the -R option, maybe it's not necessary
    chown -vR $LFS_USER $LFS/{usr{,/*},lib,var,etc,bin,sbin,tools}
    case $(uname -m) in
        x86_64) chown -v $LFS_USER $LFS/lib64 ;;
    esac
}


setup_env() {
echo test
cat > /home/$LFS_USER/.bash_profile << EOF
exec env -i HOME=/home/$LFS_USER TERM=$TERM PS1='\u:\w\$ ' /bin/bash
EOF

cat > /home/$LFS_USER/.bashrc << EOF
set +h
umask 022
LFS=/mnt/lfs
LC_ALL=POSIX
LFS_TGT=$(uname -m)-lfs-linux-gnu
PATH=/usr/bin
if [ ! -L /bin ]; then PATH=/bin:\$PATH; fi
PATH=\$LFS/tools/bin:\$PATH
CONFIG_SITE=\$LFS/usr/share/config.site
export LFS LC_ALL LFS_TGT PATH CONFIG_SITE
EOF

echo "Setting up environment...done"
}


if [ $CLEANUP == true ]; then
    cleanup
fi



create_fake_partition
mount_fake_partition
install_packages
construct_final_lfs
create_lfs_user
setup_env

cp -v $SCRIPT_DIR/build_cross_toolchain.sh $LFS
cp -v $SCRIPT_DIR/build_temp_tools.sh $LFS
cp -v $SCRIPT_DIR/prepare_chroot.sh $LFS
cp -v $SCRIPT_DIR/chroot_build_dirs.sh $LFS
cp -v $SCRIPT_DIR/build_chroot_additional_tools.sh $LFS
cp -v $SCRIPT_DIR/setup_systemv.sh $LFS

echo -ne "\n\n\nNow run the following commands:\n"
echo "su - $LFS_USER"
echo "$LFS/build_cross_toolchain.sh"
