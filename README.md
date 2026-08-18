# webOwie_nodeOS

**Alpine-native node operating environment for Proxmox, powered by ArozOS.**

`webOwie_nodeOS` is the webOwie deployment, branding and packaging layer around the ArozOS core. The project targets Alpine Linux 3.24, OpenRC and Proxmox environments.

ArozOS remains the upstream engine. `webOwie_nodeOS` remains our product and deployment layer.

## Live ISO

The repository now contains a dedicated **single bootable Alpine Linux 3.24 x86_64 live ISO** profile.

It is deliberately not a multiboot ISO.

The live environment uses Alpine's standard/LTS kernel profile and complete modloop, includes `net-tools`, `iproute2`, `iputils`, `ethtool` and `pciutils`, and prepares common Proxmox/QEMU virtual NIC drivers before OpenRC networking starts.

Network interfaces are discovered dynamically from `/sys/class/net`; the image does not depend on a hard-coded `eth0` name.

Build files:

```text
iso/mkimg.webowie_nodeos.sh
iso/genapkovl-webowie-nodeos.sh
.github/workflows/build-live-iso.yml
```

Expected CI artifact:

```text
webOwie_nodeOS-live-x86_64.iso
webOwie_nodeOS-live-x86_64.iso.sha256
qemu-live.log
```

The workflow boots the generated ISO in QEMU with a VirtIO NIC and rejects the build unless a non-loopback NIC is detected.

Full documentation:

```text
docs/LIVE-ISO.md
```

## Live ISO installation

Recommended Proxmox NIC:

```text
Model:  VirtIO (paravirtualized)
Bridge: vmbr0
```

After booting the ISO, verify networking with:

```sh
ip addr
ifconfig
ip route
netstat -rn
```

Install Alpine to the VM disk with:

```sh
setup-alpine
```

After installation, reboot from the virtual disk rather than the ISO.

## Runtime architecture

```text
ArozOS upstream
      |
      | controlled webOwie build / compatibility checks
      v
webOwie_nodeOS runtime
      |
      +-- webOwie branding
      +-- Alpine Linux 3.24
      +-- OpenRC
      +-- Proxmox VM / LXC
      +-- webOwie packaging and update layer
```

The target production design uses prebuilt runtime artifacts. Production nodes should not require the Go compiler or `make` merely to start webOwie_nodeOS.

## Current source installer

The existing source installer is retained while the production APK/release packaging is completed:

```sh
curl -fsSL \
  https://raw.githubusercontent.com/puchadave/arozos-alpine/main/installer/install-webowie-nodeos.sh \
  -o /root/install-webowie-nodeos.sh
chmod +x /root/install-webowie-nodeos.sh
/root/install-webowie-nodeos.sh
```

Runtime location:

```text
/opt/webOwie_nodeOS
```

Service management:

```sh
rc-service webowie-nodeos status
rc-service webowie-nodeos restart
rc-service webowie-nodeos stop
```

The production package design will replace target-side compilation with a prebuilt Alpine `.apk` containing only the runtime, branding, OpenRC service and required production files.

## Branding layer

Brand identity:

```text
Product: webOwie_nodeOS
Vendor:  webOwie
Base:    ArozOS
Host OS: Alpine Linux
Init:    OpenRC
```

The branding script lives at:

```text
branding/apply-branding.sh
```

Visible webOwie product branding is separated from internal ArozOS technical identifiers where retaining upstream compatibility is important.

## LXC-safe defaults

For unprivileged LXC environments the service disables host-management functions that should not operate against the Proxmox host:

```text
-allow_pkg_install=false
-enable_hwman=false
-enable_pwman=false
-enable_docker=false
-allow_upnp=false
-arozcast_turn=false
```

## Storage on Proxmox LXC

Prefer host-managed storage exposed through a bind mount:

```sh
pct set 123 -mp0 /srv/storage,mp=/srv/storage
pct restart 123
```

Then add `/srv/storage` as a local storage pool inside webOwie_nodeOS.

## Validation

Static ISO checks:

```sh
sh tests/iso-profile-smoke.sh
```

The GitHub workflow additionally performs an actual QEMU boot test of the generated ISO.

## Upstream and licensing

ArozOS is developed by **tobychui / IMUSLAB** and licensed under GNU GPL-3.0.

- Upstream project: https://github.com/tobychui/arozos
- webOwie_nodeOS deployment layer: https://github.com/puchadave/arozos-alpine

The rebranding does not remove upstream attribution or licensing notices.
