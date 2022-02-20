#!/bin/bash
time_kill=$(( {{ time_all }} + 300 ))
while true;do
yandex-tank -c /root/load_TAPS_Jmeter.yaml&
sleep $time_kill; 
killall -s SIGINT yandex-tank & killall -9 java & killall -9 tap; 
break; 
done
