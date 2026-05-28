# Fleet VMID / IP / hostname allocation

A recommended convention for sites that consume `nixos-infra-common`
to drive multiple `infra-<workload>` repos. The values below are
illustrative; replace the subnet, hypervisor hostname, and starting
VMIDs with whatever your environment requires.

## Network shape

For a single Proxmox host + LAN bridge on `<SUBNET>/24`:

```
<SUBNET>.1               gateway / router
<SUBNET>.2-.9            reserved (switches, future infra hardware)
<SUBNET>.10-.49          static infrastructure (hypervisor, DNS, monitoring, …)
<SUBNET>.50-.99          DHCP pool — set by the upstream router
<SUBNET>.100-.199        legacy / pre-fleet VMs (random VMID, random IP)
<SUBNET>.200-.249        fleet-managed static services   ← write new VMs here
<SUBNET>.250-.254        bootstrap / ephemeral (live ISO IPs during nixos-anywhere)
```

## VMID mnemonic

**The two trailing digits of VMID equal the last octet of the host's
static IP**, within the `.200-.249` fleet block. Anyone reading
`qm list` knows the IP at a glance, and vice versa.

```
VMID 200  <SUBNET>.200   <single-instance-infra-role>   e.g. nixos-builder
VMID 210  <SUBNET>.210   <workload-role>-00             e.g. agentcoder-00
VMID 211  <SUBNET>.211   <workload-role>-01             (future second instance)
VMID 220  <SUBNET>.220   <next-role>-00                 e.g. k8s-cp-00
...
```

For the `.100-.199` legacy block (where pre-fleet machines may live),
the rule applies to whatever VMIDs were historically chosen — no
attempt to retrofit.

## Sub-block convention inside `.200-.249`

Reserve a 10-address block per role family; the first VMID in the
block claims the block.

| Block | Role family (illustrative) |
|---|---|
| 200-209 | infrastructure singletons (nixos-builder, DNS, monitoring …) |
| 210-219 | dev workloads (agent VMs, jupyter, IDE servers …) |
| 220-229 | k8s nodes (control plane + workers) |
| 230-239 | slurm nodes (controller + compute) |
| 240-249 | build farm / HPC / misc |

Mixing workloads across blocks is allowed when capacity demands it —
document in the env file's `VM_DESCRIPTION`.

## Hostname convention

```
<role>            single-instance services    e.g. nixos-builder
<role>-<NN>       potentially multi-instance   e.g. agentcoder-00, k8s-w-03
```

`-NN` is **zero-indexed**: `<role>-00` is the first instance. Operators
reading `agentcoder-00` know there might one day be an `agentcoder-01`
without that being a contradiction.

Hostname == NixOS `networking.hostName` == Proxmox VM `--name` (set
via `infra-proxmox/lib/create-qemu-vm.sh`) == matching
`proxmox/<hostname>.env` filename. Diverging any of these is a smell.

## Storage

The `infra-proxmox` create-qemu-vm.sh recipe hands every VM three
disks. Hosts that don't need `/nix` or `/work` on separate disks
still declare positive integers for the env validator and ignore the
extra disks in their disko config.

| SCSI | by-id path | size knob | typical role |
|---|---|---|---|
| scsi0 | `scsi-0QEMU_QEMU_HARDDISK_drive-scsi0` | `SYSTEM_DISK_GB` | `/`, `/boot` |
| scsi1 | `scsi-0QEMU_QEMU_HARDDISK_drive-scsi1` | `NIX_DISK_GB`    | `/nix` (large agent VMs) or stub 1 GiB |
| scsi2 | `scsi-0QEMU_QEMU_HARDDISK_drive-scsi2` | `WORK_DISK_GB`   | `/var/lib/work` (large) or stub 1 GiB |

The udev by-id path is keyed on the QEMU **drive name**, not on the
`serial=` field set in the VM config. `disko` must point at
`drive-scsiN`, not at `<serial>` — the serial-keyed path simply does
not exist at install time.

## Adding a new host

1. Pick a free VMID in the right sub-block. On the hypervisor:
   `qm list | awk '$1 >= 200 && $1 <= 249 {print}'` shows what is taken.
2. Set IP last octet to match the VMID's trailing two digits.
3. Create `proxmox/<hostname>.env` in the relevant private repo with
   `VMID=…`, `NAME=…`, `STATIC_IP=…`, etc.
4. Create the matching `hosts/<hostname>/` (per-host dirs) or rely on
   `hosts/common/` (env-driven repos) — depending on which pattern the
   repo uses.
5. Deploy:
   - on the hypervisor:
     `CONFIRM=yes infra-proxmox/lib/create-qemu-vm.sh <env>`
   - from a workstation that can SSH the live ISO:
     `nix run github:nix-community/nixos-anywhere -- --flake .#<hostname> root@<dhcp-ip>`
   - on the hypervisor, post-install:
     `qm set <VMID> --boot order=scsi0 --delete ide2 && qm stop <VMID> && qm start <VMID>`

Document any deviation from these rules in the matching commit message.
