#!/bin/sh
# cpu counters, memory, root disk usage and hottest thermal zone, one value per line
head -n1 /proc/stat
awk '/^MemTotal/ {t=$2} /^MemAvailable/ {a=$2} END {print "mem", t, a}' /proc/meminfo
df -P / | awk 'NR==2 {print "disk", $5}'
cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | sort -n | tail -n1 | sed 's/^/temp /'
