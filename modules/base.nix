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

    # Fleet binary cache on the nixos-builder VM. extra-* appends to
    # the built-in defaults; the LAN cache advertises a higher priority
    # than cache.nixos.org so it is tried first, and an unreachable
    # builder degrades to a warning with the public cache serving the
    # request. A host overriding either list at normal priority
    # replaces the fleet default — include these values if the intent
    # is to add a cache rather than swap it.
    extra-substituters = lib.mkDefault [ "http://192.168.89.200:5000" ];
    extra-trusted-public-keys = lib.mkDefault [
      "nixos-builder.v99n62.ai-1:LRkbBX+segsiMfNFw45EOk4nGHIDjk3eVlsGbt8Gx44="
    ];

    # Nix's default connect-timeout is unlimited; a blackholed
    # substituter would stall operations for minutes instead of
    # skipping.
    connect-timeout = lib.mkDefault 5;
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
