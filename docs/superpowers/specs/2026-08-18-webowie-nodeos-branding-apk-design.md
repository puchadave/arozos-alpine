# webOwie_nodeOS Branding + Alpine APK Design

Date: 2026-08-18
Status: Proposed for implementation

## Goal

Turn the current Alpine deployment layer into a reproducible, installable `webOwie_nodeOS` product package for Alpine Linux / Proxmox LXC.

The resulting node must be installed from a prebuilt `.apk` artifact. Target nodes must not compile ArozOS and therefore do not require Go or Make.

## Product identity

Visible product branding:

- Product: `webOwie_nodeOS`
- Vendor: `webOwie`
- Maintainer: David Puchalla / webOwie
- Target platform: Alpine Linux 3.24+
- Primary environment: Proxmox LXC
- Core engine attribution: ArozOS by tobychui / IMUSLAB
- ArozOS license attribution remains visible and intact

Internal ArozOS identifiers, Go module paths, APIs, database keys, module IDs and compatibility-sensitive names are not mass-renamed. Only visible product identity and explicitly controlled vendor/update metadata are rebranded.

## Branding source of truth

The uploaded branding pack becomes the canonical asset source under `branding/master/`.

Expected files:

```text
branding/master/
├── web/
│   ├── favicon.ico
│   ├── apple-touch-icon.png
│   ├── icon-192.png
│   └── icon-512.png
└── svg/
    ├── webOwie_nodeOS_horizontal.svg
    ├── webOwie_nodeOS_primary.svg
    ├── webOwie_nodeOS_avatar.svg
    └── webOwie_nodeOS_icon.svg
```

Asset mapping:

- `horizontal.svg`: About/System header and large banner usage
- `primary.svg`: login/product identity
- `avatar.svg`: square avatar/project identity
- `icon.svg`: system/launcher/app identity
- `favicon.ico`: browser favicon
- `apple-touch-icon.png`: Apple home-screen icon
- `icon-192.png`: PWA 192 icon
- `icon-512.png`: PWA 512 icon

Generated PNG/JPG derivatives may be created during CI, but the SVG and supplied PNG/ICO files remain the source of truth.

## Visible rebranding scope

The branding pipeline changes visible strings and assets in the staged ArozOS runtime.

Required visible changes include:

- Login title: `webOwie_nodeOS - Login`
- Desktop title: `webOwie_nodeOS Desktop`
- Mobile/PWA name: `webOwie_nodeOS`
- Product heading in System Info/About: `webOwie_nodeOS`
- Subtitle: `Modular Node Operating Environment`
- Vendor metadata: `webOwie`
- Vendor model: `webOwie_nodeOS`
- Favicon/PWA icons/login logo/system icon replaced with webOwie assets

The current ArozOS attribution section is retained as an upstream/core attribution section.

## About/System Info page

The existing About page is reworked without deleting upstream attribution.

Top section:

```text
webOwie_nodeOS
Modular Node Operating Environment
System Version: ...
System UUID: ...
```

A new webOwie information box is added:

```text
webOwie
Product:       webOwie_nodeOS
Platform:      Alpine Linux
Environment:   Proxmox LXC
Distribution:  webOwie
Core Engine:   ArozOS
Maintainer:    David Puchalla / webOwie
Project:       GitHub repository URL
```

A separate attribution block remains visible:

```text
Powered by ArozOS
Original project by tobychui / IMUSLAB
GPLv3
```

## Build architecture

ArozOS upstream stays the source engine. GitHub Actions builds the distributable runtime and applies webOwie branding after upstream files are staged.

```text
ArozOS upstream
    ↓
GitHub Actions
    ↓
compile ArozOS for target architecture
    ↓
build/extract web + system runtime
    ↓
apply webOwie_nodeOS branding/assets
    ↓
install OpenRC files + package metadata
    ↓
abuild
    ↓
webowie-nodeos-<version>-r<revision>.apk
```

Target architectures:

- `x86_64`
- `aarch64`

## APK package

Package name:

```text
webowie-nodeos
```

Package contents:

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

The package creates a dedicated `webowie` system user/group.

## Runtime dependencies

Runtime packages remain intentionally useful for administration and storage. Go and Make are excluded from the target node.

Required runtime package set:

```text
sudo
bash
ca-certificates
curl
wget
git
tar
ffmpeg
net-tools
iproute2
procps-ng
util-linux
coreutils
findutils
tzdata
shadow
cifs-utils
nfs-utils
fuse3
```

Build-only packages such as Go, Make, `alpine-sdk`, `abuild` and compilation dependencies exist only inside CI/build workers.

## OpenRC

The APK installs:

```text
/etc/init.d/webowie-nodeos
/etc/conf.d/webowie-nodeos
```

The service starts the webOwie runtime from `/opt/webOwie_nodeOS` as `webowie:webowie`.

Default arguments:

```text
-host=0.0.0.0
-port=8080
-hostname=webOwie-node-OS
-allow_pkg_install=false
-enable_hwman=false
-enable_pwman=false
-enable_docker=false
-allow_upnp=false
-arozcast_turn=false
-max_upload_size=1024
-buffpool_size=256
-upload_buf=25
-root=/opt/webOwie_nodeOS/files
-tmp=/opt/webOwie_nodeOS/tmp
```

The Proxmox installer, not the package post-install script, is responsible for enabling and starting the service:

```sh
rc-update add webowie-nodeos default
rc-service webowie-nodeos start
```

This keeps package installation behavior predictable and lets provisioning surface startup failures clearly.

## Mutable state and upgrades

Runtime upgrades must not destroy node identity, databases, storage definitions or logs.

The packaging/update path must preserve at minimum:

```text
system/dev.uuid
system/ao.db
system/smtp_conf.json
system/storage.json
system/cron.json
system/bridge.json
system/auth/authlog.db
system/aecron/
system/logs/
system/storage/
files/
```

Before shipping automatic `apk upgrade` support, package upgrade scripts must prove that these paths survive upgrade and rollback testing.

## Launcher integration

The ArozOS launcher is a separate future component and will be forked/rebranded as `webOwie_nodeOS Launcher`.

It may continue to expose the compatibility listener on `127.0.0.1:25576` so the existing ArozOS update UI can detect a launcher.

The launcher update source will point only to webOwie-controlled release assets. It must never download an unbranded ArozOS release directly onto an installed node.

APK responsibilities:

- Alpine package dependencies
- OpenRC integration
- filesystem layout
- product installation/versioning

Launcher responsibilities:

- runtime supervision
- web UI initiated OTA runtime updates
- runtime rollback

## Release assets

Each GitHub release should publish at least:

```text
webowie-nodeos-<version>-r0-x86_64.apk
webowie-nodeos-<version>-r0-aarch64.apk
SHA256SUMS
```

Optional compatibility artifacts:

```text
webowie-nodeos_linux_amd64
webowie-nodeos_linux_arm64
web.tar.gz
update.json
```

## Proxmox install flow

Community-Scripts remains responsible for Alpine LXC creation.

The webOwie install section becomes approximately:

```text
create Alpine LXC
    ↓
install small runtime/tool dependency set
    ↓
download architecture-matching webowie-nodeos APK
    ↓
apk add --allow-untrusted ./webowie-nodeos.apk
    ↓
rc-update add webowie-nodeos default
    ↓
rc-service webowie-nodeos start
    ↓
health check
```

Once a signed webOwie Alpine repository exists, `--allow-untrusted` is removed and installation becomes normal repository-based `apk add webowie-nodeos`.

## Testing requirements

CI must fail if any of these checks fail:

1. Shell syntax checks for branding, installer and package scripts.
2. Branding test confirms required source assets are present.
3. Branding test confirms staged visible UI contains `webOwie_nodeOS`.
4. Branding test confirms upstream attribution remains present.
5. Build succeeds for `x86_64` and `aarch64`.
6. APK is structurally valid and inspectable by `apk`.
7. APK contains OpenRC service and conf.d files.
8. Package metadata declares runtime dependencies.
9. Smoke test installs the APK in Alpine 3.24.
10. Smoke test enables and starts the OpenRC service.
11. HTTP health check reaches the configured port.
12. Upgrade test proves mutable state survives a package upgrade before automatic upgrades are enabled.

## Non-goals

This implementation does not:

- rename Go module paths from `imuslab.com/arozos`
- rename internal APIs solely for branding
- remove upstream copyright/license attribution
- make Docker part of the nodeOS runtime
- compile Go code on installed production nodes

## Definition of done

The work is complete when:

- branding pack is committed under `branding/master/`
- staged ArozOS UI visibly presents `webOwie_nodeOS`
- About/System Info contains the webOwie box plus ArozOS attribution
- APKBUILD and OpenRC files are committed
- GitHub Actions builds `x86_64` and `aarch64` packages
- a real installable `.apk` artifact is produced
- package installs on Alpine 3.24 without Go or Make
- `webowie-nodeos` can be enabled and started through OpenRC
- the existing Proxmox installer can install the package by downloading the architecture-matching APK
