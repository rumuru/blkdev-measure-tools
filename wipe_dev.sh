#!/bin/bash

if [ $# -lt 1 ]
then
	echo "usage: $0 device"
	exit -1
fi

dev=$1

# disk capacity in Bytes
capacity=`/sbin/fdisk -l $dev | sed -n '/^Disk.* bytes$/p' | awk '{print $5}'`
sectors=`expr $capacity / 512`
# sectors=340020 # 65535 * 5 + 12345

echo "Wiping $dev $sectors sectors"

start_sector=0
while [ $sectors -gt 0 ]
do
    temp_sectors=65535
    if [ $sectors -gt $temp_sectors ]
    then
        sectors=`expr $sectors - $temp_sectors`
    else
        temp_sectors=$sectors
        sectors=0
    fi

    echo "hdparm --please-destroy-my-drive --trim-sector-ranges $start_sector:$temp_sectors $dev"
    hdparm --please-destroy-my-drive --trim-sector-ranges $start_sector:$temp_sectors $dev

    start_sector=`expr $start_sector + $temp_sectors`
done

echo -n "Syncing disks.. "
sync
echo

# These are for SSDs that do not support TRIM
# fill the whole capacity by big (1MB) seq. writes
# xdd -op write -dio -verbose -mbytes $capa_mbytes -targets 1 $dev -blocksize 1048576 -reqsize 1
# fill first 1G with small (4KB) seq. writes repeatedly
# xdd -op write -dio -verbose -passes 100 -mbytes 1024 -targets 1 $dev -blocksize 4096 -reqsize 1
