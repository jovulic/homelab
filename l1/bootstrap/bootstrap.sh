# shellcheck shell=bash

set -veuo pipefail

DEVICE="@device@"
DEVICE_P1="${DEVICE}p1"
DEVICE_P2="${DEVICE}p2"
DEVICE_P3="${DEVICE}p3"
HOST_NAME="@hostname@"
USER_KEY="@user_key@"

# Clearing data on device...
wipefs -a $DEVICE
dd if=/dev/zero of=$DEVICE bs=512 count=10000

# Creating paritions...
sfdisk $DEVICE <<EOF
label: gpt
device: $DEVICE
unit: sectors
1 : size=4096 type=0FC63DAF-8483-4772-8E79-3D69D8477DE4
2 : size=512MiB type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B
3 : type=0FC63DAF-8483-4772-8E79-3D69D8477DE4
EOF

# Configuring luks key...
dd if=/dev/urandom of=$DEVICE_P1 bs=4096 count=1

# Configuring boot partition...
mkfs.fat $DEVICE_P2 -F 32 -n boot

# Configuring root parition...
cryptsetup luksFormat $DEVICE_P3 --key-file=$DEVICE_P1 --keyfile-size=4096
cryptsetup open $DEVICE_P3 cryptroot --key-file=$DEVICE_P1 --keyfile-size=4096
pvcreate /dev/mapper/cryptroot
vgcreate pool /dev/mapper/cryptroot
lvcreate -l '100%FREE' -n root pool
mkfs.ext4 /dev/pool/root -L root

# Mounting partitions and installing NixOS...
mkdir -p /mnt
mount /dev/pool/root /mnt

mkdir -p /mnt/boot
mount $DEVICE_P2 /mnt/boot

nixos-generate-config --root /mnt
mv /mnt/etc/nixos/configuration.nix /mnt/etc/nixos/configuration-original.nix
cat >/mnt/etc/nixos/configuration.nix <<EOF
{ config, pkgs, lib, ... }:
{
  imports = [
    ./configuration-original.nix
    ./hardware-configuration.nix
  ];
  nix = {
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };
  boot = {
    initrd.luks.devices.luksroot = {
      device = "$DEVICE_P3";
      allowDiscards = true;
      keyFileSize = 4096;
      keyFile = "$DEVICE_P1";
    };
  };
  fileSystems."/" = lib.mkForce {
    device = "/dev/disk/by-label/root";
    fsType = "ext4";
  };
  fileSystems."/boot" = lib.mkForce {
    device = "/dev/disk/by-label/boot";
    fsType = "vfat";
  };
  networking = {
    useNetworkd = true;
    hostName = "$HOST_NAME";
  };
  systemd = {
    network.wait-online.enable = false;
  };
  users.users.root = {
    openssh.authorizedKeys.keys = [ "$USER_KEY" ];
  };
  services.openssh.enable = true;
  services.getty.autologinUser = "root";
  @ignore_lid_switch@
}
EOF
nixos-install --no-root-passwd --option experimental-features 'nix-command flakes'

# Rebooting...
umount /mnt/boot /mnt
shutdown -r +1
