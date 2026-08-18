# webOwie_nodeOS

**Alpine-native node operating environment for Proxmox LXC, powered by ArozOS.**

`webOwie_nodeOS` is packaged as a production Alpine APK. The GitHub build pipeline fetches the current ArozOS upstream source, compiles it for Alpine, applies the webOwie branding layer, builds a clean runtime-only `.apk`, installs that APK into a fresh Alpine 3.24 container, starts the OpenRC service, and performs an HTTP smoke test before publishing the release.

## Production install

Run as `root` inside Alpine Linux 3.24 x86_64:

```sh
curl -fsSL \
  https://raw.githubusercontent.com/puchadave/arozos-alpine/main/installer/install-webowie-nodeos.sh \
  | sh
```

The installer downloads the verified production APK from the `apk-latest` GitHub Release, installs it with `apk`, enables OpenRC and starts `webOwie_nodeOS`.

Direct APK asset:

```text
https://github.com/puchadave/arozos-alpine/releases/download/apk-latest/webowie-nodeos-x86_64.apk
```

After installation:

```text
http://SERVER-IP:8080/
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

## Production APK contents

The generated APK contains only files required on the Alpine node:

```text
/opt/webOwie_nodeOS/
├── webowie-nodeos
├── web/
├── system/
├── vendor-res/
├── files/
└── tmp/

/etc/init.d/webowie-nodeos
/etc/conf.d/webowie-nodeos
```

`go`, `make`, source trees and CI files are build-time only and are not installed by the APK.

Runtime package dependencies intentionally include administrative and diagnostic tools such as `git`, `wget`, `shadow`, `net-tools` and `findutils`.

## APK build pipeline

The production package is built by:

```text
.github/workflows/build-apk.yml
scripts/build-apk.sh
packaging/APKBUILD
```

Pipeline:

```text
ArozOS upstream
      ↓
Alpine 3.24 build container
      ↓
webOwie branding
      ↓
runtime-only APK
      ↓
fresh Alpine install test
      ↓
OpenRC start
      ↓
HTTP :8080 smoke test
      ↓
GitHub Release: apk-latest
```

The release asset is always named:

```text
webowie-nodeos-x86_64.apk
```

## Live ISO

A separate single Alpine 3.24 live ISO build exists for installation/recovery testing. It is not a multiboot image. The live profile includes `net-tools`, `iproute2`, virtual NIC support and dynamic DHCP setup for Proxmox/QEMU.

See:

```text
docs/LIVE-ISO.md
```

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

ArozOS remains the upstream engine and attribution/licensing notices are preserved.

## LXC-safe defaults

The OpenRC service uses conservative LXC-safe options:

```text
-allow_pkg_install=false
-enable_hwman=false
-enable_pwman=false
-enable_docker=false
-allow_upnp=false
-arozcast_turn=false
```

## Upstream and licensing

ArozOS is developed by **tobychui / IMUSLAB** and licensed under GNU GPL-3.0.

- Upstream project: https://github.com/tobychui/arozos
- webOwie_nodeOS deployment layer: https://github.com/puchadave/arozos-alpine

The rebranding does not remove upstream attribution or licensing notices.
