# shellcheck shell=bash

set -veuo pipefail

# Ensure the directories exist
install -d -m 755 -o root -g root /var/lib/kubernetes/secrets
install -d -m 700 -o cfssl -g cfssl /var/lib/cfssl

if [[ ! -e "/var/lib/cfssl/ca.pem" ]]; then
  install -m 644 -o cfssl -g cfssl "/var/lib/certs/@certificate_name@.pem" /var/lib/cfssl/ca.pem
  install -m 600 -o cfssl -g cfssl "/var/lib/certs/@certificate_name@-key.pem" /var/lib/cfssl/ca-key.pem
fi

if [[ ! -e "/var/lib/kubernetes/secrets/ca.pem" ]]; then
  install -m 644 -o root -g root "/var/lib/certs/@certificate_name@.pem" /var/lib/kubernetes/secrets/ca.pem
fi

if [[ ! -e "/var/lib/kubernetes/secrets/ca-key.pem" ]]; then
  install -m 600 -o kubernetes -g nogroup "/var/lib/certs/@certificate_name@-key.pem" /var/lib/kubernetes/secrets/ca-key.pem
fi
