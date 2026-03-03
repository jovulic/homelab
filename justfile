# Wipe a device (in preparation for usage in flash).
wipe device:
    @echo "Are you sure you want to wipe device '{{device}}'? (y/N)"
    @read -p "Confirm: " confirm && [ "$confirm" = "y" ] || { echo "Aborted."; exit 1; }
    sudo wipefs -a /{{device}}
    sudo dd if=/dev/zero of={{device}} bs=512 count=10000

# Flash a host's bootstrap iso to a device.
flash host device:
    nix build .#{{host}}-bootstrap
    @echo "Are you sure you want to flash the iso for '{{host}}' to '{{device}}'? (y/N)"
    @read -p "Confirm: " confirm && [ "$confirm" = "y" ] || { echo "Aborted."; exit 1; }
    @echo "Flashing ISO to {{device}}..."
    sudo dd if="$(ls ./result/iso/*.iso)" of={{device}} status=progress conv=fsync
    @echo "Done!"

# Generates and emits the hardware config for the given host. Useful when doing
# initial setup of a new host.
hwconfig host:
    ssh root@{{host}}.lan "nixos-generate-config --show-hardware-config"

# List all hosts.
hosts:
    @nix eval .#nixosConfigurations --apply builtins.attrNames

# Deploy a host.
deploy host *options:
    deploy .#{{host}} {{options}}

# Deploy all hosts.
deploy_all *options:
    deploy . {{options}}

# Fetch the homelab CA certificate from terra and install it locally and in the repo.
fetch_ca:
    ssh root@terra.lan "cat /var/lib/certs/ca.pem" | sudo tee /etc/ssl/certs/ca-homelab.crt > .data/ca.pem
    @echo "Fetched ca certificate fetched and saved to /etc/ssl/certs/ca-homelab.crt and .data/ca.pem"

# Fetch the homelab k8s CA certificate from frost and install it locally and in the repo.
fetch_k8s_ca:
    ssh root@frost.lan "cat /var/lib/certs/k8s-ca.pem" | sudo tee /etc/ssl/certs/k8s-ca-homelab.crt > .data/k8s-ca.pem
    @echo "Fetched k8s ca certificate fetched and saved to /etc/ssl/certs/k8s-ca-homelab.crt and .data/k8s-ca.pem"

# Fetch the cluster admin homelab kubeconfig and install it locally.
fetch_kubeconfig:
    ssh root@frost.lan "kubectl --kubeconfig /etc/kubernetes/cluster-admin.kubeconfig config view --flatten" > $HOME/.kube/config-lab.yaml
    @echo "Fetched kubeconfig and saved to $HOME/.kube/config-lab.yaml"

# Fetch the kubernetes apitoken from frost and encrypt it using sops.
fetch_apitoken:
    ssh root@frost.lan "cat /var/lib/cfssl/apitoken.secret"

# Pull a host's SSH public key and convert it to an age public key.
host_to_age host:
    ssh-keyscan {{host}}.lan 2>/dev/null | grep ssh-ed25519 | ssh-to-age

# Re-encrypt all secrets using the current keys in .sops.yaml.
refresh_secrets:
    @for f in .data/enc.*; do \
        echo "Refreshing $f..."; \
        sops updatekeys "$f"; \
    done

# Select and edit/create a secret from the .data directory.
edit_secret:
    #!/usr/bin/env bash
    set -euo pipefail
    # List of supported secrets.
    secrets=(
        "certificate.cfssl-auth-key"
        "kubernetes.apitoken"
        "identity.admin-password"
        "identity.idm-admin-password"
        "identity.oauth-secret-kubernetes"
    )

    PS3="Select a secret to create or edit: "
    select name in "${secrets[@]}"; do
        if [ -n "$name" ]; then
            sops ".data/enc.$name"
            break
        else
            echo "Invalid selection. Please choose a number from the list above."
        fi
    done
# Set a user's password using the interactive update command.
set_password user:
    #!/usr/bin/env bash
    set -euo pipefail
    # Check if we are logged in AND the session is valid.
    # Kanidm sometimes returns exit code 0 even on 401 SessionExpired, so we check stderr for ERROR.
    if ! kanidm self whoami --url https://identity.lab --name idm_admin 2>&1 | grep -qv "ERROR"; then
        echo "Not logged in or session expired. Logging in as idm_admin..."
        kanidm login --url https://identity.lab --name idm_admin
    fi

    # Ensure MFA is not strictly required for initial password setup.
    echo "Checking mfa policy for idm_all_persons..."
    current_policy=$(kanidm group get idm_all_persons --url https://identity.lab --name idm_admin | grep "credential_type_minimum:" | awk '{print $2}' || echo "unknown")
    if [ "$current_policy" != "any" ]; then
        echo "Lowering mfa requirement for idm_all_persons to 'any'..."
        kanidm group account-policy credential-type-minimum idm_all_persons any --url https://identity.lab --name idm_admin
    fi

    echo "Updating credentials for {{user}}..."
    kanidm person credential update {{user}} --url https://identity.lab --name idm_admin

