# Guest-side IP-over-InfiniBand for a host that has been given an
# InfiniBand interface (e.g. an SR-IOV VF passed through by the
# hypervisor). Mechanism only — the fabric address is a site fact the
# consumer sets via local.ipoib.address.
#
# Two fabric invariants are enforced because getting either wrong makes
# the link appear up while traffic silently blackholes:
#   * IPoIB mode (connected) is written to sysfs on device appearance,
#     before networkd raises the link — the mode can only change while the
#     interface is down, and the large MTU is only valid in connected mode.
#   * The MTU must match the fabric exactly.
#
# No gateway/DNS is configured on the IB side: the InfiniBand subnet is
# link-local to the fabric, so the host's default route stays on its
# Ethernet (LAN) interface.
{ config, lib, ... }:

let
  cfg = config.local.ipoib;
in
{
  options.local.ipoib = {
    enable = lib.mkEnableOption "IP-over-InfiniBand on a passed-through IB interface";

    address = lib.mkOption {
      type = lib.types.str;
      example = "192.168.77.50/24";
      description = ''
        Static fabric address (CIDR) for the IB interface. No gateway is
        configured; the default route stays on the Ethernet interface.
      '';
    };

    interface = lib.mkOption {
      type = lib.types.str;
      default = "ib*";
      description = "systemd-networkd Name= match for the IB interface.";
    };

    mtu = lib.mkOption {
      type = lib.types.int;
      default = 65520;
      description = ''
        IPoIB MTU; must match the fabric. 65520 is the connected-mode max.
      '';
    };

    mode = lib.mkOption {
      type = lib.types.enum [
        "connected"
        "datagram"
      ];
      default = "connected";
      description = "IPoIB mode; must match the fabric.";
    };
  };

  config = lib.mkIf cfg.enable {
    networking.useNetworkd = true;

    # The IPoIB ULP that creates the ibN netdev. mlx4_ib/ib_core load on
    # device appearance, but ib_ipoib does not auto-load — without it there
    # is no ib* interface for the udev/networkd rules below to match, and
    # the fabric link silently never comes up.
    boot.kernelModules = [ "ib_ipoib" ];

    # Write the IPoIB mode before networkd configures the link. udev fires
    # on device appearance (link still down), which is the only time the
    # mode is changeable.
    services.udev.extraRules = ''
      SUBSYSTEM=="net", ACTION=="add", KERNEL=="ib*", ATTR{mode}="${cfg.mode}"
    '';

    systemd.network.networks."40-ipoib" = {
      matchConfig.Name = cfg.interface;
      address = [ cfg.address ];
      linkConfig.MTUBytes = toString cfg.mtu;
      # Fabric-only: no gateway, no DNS, no autoconf. Default route and
      # resolvers come from the Ethernet interface.
      networkConfig = {
        LinkLocalAddressing = "no";
        IPv6AcceptRA = false;
        DHCP = "no";
      };
    };
  };
}
