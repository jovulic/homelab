# shellcheck shell=bash

set -veuo pipefail

# Ensure the secrets directory exists
install -d -m 755 -o root -g root /var/lib/kubernetes/secrets

if [[ ! -e "/var/lib/kubernetes/secrets/ca.pem" ]]; then
  install -m 644 -o root -g root "/var/lib/certs/@certificate_name@.pem" /var/lib/kubernetes/secrets/ca.pem
fi

if [[ ! -e "/var/lib/kubernetes/secrets/ca-key.pem" ]]; then
  install -m 600 -o kubernetes -g nogroup "/var/lib/certs/@certificate_name@-key.pem" /var/lib/kubernetes/secrets/ca-key.pem
fi
