#!/bin/bash

dexe()
{
	docker exec $1 $2
}

dcopy()
{
	docker cp $2 $1:/tmp/setup
}

config_router()
{
	interface=0
	if [[ $3 -eq 2 ]]; then
		interface=1
	fi
	if (( $3 > 1 )); then #If not RR, create vxlan and bridge
		dexe $1 "ip link add vxlan10 type vxlan id 10 dstport 4789 local 1.1.1.$3 nolearning"
		dexe $1 "/usr/sbin/brctl addbr br0"
		dexe $1 "/usr/sbin/brctl addif br0 vxlan10"
		dexe $1 "/usr/sbin/brctl addif br0 eth$interface"
		dexe $1 "/usr/sbin/brctl stp br0 off"
		dexe $1 "ip link set br0 up"
		dexe $1 "ip link set vxlan10 up"
	fi

	#Copy and apply the corresponding configuration
	dcopy $1 "router_mpivet-p-$3"
	docker exec $1 /bin/ash -c "vtysh </tmp/setup"
}

for line in $(docker ps -q); do
	name=$(docker exec $line hostname);
	host_type=${name%%_*}
	host_nbr=${name##*-}

	echo "Configuring $name ($line)...";

	if [[ $host_type == "router" ]]; then
		config_router $line $name $host_nbr
	else
		echo -e "\033[93mWarning\033[0m: Unknown container $name!" 1>&2
	fi
done
