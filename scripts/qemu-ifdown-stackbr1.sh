#!/bin/sh
set -x

switch=br0

if [ -n "$1" ];then
	ifconfig $1 down
	brctl delif br0 $1
	tunctl -d $1

	ifconfig br0 down
	brctl delbr br0

sleep 0.5s
else
	echo "Error: no interface specified"
	exit 1
fi
