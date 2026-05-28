# Site-local network configuration driven by the proxmox env file that
# infra-proxmox consumes — same fields, same semantics, parsed once at
# nix-eval-time in the consumer flake and passed in via specialArgs.env.
#
# When STATIC_IP is empty (or the env attribute is absent), the host
# falls back to DHCP. When set (e.g. "10.0.0.10/24") with a matching
# GATEWAY, it switches the host onto systemd-networkd with a static lease
# that matches any `en*` interface — robust to udev rename quirks across
# kernel versions.
{ config, lib, env ? { }, ... }:

let
  staticIp = env.STATIC_IP or "";
  gateway = env.GATEWAY or "";
  nameservers = lib.splitString " " (env.NAMESERVERS or "1.1.1.1 8.8.8.8");

  hasStatic = staticIp != "" && gateway != "";
in {
  networking = {
    firewall.allowedTCPPorts = lib.mkDefault [ 22 ];
    nameservers = lib.mkIf hasStatic nameservers;
  } // (
    if hasStatic then {
      useDHCP = lib.mkForce false;
      useNetworkd = true;
    } else {
      useDHCP = lib.mkDefault true;
    }
  );

  systemd.network.networks = lib.mkIf hasStatic {
    "10-lan" = {
      matchConfig.Name = "en*";
      address = [ staticIp ];
      routes = [ { Gateway = gateway; } ];
    };
  };
}
