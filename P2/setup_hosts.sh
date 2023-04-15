#!/bin/bash

dexe()
{
	docker exec $1 $2
}


config_host()
{
	dexe $1 'ifconfig eth0' 2>&- 1>&-
	if [[ $? -eq 0 ]]; then
		#Rename eth0
		dexe $1 'ip link set eth0 down'
		dexe $1 'ip link set eth0 name eth1'
		dexe $1 'ip link set eth1 up'
		#Assign IP to eth1
		dexe $1 "ip addr add 30.1.1.$3/24 dev eth1"
	else
		echo "Warning: $2 already configured!"
	fi
}

config_router()
{
	ips=( 1 2 )
	ip=${ips[$3%2]}
	dexe $1 'ifconfig vxlan10' 2>&- 1>&-
	if [[ $? -eq 1 ]]; then
		#Assign ips to interfaces
		dexe $1 "ip addr add 10.1.1.$3/24 dev eth0"

		#Create interfaces
		dexe $1 "ip link add name br0 type bridge"
		#dexe $1 "ip link add name vxlan10 type vxlan id 10 remote 10.1.1.$ip local 10.1.1.$3 dstport 4789 dev eth0"
		dexe $1 "ip link add name vxlan10 type vxlan id 10 group 239.1.1.1 dstport 4789 dev eth0"

		#Set up interfaces
		dexe $1 "ip link set br0 up"
		dexe $1 "ip link set vxlan10 up"

		#Assign master to bridge
		dexe $1 'ip link set vxlan10 master br0'
		dexe $1 'ip link set eth1 master br0'

		#Add unspecified mac-addr to the forwarding table for vxlan10
		dexe $1 "bridge fdb append 00:00:00:00:00:00 dev vxlan10 dst 10.1.1.$ip"
	else
		echo -e "\033[93mWarning\033[0m: $2 already configured!"
	fi
}

for line in $(docker ps -q); do
	name=$(docker exec $line hostname);
	host_type=${name%%_*}
	host_nbr=${name##*-}

	echo "Configuring $name ($line)...";

	if [[ $host_type == "host" ]]; then
		config_host $line $name $host_nbr
	elif [[ $host_type == "router" ]]; then
		config_router $line $name $host_nbr
	else
		echo "Error: Unknown container $name!" 1>&2
	fi
done
