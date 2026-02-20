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

  # List all host directories with a default.nix.
  hostDirs = builtins.attrNames (
    lib.filterAttrs (
      name: type: type == "directory" && builtins.pathExists (./hosts + "/${name}/default.nix")
    ) (builtins.readDir ./hosts)
  );

  # Import each host.
  hosts = lib.genAttrs hostDirs (
    name:
    let
      host = pkgs.callPackage (./hosts + "/${name}") {
        inherit
          nixpkgs
          deploy-rs
          system
          ;
      };
    in
    builtins.removeAttrs host [
      "override"
      "overrideDerivation"
    ]
  );

  # Combine all hosts into a single attribute set.
  mergedHosts = lib.mergeAttrsList (builtins.attrValues hosts);
in
mergedHosts
