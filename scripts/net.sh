#!/bin/sh
# total received and sent bytes across real interfaces
awk '$1 !~ /^(lo|docker|veth|br-|virbr)/ && NR > 2 {sub(":", " "); rx += $2; tx += $10} END {print rx + 0, tx + 0}' /proc/net/dev
