#!/bin/sh
# cpu counters, memory, per-disk busy time, uptime and hottest thermal zone, one value per line
head -n1 /proc/stat
awk '/^MemTotal/ {t=$2} /^MemAvailable/ {a=$2} END {print "mem", t, a}' /proc/meminfo
# whole disks only: field 13 is milliseconds spent doing I/O
awk '$3 ~ /^(nvme[0-9]+n[0-9]+|sd[a-z]+|vd[a-z]+|mmcblk[0-9]+)$/ {print "io", $3, $13}' /proc/diskstats
awk '{print "up", $1}' /proc/uptime
cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | sort -n | tail -n1 | sed 's/^/temp /'
