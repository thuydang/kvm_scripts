#!/bin/sh
set -x

switch=brtmp

if [ -n "$1" ];then
	ifconfig $1 down
	brctl delif br0 $1
	tunctl -d $1

	ifconfig $switch down
	brctl delbr $switch

sleep 0.5s
else
	echo "Error: no interface specified"
	exit 1
fi
