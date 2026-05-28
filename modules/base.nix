# Baseline NixOS settings shared by every host in the fleet.
#
# - Enables nix flakes + nix-command (everything downstream assumes flakes).
# - Conservative weekly GC with a 30-day retention floor so disk usage on
#   long-lived VMs doesn't drift unbounded.
# - UTC + en_US.UTF-8 by default; hosts in odd timezones override at
#   site-level.
# - A small set of "every login needs this" CLI packages. Workload-specific
#   tooling (claude-code, codex, k8s clients, ...) is added by the consuming
#   repo, not here.
{ pkgs, lib, ... }: {
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = lib.mkDefault [ "root" ];
    auto-optimise-store = true;
  };

  nix.gc = {
    automatic = lib.mkDefault true;
    dates = lib.mkDefault "weekly";
    options = lib.mkDefault "--delete-older-than 30d";
  };

  nixpkgs.config.allowUnfree = lib.mkDefault true;

  time.timeZone = lib.mkDefault "UTC";
  i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";

  environment.systemPackages = with pkgs; [
    git
    tmux
    vim
    curl
    jq
    ripgrep
    fd
    htop
    btop
    file
    rsync
    openssh
  ];

  # OpenSSH hardened for key-only auth. Hosts can still flip individual
  # settings; the defaults are the lowest common denominator that's safe to
  # expose to a LAN.
  services.openssh = {
    enable = lib.mkDefault true;
    settings = {
      PasswordAuthentication = lib.mkDefault false;
      KbdInteractiveAuthentication = lib.mkDefault false;
      PermitRootLogin = lib.mkDefault "prohibit-password";
    };
  };
}
