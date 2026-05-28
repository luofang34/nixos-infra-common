{
  description = "Fleet-wide NixOS modules + lib helpers shared across infra-<workload> repos.";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }: {
    nixosModules = rec {
      base          = import ./modules/base.nix;
      shell         = import ./modules/shell.nix;
      time          = import ./modules/time.nix;
      proxmoxGuest  = import ./modules/proxmox-guest.nix;
      network       = import ./modules/network.nix;
      users         = import ./modules/users.nix;
      autoUpdate    = import ./modules/auto-update.nix;
      monitoring    = import ./modules/monitoring.nix;

      # Bundled "everything every fleet host should opt into": baseline
      # nix + locale + sshd (base), zsh + bira (shell), accurate clock
      # (time). The other modules are opt-in because they need a
      # decision per host class (users), have side effects (autoUpdate),
      # or surface listeners (monitoring).
      default = { ... }: {
        imports = [ base shell time ];
      };
    };

    lib = {
      parseShellEnv = import ./lib/parse-shell-env.nix nixpkgs.lib;
    };
  };
}
