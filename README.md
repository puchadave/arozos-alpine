# ArozOS Alpine

Native **ArozOS deployment for Alpine Linux and Proxmox LXC**.

This repository provides an Alpine/OpenRC installation path for [tobychui/arozos](https://github.com/tobychui/arozos) without Docker, systemd, or Debian-specific host assumptions.

## Target

- Alpine Linux 3.24+
- Proxmox VE LXC
- OpenRC
- native Go build
- unprivileged LXC recommended
- no Docker required

## Quick install

Run as `root` inside a fresh Alpine LXC:

```sh
wget -O /root/install-arozos-alpine.sh \
  https://raw.githubusercontent.com/puchadave/arozos-alpine/main/installer/install-alpine-lxc.sh
chmod +x /root/install-arozos-alpine.sh
/root/install-arozos-alpine.sh
```

After installation, open:

```text
http://LXC-IP:8080/
```

## Optional configuration

```sh
PORT=8088 AROZ_HOSTNAME=storage /root/install-arozos-alpine.sh
```

The installer accepts these environment overrides:

| Variable | Default | Purpose |
|---|---|---|
| `REPO` | `https://github.com/tobychui/arozos.git` | ArozOS source repository |
| `REF` | `master` | ArozOS branch/tag/ref |
| `SRC` | `/usr/local/src/arozos` | build source directory |
| `INSTALL` | `/opt/arozos` | runtime directory |
| `PORT` | `8080` | HTTP port |
| `AROZ_HOSTNAME` | `arozos` | ArozOS hostname |
| `SERVICE_USER` | `arozos` | OpenRC service user |
| `SERVICE_GROUP` | `arozos` | OpenRC service group |

## LXC-safe defaults

ArozOS contains Debian-oriented package and host-management functions. The Alpine service therefore disables them by default:

```text
-allow_pkg_install=false
-enable_hwman=false
-enable_pwman=false
-enable_docker=false
-allow_upnp=false
-arozcast_turn=false
```

The installer also reduces the default ArozOS buffer pool for a lightweight LXC deployment.

## Service management

```sh
rc-service arozos status
rc-service arozos restart
rc-service arozos stop
```

## Storage on Proxmox

Prefer mounting storage on the Proxmox host and exposing it to the LXC as a bind mount:

```sh
pct set 123 -mp0 /srv/storage,mp=/srv/storage
pct restart 123
```

Then configure `/srv/storage` as a local Storage Pool inside ArozOS.

## Documentation

See [`docs/ALPINE-LXC.md`](docs/ALPINE-LXC.md).

## Upstream

ArozOS is developed by **tobychui / IMUSLAB**:

- Upstream: https://github.com/tobychui/arozos
- Upstream license: GPL-3.0

This repository adds an Alpine Linux/OpenRC deployment layer and does not replace the upstream project.
