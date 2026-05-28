# Fleet-wide observability primitive. Off by default; turn on at the
# host level after a Prometheus collector exists somewhere in the LAN
# that can scrape it. `openFirewall` is opt-in so a freshly enabled
# exporter doesn't accidentally surface on a bridge.
{ lib, ... }: {
  services.prometheus.exporters.node = {
    enable = lib.mkDefault false;
    port = lib.mkDefault 9100;
    enabledCollectors = lib.mkDefault [
      "systemd"
      "processes"
    ];
    openFirewall = lib.mkDefault false;
  };
}
