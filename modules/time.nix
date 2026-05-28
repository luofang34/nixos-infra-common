# Accurate wall clock is a prerequisite for TLS, log correlation,
# Kerberos / OIDC, and most signed-protocol auth flows. chrony is the
# fleet default; pool.ntp.org's anycast pool is correct for almost any
# Internet-connected host. Sites with restricted egress can override
# `services.chrony.servers` at the host level.
{ lib, ... }: {
  services.chrony = {
    enable = lib.mkDefault true;
    extraConfig = lib.mkDefault ''
      # Drift correction quickly on first boot — useful for VMs whose
      # clock can drift hard during snapshot/restore.
      makestep 1.0 3
    '';
  };
}
