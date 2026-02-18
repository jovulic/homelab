{
  description = "My over-engineered home network.";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-25.11";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      flake-parts,
      ...
    }:
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
            ];
          };
          packages = {
          };
        };
    };
}
