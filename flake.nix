{
  description = "My over-engineered home network.";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-25.11";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
    };
    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      # self,
      nixpkgs,
      flake-parts,
      ...
    }:
    let
      lib = inputs.nixpkgs.lib;
      hosts = import ./l1 { inherit inputs; };
    in
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      perSystem =
        {
          # config,
          # self',
          # inputs',
          system,
          pkgs,
          ...
        }:
        {
          _module.args.pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
          devShells.default = pkgs.mkShell {
            packages = [
              pkgs.git
              pkgs.bash
              pkgs.just
              pkgs.deploy-rs
            ];
          };
          packages = inputs.nixpkgs.lib.mapAttrs' (name: cfg: {
            name = "${name}-bootstrap";
            value = cfg.bootstrap;
          }) hosts;
        };
      flake = {
        nixosConfigurations = lib.mapAttrs (name: cfg: cfg.system) hosts;
        deploy = {
          nodes = lib.foldl' (acc: cfg: acc // cfg.deploy.nodes) { } (builtins.attrValues hosts);
        };
      };
    };
}
