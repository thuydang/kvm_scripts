#!/bin/sh


set -x

############ Prerequistes #######################

DIR=$( cd "$( dirname "$0" )" && pwd )

# Create directories
mkdir -p images
mkdir -p isos
mkdir -p keys

# SWITCH 1 Host only network 10.10.10.1
BRIDGE=br0
NETWORK=10.10.10.0
GATEWAY=10.10.10.1
NETMASK=255.255.255.0
DHCPRANGE=10.10.10.2,10.10.10.254

# Optionally parameters to enable PXE support
TFTPROOT=
BOOTP=

# "$@" an array of arguments. I.e, "do_brctl aaa bbb" results in "brctl aaa bbb".
do_brctl() {
	sudo brctl "$@"
}

do_ifconfig() {
	sudo ifconfig "$@"
}


check_bridge_status() {

	modprobe kvm
	modprobe kvm_intel
	modprobe tun

	echo "Check existence... bridge device "$1
	BR_STATUS=$(ifconfig | grep "$1")
	#if [ test "${BR_STATUS}" = "" ]; then
	if [ -z "$BR_STATUS" ]; then
		return 1
	else
		return 0
	fi
}

create_bridge() {
	if check_bridge_status "$1"
		then 
			do_brctl addbr "$1"	
			do_brctl stp "$1" off
			do_brctl setfd "$1" 0
			do_ifconfig "$1" "$2" netmask "$3" up
			#ip a a 2001:db8:1234:5::1:1/64 dev kvmbr0
		else
			echo "Bridge $1 already exist"
		fi
}

create_bridge "$BRIDGE" "10.10.10.1" "255.255.255.0"

do_dnsmasq() {
	dnsmasq "$@"
}

start_dnsmasq() {
	do_dnsmasq \
	--strict-order \
	--except-interface=lo \
	--interface=$BRIDGE \
	--listen-address=$GATEWAY \
	--bind-interfaces \
	--dhcp-range=$DHCPRANGE \
	--conf-file="" \
	--pid-file=/var/run/qemu-dnsmasq-$BRIDGE.pid \
	--dhcp-leasefile=/var/run/qemu-dnsmasq-$BRIDGE.leases \
	--dhcp-no-override \
	${TFTPROOT:+"--enable-tftp"} \
	${TFTPROOT:+"--tftp-root=$TFTPROOT"} \
	${BOOTP:+"--dhcp-boot=$BOOTP"}
}

start_dnsmasq

############ Create image #######################

ISO=Fedora-20-x86_64-netinst.iso
IMAGE=Fedora-x86_64-20-20141008-sda.qcow2
SIZE=300G

qemu-img create -f qcow2 $DIR/images/$IMAGE $SIZE

sudo qemu-kvm -hda $DIR/images/$IMAGE -m 1024 -cdrom $DIR/isos/$ISO -boot order=d \
	-device e1000,netdev=snet0,mac=DE:AD:BE:EF:00:01 \
	-netdev tap,id=snet0,script=$DIR/scripts/qemu-ifup.sh,downscript=$DIR/scripts/qemu-ifdown.sh

