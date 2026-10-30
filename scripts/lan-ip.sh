#!/usr/bin/env bash
#
# Prints the notebook's IPv4 address on the local network: the source address
# of the default route, so Docker bridges and IPv6 never come out.

set -euo pipefail

ip -4 route get 1.1.1.1 | grep -oP 'src \K\S+'
