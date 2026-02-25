{ ... }:
{
  imports = [
    ./boot.nix
    ./iscsi
    ./monitor.nix
    ./netboot
    ./network.nix
    ./nix.nix
    ./tools.nix
    ./user.nix
    ./zfs
  ];
}
