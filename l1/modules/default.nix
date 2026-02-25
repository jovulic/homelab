{ ... }:
{
  imports = [
    ./boot.nix
    ./iscsi
    ./monitor.nix
    ./network.nix
    ./nix.nix
    ./tools.nix
    ./user.nix
    ./zfs
  ];
}
