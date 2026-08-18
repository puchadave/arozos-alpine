# webOwie_nodeOS Live ISO

The project builds one bootable Alpine Linux 3.24 x86_64 live ISO for installation and recovery.

It is deliberately **not** a multiboot image.

## Image characteristics

- Alpine Linux 3.24
- x86_64 only
- Alpine standard profile with LTS kernel
- complete modloop / virtual-device driver support
- serial and VGA console output
- `net-tools` included in the live system
- `iproute2`, `iputils`, `ethtool` and `pciutils` included
- dynamic Proxmox/QEMU network-interface discovery
- DHCP configuration generated for every detected non-loopback NIC
- common virtual NIC drivers preloaded: `virtio_net`, `e1000`, `e1000e`, `vmxnet3`
- normal Alpine installer available through `setup-alpine`

## GitHub Actions build

The workflow is:

```text
.github/workflows/build-live-iso.yml
```

The ISO profile and overlay are:

```text
iso/mkimg.webowie_nodeos.sh
iso/genapkovl-webowie-nodeos.sh
```

The build uses Alpine's `aports` `3.24-stable` branch and the official `scripts/mkimage.sh` image builder.

The expected artifact is:

```text
webOwie_nodeOS-live-x86_64.iso
webOwie_nodeOS-live-x86_64.iso.sha256
qemu-live.log
```

Before publishing the artifact, CI boots the ISO with QEMU and a VirtIO network device and requires the boot log to contain:

```text
Detected NIC:
```

This prevents an ISO that boots with only `lo` from being treated as a successful build.

## Recommended Proxmox VM settings

```text
Machine:   q35 or default Proxmox machine
CPU:       host or x86-64-v2-AES
Memory:    1024 MiB or more
CD/DVD:    webOwie_nodeOS-live-x86_64.iso
NIC model: VirtIO (paravirtualized)
Bridge:    vmbr0
Boot:      CD/DVD first for installation
```

The ISO also preloads E1000/E1000E and VMXNET3 as fallbacks.

## Network verification

After booting the live ISO:

```sh
ip addr
ifconfig
ip route
netstat -rn
```

At least one interface in addition to `lo` must be present.

For a VirtIO NIC the interface will commonly be named `eth0`, but the live environment does not depend on that name.

## Install Alpine to disk

From the live console:

```sh
setup-alpine
```

Choose the detected network interface and DHCP unless a static address is required.

After installation, reboot from the virtual disk rather than the ISO.

## Source-level validation

The invariant test is:

```sh
sh tests/iso-profile-smoke.sh
```

It verifies that the image remains a single x86_64 Alpine live image, includes the network tooling, wires the custom `apkovl` correctly and retains the virtual-NIC preparation logic.
