#!/bin/sh
#Usage "remote-bandwidth-stats.sh <interface>"
interface=$1
cnt_file="/tmp/bw-stats-count"
#Replace myserver.com with the server url where you kept the remote-bandwidth-stats.php file
address="http://myserver.com/remote-bandwidth-stats.php"
rx=`cat /sys/class/net/$interface/statistics/rx_bytes`
tx=`cat /sys/class/net/$interface/statistics/tx_bytes`
#Give any name to the machine whose bandwidth usage is being logged
name="my-device"

if [ ! -e $cnt_file ]; then
  touch $cnt_file
fi
  
cnt=`cat $cnt_file`
  
if [ -z $cnt ]; then
  cnt=1
else
  cnt=$((cnt+1))
fi
`wget --spider "$address?r=$rx&t=$tx&c=$cnt&n=$name"`
if [ ! $? -gt "0" ]; then
  echo $cnt > $cnt_file
else
  echo $cnt
fi

