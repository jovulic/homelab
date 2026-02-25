# shellcheck shell=bash
set -veuo pipefail
ROOT_DIR="/srv/http"
mkdir -p "$ROOT_DIR/v1/file" "$ROOT_DIR/v1/boot"

@setup_hosts@

echo "Starting miniserve..."
miniserve -p 8081 -v "$ROOT_DIR"
