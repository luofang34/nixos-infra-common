# Hardware-side defaults for any Proxmox QEMU guest produced by the
# infra-proxmox/lib/create-qemu-vm.sh recipe (q35 + OVMF UEFI +
# VirtIO SCSI single, three disks with discard=on, serial0 socket).
#
# Bootloader = systemd-boot on EFI. Kernel params mirror Linux output to
# both ttyS0 (the Proxmox `qm terminal` channel) and tty1 (noVNC), so the
# boot log is visible from either side. `services.fstrim` keeps qcow2
# back-storage trimmed without operator action.
{ modulesPath, lib, ... }: {
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  boot = {
    loader = {
      systemd-boot.enable = lib.mkDefault true;
      efi.canTouchEfiVariables = lib.mkDefault true;
    };
    initrd.availableKernelModules = [
      "ahci" "xhci_pci" "virtio_pci" "virtio_scsi" "sd_mod" "sr_mod"
    ];
    kernelParams = lib.mkDefault [ "console=ttyS0,115200n8" "console=tty1" ];
  };

  systemd.services."serial-getty@ttyS0".enable = lib.mkDefault true;

  services.qemuGuest.enable = lib.mkDefault true;
  services.fstrim.enable = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
