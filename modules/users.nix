# Fleet user / SSH-key surface.
#
# Today: each host's `local.users` declares the operator pubkeys and a
# small attrset of normal users (interactive accounts the operator
# SSHes into). The module wires those into NixOS — root and every
# declared user get the operator key set, `mutableUsers = false`,
# `wheel` gets passwordless sudo when asked.
#
# Roadmap (deferred, see docs/auth-roadmap.md):
#   * Stage 1 (now)        — static authorized_keys per host, declared
#                             in this module.
#   * Stage 2 (soon)       — SSH certificate authority signed by the
#                             Kanidm staging instance (auth-staging).
#                             Each operator's workstation requests a
#                             short-lived cert via the OIDC flow;
#                             OpenSSH on fleet hosts trusts the CA
#                             pubkey, not individual user pubkeys.
#                             This stays terminal-native — no GUI
#                             requirement at SSH time.
#   * Stage 3 (later)      — Kanidm group → host-class mapping, so
#                             "k8s-ops" gets login on k8s-* hosts
#                             only, "slurm-users" on slurm-* etc.
#                             Keeps service-scoped least privilege
#                             without a separate per-host key list.
#
# Until Stage 2 ships, treat `local.users.opSshKeys` as the
# fleet-shared "authorized to operate this host" boundary.

{ config, pkgs, lib, ... }:

let
  cfg = config.local.users;
in {
  options.local.users = {
    opSshKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Operator SSH public keys authorised on root and every
        declared normal user. The intent is "who is allowed to drive
        this host as a privileged operator"; reduce or expand at the
        host level rather than introducing per-user shards.
      '';
      example = [
        "ssh-ed25519 AAAA... operator@workstation"
      ];
    };

    rootExtraKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Additional keys authorised on root only. Use for break-glass
        keys or service-account access that should not log into
        normal user shells.
      '';
    };

    normalUsers = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule ({ name, ... }: {
        options = {
          description = lib.mkOption {
            type = lib.types.str;
            default = "Operator / interactive user";
          };
          extraGroups = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ "wheel" ];
            description = "Supplementary groups; default includes wheel.";
          };
          shell = lib.mkOption {
            type = lib.types.enum [ "zsh" "bash" ];
            default = "zsh";
            description = "Login shell — zsh is the fleet default.";
          };
          extraSshKeys = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = ''
              Keys authorised on this user ONLY, in addition to the
              fleet-wide `opSshKeys`.
            '';
          };
        };
      }));
      default = { };
      description = ''
        Normal interactive accounts to create. Each gets `opSshKeys`
        merged with its own `extraSshKeys`. Attribute key is the
        username; for the fleet default of a single account, the
        convention is `nixos` (most workloads) or `ops` (auth).
      '';
      example = lib.literalExpression ''
        {
          nixos = { extraGroups = [ "wheel" ]; };
        }
      '';
    };

    sudoNoPassword = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether wheel members can sudo without a password. SSH keys
        are the only auth boundary in this fleet — there is no
        password to challenge against — so the default is `true`.
      '';
    };
  };

  config = {
    users.mutableUsers = false;

    users.users = (lib.mapAttrs (name: user: {
      isNormalUser = true;
      description = user.description;
      extraGroups = user.extraGroups;
      shell = pkgs.${user.shell};
      openssh.authorizedKeys.keys = cfg.opSshKeys ++ user.extraSshKeys;
    }) cfg.normalUsers) // {
      root.openssh.authorizedKeys.keys = cfg.opSshKeys ++ cfg.rootExtraKeys;
    };

    security.sudo.wheelNeedsPassword = !cfg.sudoNoPassword;
  };
}
