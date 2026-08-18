# ArozOS on Alpine Linux LXC

This repository adds a native Alpine Linux installation path for ArozOS without Docker or systemd.

## Recommended environment

- Proxmox VE LXC
- Alpine Linux 3.24 or newer
- unprivileged container
- 2 vCPU
- 2 GB RAM
- 512 MB swap
- 8-16 GB root disk
- TCP 8080

## Install

Run as root inside the Alpine LXC:

```sh
wget -O /root/install-arozos-alpine.sh \
  https://raw.githubusercontent.com/puchadave/arozos-alpine/main/installer/install-alpine-lxc.sh
chmod +x /root/install-arozos-alpine.sh
/root/install-arozos-alpine.sh
```

Optional overrides:

```sh
PORT=8088 AROZ_HOSTNAME=storage /root/install-arozos-alpine.sh
```

To build another ArozOS branch or tag:

```sh
REF=master /root/install-arozos-alpine.sh
```

To build from another compatible source repository:

```sh
REPO=https://github.com/example/arozos.git REF=main /root/install-arozos-alpine.sh
```

## What the installer does

1. Installs the required Alpine packages with `apk`.
2. Checks for Go 1.25 or newer.
3. Creates a dedicated `arozos` service account.
4. Clones the selected ArozOS source tree.
5. Builds a native static Go binary with `CGO_ENABLED=0`.
6. Builds the upstream `web/system` runtime bundle.
7. Installs ArozOS under `/opt/arozos`.
8. Creates an OpenRC service.
9. Enables and starts ArozOS.

## Service management

```sh
rc-service arozos status
rc-service arozos restart
rc-service arozos stop
```

Enable at boot manually if needed:

```sh
rc-update add arozos default
```

## Runtime paths

```text
/opt/arozos/            ArozOS runtime
/opt/arozos/arozos      native binary
/opt/arozos/system/     system data/config
/opt/arozos/web/        web UI
/opt/arozos/files/      default user storage
/opt/arozos/tmp/        ArozOS temporary storage
/etc/conf.d/arozos      OpenRC arguments
/etc/init.d/arozos      OpenRC service
/usr/local/src/arozos   source/build tree
```

## Alpine compatibility choices

ArozOS contains Debian/Ubuntu-specific package-management integration. The Alpine service therefore starts ArozOS with:

```text
-allow_pkg_install=false
```

Host-level hardware, power and Docker management are disabled by default inside LXC:

```text
-enable_hwman=false
-enable_pwman=false
-enable_docker=false
-allow_upnp=false
-arozcast_turn=false
```

The default deployment also uses:

```text
-max_upload_size=1024
-buffpool_size=256
-upload_buf=25
```

These values are more appropriate for a small LXC than the comparatively large upstream defaults.

## Proxmox storage

Storage should preferably be mounted by Proxmox and exposed to the LXC via bind mounts instead of letting ArozOS manipulate host block devices.

Example on the Proxmox host:

```sh
pct set 123 -mp0 /srv/storage,mp=/srv/storage
pct restart 123
```

Inside the container:

```sh
ls -lah /srv/storage
```

Then add `/srv/storage` as a local Storage Pool in ArozOS.

### Unprivileged LXC note

For unprivileged containers, host-side ownership of bind-mounted directories must match the container's UID/GID mapping. Check the service UID inside the container with:

```sh
id arozos
```

Apply the corresponding mapped ownership on the Proxmox host before allowing ArozOS write access.

## Reverse proxy

ArozOS listens on port `8080` by default. For external access, terminate TLS at a reverse proxy such as Zoraxy, Caddy, Traefik or nginx and proxy to the LXC address.

If the instance is exclusively behind a reverse proxy, consider adding this flag to `/etc/conf.d/arozos`:

```text
-disable_ip_resolver=true
```

Restart after changing flags:

```sh
rc-service arozos restart
```

## Upgrading

Re-running the installer currently performs a fresh application deployment under `/opt/arozos`. Before doing so, back up persistent ArozOS configuration and user data.

At minimum, preserve data that matters from:

```text
/opt/arozos/system/
/opt/arozos/files/
```

For production use, persistent data should ideally live on separate Proxmox-backed storage rather than solely inside the LXC root filesystem.

## Upstream

Original project:

https://github.com/tobychui/arozos

This deployment repository keeps the upstream application source separate and adds Alpine/OpenRC support around it.
