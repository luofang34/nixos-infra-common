# Periodic self-update: pull the host's flake repo, refresh selected
# flake inputs, rebuild the system. Pulled out of infra-agentcoder where
# it was a per-business copy with auth's URL hardcoded; the option
# surface lets any infra-<workload> host opt in by setting the relevant
# values in its local.nix / hosts entry.
#
# Design notes:
#
#   * `flakeInputs = [ ]` updates every input each cycle (a full
#     `nix flake update`). Set it to `[ "claude-code" "codex-cli" ]` —
#     or similar — to keep the cadence cheap and prevent a nixpkgs roll
#     from triggering a heavy rebuild every hour.
#   * The local clone under /var/lib is `git reset --hard origin/<branch>`
#     each cycle. Lock-file churn from `nix flake update` is intentionally
#     not pushed back upstream; that path stays an operator decision.
#   * Runs as root because `nixos-rebuild switch` needs to set the system
#     profile.
{ config, pkgs, lib, ... }:

let
  cfg = config.local.autoUpdate;
in {
  options.local.autoUpdate = {
    enable = lib.mkEnableOption "periodic flake update + nixos-rebuild";

    flakeRepo = lib.mkOption {
      type = lib.types.str;
      description = "Git URL of the flake to pull each cycle.";
      example = "https://github.com/your-org/infra-<workload>.git";
    };

    flakeBranch = lib.mkOption {
      type = lib.types.str;
      default = "main";
      description = "Branch tracked on the flake repo.";
    };

    hostAttr = lib.mkOption {
      type = lib.types.str;
      description = ''
        Name of the `nixosConfigurations.<hostAttr>` attribute to
        switch to. Usually the host's hostname.
      '';
    };

    flakeInputs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Flake inputs to refresh each cycle. Empty list means a full
        `nix flake update`, which may pull a fresh nixpkgs each tick
        and trigger heavy rebuilds. Scope it to the inputs you
        actually want fast-tracked (e.g. `[ "claude-code" "codex-cli" ]`).
      '';
    };

    onCalendar = lib.mkOption {
      type = lib.types.str;
      default = "hourly";
      description = "systemd OnCalendar expression for the timer.";
    };

    workingDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/infra-auto-update";
      description = "Filesystem path the service clones the repo into.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.infra-auto-update = {
      description = "Pull ${cfg.flakeRepo}, update inputs, rebuild";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      path = with pkgs; [ git nix nixos-rebuild coreutils gnused ];
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
      script = ''
        set -euo pipefail

        if [ ! -d "${cfg.workingDir}/.git" ]; then
          rm -rf "${cfg.workingDir}"
          git clone --branch "${cfg.flakeBranch}" "${cfg.flakeRepo}" "${cfg.workingDir}"
        fi

        cd "${cfg.workingDir}"
        git fetch origin "${cfg.flakeBranch}"
        # Reset to upstream so locally-drifted lock files (e.g. previous
        # auto-update runs) don't block fast-forward. Lock churn is
        # intentionally not pushed back.
        git reset --hard "origin/${cfg.flakeBranch}"

        ${if cfg.flakeInputs == [] then ''
          nix flake update
        '' else ''
          nix flake update ${lib.concatStringsSep " " cfg.flakeInputs}
        ''}

        nixos-rebuild switch --flake ".#${cfg.hostAttr}"
      '';
    };

    systemd.timers.infra-auto-update = {
      description = "${cfg.onCalendar} flake refresh + rebuild";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.onCalendar;
        Persistent = true;
        RandomizedDelaySec = "15min";
      };
    };
  };
}
