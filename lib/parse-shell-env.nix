# Parse a bash-style env file into an attrset at nix-eval time.
# Used to flow a single source of truth (proxmox/*.env consumed by
# infra-proxmox/lib/create-qemu-vm.sh) into the NixOS evaluation of the
# matching host, so VMID/NAME/STATIC_IP/etc don't have to be duplicated
# between shell and nix.
#
# Caveats:
#   * Comments after `#` are stripped per-line; values containing `#` would
#     be misparsed (we don't have any).
#   * Only KEY=VALUE or KEY="VALUE" with `^[A-Z_][A-Z0-9_]*$` keys are
#     recognised. Multi-line values are not supported.
lib: path:
let
  lines = lib.splitString "\n" (builtins.readFile path);
  parseLine = line:
    let
      noComment = builtins.head (lib.splitString "#" line);
      m = builtins.match
        ''^[[:space:]]*([A-Z_][A-Z0-9_]*)="?([^"]*)"?[[:space:]]*$''
        noComment;
    in
      if m == null then null
      else lib.nameValuePair (builtins.elemAt m 0) (builtins.elemAt m 1);
  pairs = builtins.filter (x: x != null) (map parseLine lines);
in
  builtins.listToAttrs pairs
