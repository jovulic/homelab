# shellcheck shell=bash

set -veuo pipefail

# This script is used to generate certificates using cfssl.
# It expects the configuration files to be present in /etc/certs/.

mkdir -p /var/lib/certs
cd /var/lib/certs

if [[ ! -e ca.pem ]]; then
  cfssl gencert -initca /etc/certs/ca.json | cfssljson -bare ca
fi

@generate_certificates@

chmod 644 /var/lib/certs/*.pem
chmod 600 /var/lib/certs/*-key.pem
