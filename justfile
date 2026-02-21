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

# List all hosts.
hosts:
    @nix eval .#nixosConfigurations --apply builtins.attrNames

# Deploy a host.
deploy host:
    deploy .#{{host}}

# Deploy all hosts.
deploy_all:
    deploy .
