{ ... }:
{
  imports = [
    ./boot.nix
    ./iscsi
    ./monitor.nix
    ./netboot
    ./network.nix
    ./nix.nix
    ./registry
    ./tools.nix
    ./user.nix
    ./zfs
  ];
}
