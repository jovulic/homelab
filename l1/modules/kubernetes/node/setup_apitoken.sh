#!/usr/bin/env bash

set -e

mkdir -p /var/lib/kubernetes/secrets
chmod 0755 /var/lib/kubernetes/secrets

cp "@apitoken_file@" /var/lib/kubernetes/secrets/apitoken.secret
