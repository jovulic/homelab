# shellcheck shell=bash
set -veuo pipefail
echo "Starting pixiecore..."
pixiecore api http://127.0.0.1:8081 --port 8080 --dhcp-no-bind --debug
