{ lib, ... }:
{
  htypes = {
    sopsSecret = lib.types.submodule {
      options = {
        secret = lib.mkOption {
          type = lib.types.attrs;
          description = "The sops-nix secret attribute set.";
        };
        placeholder = lib.mkOption {
          type = lib.types.str;
          description = "The sops-nix placeholder string.";
        };
      };
    };
  };

  mkSopsSecret = config: name: {
    secret = config.sops.secrets.${name};
    placeholder = config.sops.placeholder.${name};
  };
}
