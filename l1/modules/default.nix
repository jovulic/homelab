{ ... }:
{
  imports = [
    ./boot.nix
    ./certificate
    ./dns.nix
    ./iscsi
    ./monitor.nix
    ./netboot
    ./network.nix
    ./nix.nix
    ./proxy.nix
    ./registry
    ./tools.nix
    ./user.nix
    ./zfs
  ];
}
