{ ... }:
{
  imports = [
    ./boot.nix
    ./certificate
    ./dns.nix
    ./identity.nix
    ./iscsi
    ./kubernetes
    ./monitor.nix
    ./netboot
    ./network.nix
    ./nix.nix
    ./nvidia.nix
    ./proxy.nix
    ./registry
    ./tools.nix
    ./user.nix
    ./zfs
    ./zfsilo
  ];
}
