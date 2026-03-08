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
    sops-nix = {
      url = "github:Mic92/sops-nix";
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
              pkgs.sops
              pkgs.ssh-to-age
              pkgs.kanidm_1_8
              pkgs.pulumi
              pkgs.nodejs
            ];
            shellHook = ''
              storage_path="/mnt/storage"
              pulumi_storage_path="$storage_path/pulumi"
              if [ ! -e "$pulumi_storage_path" ]; then
                mkdir -p "$pulumi_storage_path"
                echo "Created directory $pulumi_storage_path"
              fi

              export REPOSITORY_ROOT="$(git rev-parse --show-toplevel)"
              export PULUMI_BACKEND_URL="file://$pulumi_storage_path"
              export PULUMI_CONFIG_PASSPHRASE="$(gopass show --nosync -n -o homelab/pulumi/passphrase)"
            '';
          };
          packages =
            let
              bootstrapHosts = inputs.nixpkgs.lib.filterAttrs (_name: cfg: cfg ? bootstrap) hosts;
            in
            inputs.nixpkgs.lib.mapAttrs' (name: cfg: {
              name = "${name}-bootstrap";
              value = cfg.bootstrap;
            }) bootstrapHosts;
        };
      flake = {
        nixosConfigurations = lib.mapAttrs (name: cfg: cfg.system) hosts;
        deploy = {
          nodes = lib.foldl' (acc: cfg: acc // cfg.deploy.nodes) { } (builtins.attrValues hosts);
        };
      };
    };
}
