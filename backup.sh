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


backup() {
  mountpoint -q $LFS/dev/shm && umount $LFS/dev/shm
  umount $LFS/dev/pts
  umount $LFS/{sys,proc,run,dev}

  cd $LFS
  tar -cJpf $HOME/lfs-temp-tools-12.0.tar.xz .
}


restore() {
  echo LFS: $LFS
  echo This script is dangerous, it will delete everything in $LFS before restoring the backup
  echo Is this the right directory? [y/n]
  read answer
  if [ "$answer" != "${answer#[Yy]}" ] ;then
      echo "Continuing..."
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
}

while getopts ":br" opt; do
  case ${opt} in
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

