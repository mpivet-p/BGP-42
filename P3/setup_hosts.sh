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
		dexe $1 "ip addr add 20.1.1.$3/24 dev eth1"
	else
		echo "Warning: $2 already configured!"
	fi
}

for line in $(docker ps -q); do
	name=$(docker exec $line hostname);
	host_type=${name%%_*}
	host_nbr=${name##*-}

	echo "Configuring $name ($line)...";

	if [[ $host_type == "host" ]]; then
		config_host $line $name $host_nbr
	fi
done
