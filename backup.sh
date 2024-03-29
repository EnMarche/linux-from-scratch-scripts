#!/bin/bash

set -euo pipefail

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit 1
fi

if [ -n "$LFS" ]; then
    echo "Preparing backup"
else
    echo "LFS Variable not set"
    exit 1
fi

HOME=$(eval  echo ~$SUDO_USER)

backup() {
  echo backing up $LFS
  mountpoint -q $LFS/dev/shm && umount $LFS/dev/shm
  mountpoint -q $LFS/dev/pts && umount -f $LFS/dev/pts
  mountpoint -q $LFS/sys && umount -f $LFS/sys
  mountpoint -q $LFS/proc && umount -f $LFS/proc
  mountpoint -q $LFS/run && umount -f $LFS/run
  mountpoint -q $LFS/dev && umount -f $LFS/dev

  cd $LFS
  tar -cJpfv $HOME/lfs-temp-tools-12.0.tar.xz .
}


restore() {
  echo LFS: $LFS
  echo This script is dangerous, it will delete everything in $LFS before restoring the backup
  echo Is this the right directory? [y/n]
  read answer
  if [ "$answer" != "${answer#[Yy]}" ] ;then
      echo "Continuing..."
      echo restoring
  else
      echo "Exiting..."
      exit 1
  fi

  cd $LFS
  rm -rf ./*
  tar -xpf $HOME/lfs-temp-tools-12.0.tar.xz

  mount -v --bind /dev $LFS/dev
  mount -v --bind /dev/pts $LFS/dev/pts
  mount -vt proc proc $LFS/proc
  mount -vt sysfs sysfs $LFS/sys
  mount -vt tmpfs tmpfs $LFS/run
  if [ -h $LFS/dev/shm ]; then
    mkdir -pv $LFS/$(readlink $LFS/dev/shm)
  else
    mount -t tmpfs -o nosuid,nodev tmpfs $LFS/dev/shm
  fi
  chroot "$LFS" /usr/bin/env -i   \
    HOME=/root                  \
    TERM="$TERM"                \
    PS1='(lfs chroot) \u:\w\$ ' \
    PATH=/usr/bin:/usr/sbin     \
    /bin/bash --login
}

usage() {
    echo "Usage: $0 [OPTIONS]" 1>&2;
    echo -ne "Options:\n  -b  Backup \$LFS partition\n"
    echo -ne "  -r  Restore \$LFS partition\n"
    echo -ne "  -m  Only mount virtual filesystem\n"
    echo -ne "  -c  Chroot into lfs\n"
}

mount_vfs() {
  mountpoint -q $LFS/dev || mount -v --bind /dev $LFS/dev
  mountpoint -q $LFS/dev/pts || mount -v --bind /dev/pts $LFS/dev/pts
  mountpoint -q $LFS/proc || mount -vt proc proc $LFS/proc
  mountpoint -q $LFS/sys || mount -vt sysfs sysfs $LFS/sys
  mountpoint -q $LFS/run || mount -vt tmpfs tmpfs $LFS/run
    if [ -h $LFS/dev/shm ]; then
    mkdir -pv $LFS/$(readlink $LFS/dev/shm)
  else
    mountpoint -q $LFS/dev/shm || mount -t tmpfs -o nosuid,nodev tmpfs $LFS/dev/shm
  fi
}

while getopts ":brmc" opt; do
  case ${opt} in
    c )
      chroot "$LFS" /usr/bin/env -i   \
        HOME=/root                  \
        TERM="$TERM"                \
        PS1='(lfs chroot) \u:\w\$ ' \
        PATH=/usr/bin:/usr/sbin     \
        /bin/bash --login
      ;;
    m )
      mount_vfs
      exit 0
      ;;
    b )
      backup
      exit 0
      ;;
    r )
      restore
      exit 0
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

