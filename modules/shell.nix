# Fleet-wide shell defaults. `bira` is deliberately distinctive: any time
# a freshly SSH'd-in operator sees the two-line prompt
#
#     ╭─user@host time directory
#     ╰─$
#
# they know the common module landed on this host. Lose the bira prompt =
# something is wrong with the module wiring.
#
# Side-effect intended: `programs.zsh.ohMyZsh.enable = true` writes a
# complete `/etc/zshrc` (compinit, theme, plugin loading), which makes the
# `zsh-newuser-install` walkthrough never trigger for new accounts. The
# stock `programs.zsh.enable = true` alone does not — that was the symptom
# that motivated this module.
{ pkgs, lib, ... }: {
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    syntaxHighlighting.enable = true;
    autosuggestions.enable = true;
    histSize = 10000;
    ohMyZsh = {
      enable = true;
      theme = lib.mkDefault "bira";
      plugins = lib.mkDefault [ "git" "sudo" "history" "command-not-found" ];
    };
  };

  environment.systemPackages = [ pkgs.zsh ];

  # zsh 5.x triggers the `zsh-newuser-install` walkthrough on first
  # interactive login whenever NONE of ~/.zshrc, ~/.zshenv, ~/.zprofile,
  # ~/.zlogin exist in the user's home. NixOS provides /etc/zshrc but
  # that lives outside $HOME, so zsh still considers the user "fresh".
  # We touch an empty ~/.zshrc on every system activation for each
  # normal user that doesn't already have one; this is the minimum the
  # walkthrough's own conditional checks for, and oh-my-zsh's
  # /etc/zshrc continues to drive the actual interactive setup.
  system.activationScripts.zsh-suppress-newuser-install = ''
    while IFS=: read -r username _ uid _ _ home shell; do
      # Filter to humans whose interactive shell is zsh. System users
      # parked on /var/empty (read-only) or running other shells don't
      # see the walkthrough, so leave them alone.
      [ "$uid" -lt 1000 ] && continue
      [ "$uid" -eq 65534 ] && continue
      [ "$home" = "/var/empty" ] && continue
      [ -d "$home" ] || continue
      case "$shell" in *zsh*) ;; *) continue ;; esac

      if [ ! -e "$home/.zshrc" ]; then
        # Best effort. A single user's home being read-only or owned
        # by something unexpected must not break the whole activation
        # — we only want to suppress a UX wart, not gate boot.
        touch "$home/.zshrc" 2>/dev/null \
          && chown "$username:" "$home/.zshrc" 2>/dev/null \
          && chmod 0644 "$home/.zshrc" 2>/dev/null \
          || true
      fi
    done < /etc/passwd
  '';
}

