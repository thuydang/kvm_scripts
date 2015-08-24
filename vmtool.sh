#!/bin/sh


set -x

############ Prerequistes #######################

DIR=$( cd "$( dirname "$0" )" && pwd )

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

do_iptables_restore() {
	sudo iptables-restore "$@"
}

check_bridge_status() {

	modprobe kvm
	modprobe kvm_intel
	modprobe tun

	echo "Check existence... bridge device "$1
	if ! BR_STATUS=$(ifconfig | grep "$1"); then 
		echo "Check existence... BR_STATUS not defined "$1
		BR_STATUS=""
	fi

	#if [ test "${BR_STATUS}" = "" ]; then
	if [ -z "$BR_STATUS" ]; then
	#if [ "$BR_STATUS" = "" ]; then
		echo "Check existence... bridge not exist "$1
		return 1
	else
		echo "Check existence... bridge exist "$1
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

do_dnsmasq() {
	sudo dnsmasq "$@"
}

start_dnsmasq() {
	sudo kill -9 $(cat /var/run/qemu-dnsmasq-$BRIDGE.pid)
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

############
add_filter_rules() {
	BRIDGE=$1
	NETWORK=$2
	NETMASK=$3

sudo iptables -F
sudo iptables -t nat -F
#cat <<EOF
do_iptables_restore <<EOF
*nat
:PREROUTING ACCEPT [61:9671]
:POSTROUTING ACCEPT [121:7499]
:OUTPUT ACCEPT [132:8691]
-A POSTROUTING -s $NETWORK/$NETMASK -j MASQUERADE
COMMIT
# Completed on Fri Aug 24 15:20:25 2007
# Generated by iptables-save v1.3.6 on Fri Aug 24 15:20:25 2007
*filter
:INPUT ACCEPT [1453:976046]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [1605:194911]
-A INPUT -i $BRIDGE -p tcp -m tcp --dport 67 -j ACCEPT
-A INPUT -i $BRIDGE -p udp -m udp --dport 67 -j ACCEPT
-A INPUT -i $BRIDGE -p tcp -m tcp --dport 53 -j ACCEPT
-A INPUT -i $BRIDGE -p udp -m udp --dport 53 -j ACCEPT
-A FORWARD -i $1 -o $1 -j ACCEPT
-A FORWARD -s $NETWORK/$NETMASK -i $BRIDGE -j ACCEPT
-A FORWARD -d $NETWORK/$NETMASK -o $BRIDGE -m state --state RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -o $BRIDGE -j REJECT --reject-with icmp-port-unreachable
-A FORWARD -i $BRIDGE -j REJECT --reject-with icmp-port-unreachable
COMMIT
EOF
}

############
setup_nat() {
	add_filter_rules "$BRIDGE" "10.10.10.1" "255.255.255.0"
}

############ Steps #######################
ISO=Fedora-20-x86_64-netinst.iso
IMAGE=Fedora-x86_64-20-300G-20150130-sda.qcow2
SIZE=300G

create_dirs() {
	# Create directories
	mkdir -p images
	mkdir -p isos
	mkdir -p keys
}

prepare() {
	create_dirs
	create_bridge "$BRIDGE" "10.10.10.1" "255.255.255.0"
	setup_nat
	start_dnsmasq
}

create_image() {
	qemu-img create -f qcow2 $DIR/images/$IMAGE $SIZE
}

install_os() {
	if [ ! -f $DIR/isos/$ISO ]; then
		    #echo "File not found!"
				wget http://archive.fedoraproject.org/pub/fedora/linux/releases/20/Fedora/x86_64/iso/Fedora-20-x86_64-netinst.iso -O $DIR/isos/$ISO
	fi

	create_image
	sudo qemu-kvm -hda $DIR/images/$IMAGE -m 1024 -cdrom $DIR/isos/$ISO -boot order=d \
		-device e1000,netdev=snet0,mac=DE:AD:BE:EF:00:01 \
		-netdev tap,id=snet0,script=$DIR/scripts/qemu-ifup.sh,downscript=$DIR/scripts/qemu-ifdown.sh
}

run_vm() {
	prepare
	sudo qemu-kvm -hda $DIR/images/$IMAGE -m 1024 -cdrom $DIR/isos/$ISO -boot order=c \
		-device e1000,netdev=snet0,mac=DE:AD:BE:EF:00:01 \
		-netdev tap,id=snet0,script=$DIR/scripts/qemu-ifup.sh,downscript=$DIR/scripts/qemu-ifdown.sh
}
############ Main #######################

case $1 in
	prepare)
		prepare
		;;
	install)
		install_os
		;;
	run)
		run_vm
		;;
	test)
		check_bridge_status "br10"
		;;
	*)
	echo "Usage: $(basename $0) (prepare | install | run)"
esac
