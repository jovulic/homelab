# shellcheck shell=bash

set -veuo pipefail

# This script is used to generate certificates using cfssl with a remote server.
# It expects the configuration files to be present in /etc/certs/.

mkdir -p /var/lib/certs
chown root:certs /var/lib/certs
chmod 750 /var/lib/certs
cd /var/lib/certs

@generate_remote_certificates@

chmod 644 /var/lib/certs/*.pem
chown root:certs /var/lib/certs/*-key.pem
chmod 640 /var/lib/certs/*-key.pem
