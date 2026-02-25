{
  inputs,
  ...
}:
let
  system = "x86_64-linux";
  pkgs = import inputs.nixpkgs {
    inherit system;
    config.allowUnfree = true;
  };
  inherit (inputs) nixpkgs deploy-rs;
  inherit (pkgs) lib;

  # NOTE: We ignore phantom as the machine is currently in-use elsewhere.
  ignoredHosts = [ "phantom" ];

  # List all host directories with a default.nix.
  hostDirs = builtins.attrNames (
    lib.filterAttrs (
      name: type:
      type == "directory"
      && builtins.pathExists (./hosts + "/${name}/default.nix")
      && !builtins.elem name ignoredHosts
    ) (builtins.readDir ./hosts)
  );

  # Import each host.
  hosts = lib.fix (
    self:
    lib.genAttrs hostDirs (
      name:
      import (./hosts + "/${name}/default.nix") {
        inherit
          nixpkgs
          deploy-rs
          lib
          ;
        hosts = self;
      }
    )
  );
in
hosts
