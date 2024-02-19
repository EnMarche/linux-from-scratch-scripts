#!/bin/bash

set -euo pipefail

install_lfs_bootscripts() {
  cd /sources
  tar -xf lfs-bootscripts-20230728.tar.xz
  cd lfs-bootscripts-20230728
  make install
}

install_lfs_bootscripts


setup_network() {
  # TODO: follow the BLFS setup to use DHCP instead of static IP
bash /usr/lib/udev/init-net-rules.sh
# Get network interface name
eval `tail -n1 /etc/udev/rules.d/70-persistent-net.rules | tr " " "\n" | grep NAME`
cd /etc/sysconfig/
cat > ifconfig.eth0 << EOF
ONBOOT=yes
IFACE="$NAME"
SERVICE=ipv4-static
IP=10.109.255.202
GATEWAY=10.109.1.1
PREFIX=16
BROADCAST=10.109.255.255
EOF
}

setup_dns_resolution() {
cat > /etc/resolv.conf << EOF
# Begin /etc/resolv.conf

# domain <Your Domain Name> # not used
nameserver 208.67.222.222 #openDNS
nameserver 208.67.220.220 #openDNS

# End /etc/resolv.conf
EOF
}

setup_hostname() {
  echo "macronos-lfs" > /etc/hostname
}

setup_hosts() {
cat > /etc/hosts << EOF
# Begin /etc/hosts

127.0.0.1 localhost.localdomain localhost
::1       localhost ip6-localhost ip6-loopback
ff02::1   ip6-allnodes
ff02::2   ip6-allrouters

# End /etc/hosts
EOF
}

configure_sysvinit() {


cat > /etc/inittab << EOF
# Begin /etc/inittab

id:3:initdefault:

si::sysinit:/etc/rc.d/init.d/rc S

l0:0:wait:/etc/rc.d/init.d/rc 0
l1:S1:wait:/etc/rc.d/init.d/rc 1
l2:2:wait:/etc/rc.d/init.d/rc 2
l3:3:wait:/etc/rc.d/init.d/rc 3
l4:4:wait:/etc/rc.d/init.d/rc 4
l5:5:wait:/etc/rc.d/init.d/rc 5
l6:6:wait:/etc/rc.d/init.d/rc 6

ca:12345:ctrlaltdel:/sbin/shutdown -t1 -a -r now

su:S06:once:/sbin/sulogin
s1:1:respawn:/sbin/sulogin

1:2345:respawn:/sbin/agetty --noclear tty1 9600
2:2345:respawn:/sbin/agetty tty2 9600
3:2345:respawn:/sbin/agetty tty3 9600
4:2345:respawn:/sbin/agetty tty4 9600
5:2345:respawn:/sbin/agetty tty5 9600
6:2345:respawn:/sbin/agetty tty6 9600

# End /etc/inittab
EOF
}

configure_time() {
  cat > /etc/sysconfig/clock << EOF
# Begin /etc/sysconfig/clock

UTC=1

# Set this to any options you might need to give to hwclock,
# such as machine hardware clock type for Alphas.
CLOCKPARAMS=

# End /etc/sysconfig/clock
EOF
}