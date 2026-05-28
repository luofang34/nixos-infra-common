# nixos-infra-common

Public NixOS modules + lib helpers shared across the `infra-<workload>`
fleet. Consumed downstream as a
pinned flake input — there is one source of truth for each piece of
cross-cutting behaviour.

## Status

Experimental, built primarily for the author's own deployment.
Contributions and audit are welcome; no promises about stability, API
compatibility, or support.

## What's in here

| Module | Purpose |
|---|---|
| `nixosModules.base` | Nix flakes/GC defaults, UTC + en\_US locale, baseline CLI packages, hardened sshd |
| `nixosModules.shell` | Zsh + oh-my-zsh + `bira` theme — the visible signature that this module reached a host |
| `nixosModules.time` | chrony NTP, default-on, quick first-boot drift correction |
| `nixosModules.proxmoxGuest` | qemu-guest profile, systemd-boot UEFI, serial + tty1 console, fstrim |
| `nixosModules.network` | DHCP / static-IP flip driven by env-file (`STATIC_IP`, `GATEWAY`, `NAMESERVERS`) |
| `nixosModules.users` | Option-driven operator SSH keys + normal users + sudo NOPASSWD (`local.users.*`) |
| `nixosModules.autoUpdate` | Periodic flake-update + nixos-rebuild (`local.autoUpdate.*`, off by default) |
| `nixosModules.monitoring` | prometheus node-exporter scaffolding (off by default) |
| `nixosModules.default` | `base` + `shell` + `time` bundled — every fleet host should at least get this |
| `lib.parseShellEnv` | Bash env-file → nix attrset, eval-time |

## Docs

* [`docs/allocation.md`](docs/allocation.md) — recommended VMID / IP / hostname / storage allocation convention for fleets that consume this flake.

## Consuming this flake

```nix
inputs.infra-common = {
  url = "github:luofang34/nixos-infra-common";
  inputs.nixpkgs.follows = "nixpkgs";
};

# in your host's default.nix:
imports = [
  inputs.infra-common.nixosModules.default
  # …or pick specific modules:
  # inputs.infra-common.nixosModules.base
  # inputs.infra-common.nixosModules.shell
  # inputs.infra-common.nixosModules.proxmoxGuest
  # inputs.infra-common.nixosModules.network
];
```

`network` expects `env` in specialArgs (the parsed proxmox/*.env). The
consumer flake parses that file via `inputs.infra-common.lib.parseShellEnv`
and forwards the attrset to the host.

## Verification fingerprint

Bira renders prompts like:

```
╭─user@host time directory
╰─$
```

If you SSH into a host that imports `nixosModules.default` and don't see
that two-line prompt, the common module didn't actually land — start
debugging there.

## License

[AGPL-3.0-or-later](./LICENSE).
