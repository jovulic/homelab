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
    @echo "Fetched CA certificate fetched and saved to /etc/ssl/certs/ca-homelab.crt and .data/ca.pem"

# Fetch the cluster admin homelab kubeconfig and install it locally.
fetch_kubeconfig:
    ssh root@frost.lan "kubectl --kubeconfig /etc/kubernetes/cluster-admin.kubeconfig config view --flatten" > $HOME/.kube/config-lab.yaml
    @echo "Fetched kubeconfig and saved to $HOME/.kube/config-lab.yaml"

# Pull a host's SSH public key and convert it to an age public key.
host_to_age host:
    ssh-keyscan {{host}}.lan 2>/dev/null | grep ssh-ed25519 | ssh-to-age

# Re-encrypt all secrets using the current keys in .sops.yaml.
refresh_secrets:
    @for f in .data/enc.*; do \
        echo "Refreshing $f..."; \
        sops updatekeys "$f"; \
    done

# Edit the shared cfssl HMAC key secret.
edit_cfssl_auth_key:
    sops .data/enc.cfssl_auth_key.txt

# Fetch the kubernetes apitoken from frost and encrypt it using sops.
fetch_apitoken:
    ssh root@frost.lan "cat /var/lib/cfssl/apitoken.secret"

# Edit the kubernetes apitoken.
edit_apitoken:
    sops .data/enc.apitoken.secret
