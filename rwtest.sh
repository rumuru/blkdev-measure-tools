#!/bin/bash
#
# Copyright (c) 2013 Moonkyung Ryu
# 
# This script measures performance of sequential/random read/write of an SSD
# using xdd.
#
# CAUTION: Your data in the target device will be destroyed!
# 
# Usage: rwtest.sh [-f] [-r] [-d ssd device] [-o log file]
# Example: ./rwtest.sh -d /dev/sdd -o ssd12/rwtest.log

if [ $# -lt 2 ]
then
	echo "usage: $0 [-f] [-r] -d device -o logfile"
	exit -1
fi

# Parse arguments
go="N"
readonly=0
while getopts "frd:o:" opt
do
  case ${opt} in
    f)
      go="Y"
      ;;
    r)
      readonly=1
      ;;
    d)
      dev=$OPTARG
      ;;
    o)
      output=$OPTARG
      ;;
  esac
done

if [ $readonly == 1 ]
then
  echo "Only read performance will be measured."
fi

if [ $go != "Y" ]
then
  echo -ne "Your data in device $dev will be destroyed!\nAre you sure to proceed? [Y/N] "
  read go
  go=`echo $go | tr '[:lower:]' '[:upper:]'`
  if [ $go != "Y" ]
  then
    exit 0
  fi
fi


fill_dev()
{
  dev=$1
  capa_mbytes=$2
  blk_size=$3     # in Bytes

  # First, fill up the device sequentially in full.
  xdd -op write -dio -verbose -datapattern random -mbytes $capa_mbytes -targets 1 $dev -blocksize $blk_size -reqsize 1

  # Second, additional writes to exhaust over-provisioned capacity.
  # Guess sufficiently large amount of over-provision ratio (20%)
  overprov_mbytes=`echo "$capa_mbytes * 0.2" | bc`
  xdd -op write -dio -verbose -datapattern random -mbytes $overprov_mbytes -targets 1 $dev -blocksize $blk_size -reqsize 1
}


# Capacity in Bytes
capacity=`/sbin/fdisk -l $dev | sed -n '/^Disk.* bytes$/p' | awk '{print $5}'`

# Capacity in MBytes.
capa_mbytes=`echo "$capacity / 1048576" | bc`

# MBytes to read. 40GB.
mbytes=`echo "1024 * 40" | bc`


# sequential read
echo "--seq read test--" >> $output
for b in 65536 32768 16384 8192 4096 2048 1024 512 256 128 64 32 16 8 4  # Block size in KB.
do
  b=`echo "$b * 1024" | bc`    # to bytes
  xdd -op read -dio -verbose -mbytes $mbytes -targets 1 $dev -blocksize $b -reqsize 1 -csvout /tmp/xddlog.tmp
	cat /tmp/xddlog.tmp >> $output
done

# randome read
echo "--rand read test--" >> $output
for b in 65536 32768 16384 8192 4096 2048 1024 512 256 128 64 32 16 8 4
do
  # Seek range in blocks for random reads.
  b=`echo "$b * 1024" | bc`    # to bytes
  srange=`echo "$capacity / $b" | bc`
	xdd -op read -dio -verbose -mbytes $mbytes -targets 1 $dev -blocksize $b -reqsize 1 -csvout /tmp/xddlog.tmp -randomize -seek random -seek range $srange
	cat /tmp/xddlog.tmp >> $output
done

if [ $readonly == 0 ]
then
  # Initialize the device via TRIM
  ./wipe_dev.sh $dev
  sleep 60

  # Warm up the device with 1MB writes
  fill_dev $dev $capa_mbytes 1048576
  sleep 60

  # sequential write
  echo "--seq write test--" >> $output
  for b in 65536 32768 16384 8192 4096 2048 1024 512 256 128 64 32 16 8 4
  do
    b=`echo "$b * 1024" | bc`    # to bytes
  
  	xdd -op write -dio -verbose -datapattern random -mbytes $capa_mbytes -targets 1 $dev -blocksize $b -reqsize 1 -csvout /tmp/xddlog.tmp
  	cat /tmp/xddlog.tmp >> $output
  done
  
  # random write
  echo "--rand write test--" >> $output
  for b in 65536 32768 16384 8192 4096 2048 1024 512 256 128 64 32 16 8 4
  do
    # Seek range in blocks for random writes.
    b=`echo "$b * 1024" | bc`    # to bytes
    srange=`echo "$capacity / $b" | bc`
  
  	xdd -op write -dio -verbose -datapattern random -mbytes $capa_mbytes -targets 1 $dev -blocksize $b -reqsize 1 -csvout /tmp/xddlog.tmp -randomize -seek random -seek range $srange
  	cat /tmp/xddlog.tmp >> $output
  done
fi


# remove temporary files
rm -rf /tmp/xddlog.tmp

chown -R rumuru:rumuru $output
