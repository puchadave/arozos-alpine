# webOwie_nodeOS

**Alpine-native node operating environment for Proxmox LXC, powered by ArozOS.**

`webOwie_nodeOS` is installed exclusively from this repository. During installation the current ArozOS upstream source is fetched, compiled natively for Alpine Linux, and then transformed by the webOwie branding and deployment layer.

## Architecture

```text
puchadave/arozos-alpine
        |
        | webOwie installer + branding + Alpine integration
        v
ArozOS upstream source
        |
        | native Go build
        v
webOwie_nodeOS runtime
        |
        +-- Alpine Linux
        +-- OpenRC
        +-- Proxmox LXC
        +-- webOwie branding/vendor layer
```

ArozOS remains the upstream engine. `webOwie_nodeOS` remains our product and deployment layer.

## Quick install

Run as `root` inside a fresh Alpine Linux 3.24+ LXC:

```sh
curl -fsSL \
  https://raw.githubusercontent.com/puchadave/arozos-alpine/main/installer/install-webowie-nodeos.sh \
  -o /root/install-webowie-nodeos.sh

chmod +x /root/install-webowie-nodeos.sh
/root/install-webowie-nodeos.sh
```

After installation:

```text
http://LXC-IP:8080/
```

Service management:

```sh
rc-service webowie-nodeos status
rc-service webowie-nodeos restart
rc-service webowie-nodeos stop
```

Runtime location:

```text
/opt/webOwie_nodeOS
```

## Upstream updates

Installed nodes can rebuild from the current ArozOS upstream while preserving mutable node state and reapplying the webOwie branding layer:

```sh
curl -fsSL \
  https://raw.githubusercontent.com/puchadave/arozos-alpine/main/scripts/update-webowie-nodeos.sh \
  -o /root/update-webowie-nodeos.sh

chmod +x /root/update-webowie-nodeos.sh
/root/update-webowie-nodeos.sh
```

The installed upstream commit is recorded in:

```text
/opt/webOwie_nodeOS/vendor-res/upstream.json
```

## Branding layer

The project uses the vendor-extension hooks already present in ArozOS where possible and applies narrowly scoped runtime branding where required.

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

## LXC-safe defaults

The service disables host-management functions that are inappropriate inside an unprivileged Proxmox LXC:

```text
-allow_pkg_install=false
-enable_hwman=false
-enable_pwman=false
-enable_docker=false
-allow_upnp=false
-arozcast_turn=false
```

## Optional installer variables

```sh
PORT=8088 \
NODE_HOSTNAME=webOwie-storage-01 \
/root/install-webowie-nodeos.sh
```

Important variables:

| Variable | Default |
|---|---|
| `UPSTREAM_REPO` | `https://github.com/tobychui/arozos.git` |
| `UPSTREAM_REF` | `master` |
| `INSTALL` | `/opt/webOwie_nodeOS` |
| `PORT` | `8080` |
| `NODE_HOSTNAME` | `webOwie-nodeOS` |
| `SERVICE_NAME` | `webowie-nodeos` |
| `SERVICE_USER` | `webowie` |

## Storage on Proxmox

Prefer host-managed storage exposed to the LXC through a bind mount:

```sh
pct set 123 -mp0 /srv/storage,mp=/srv/storage
pct restart 123
```

Then add `/srv/storage` as a local storage pool in the webOwie_nodeOS interface.

## Upstream and licensing

ArozOS is developed by **tobychui / IMUSLAB** and licensed under GNU GPL-3.0.

- Upstream project: https://github.com/tobychui/arozos
- webOwie_nodeOS deployment layer: https://github.com/puchadave/arozos-alpine

The rebranding does not remove upstream attribution or licensing notices.
