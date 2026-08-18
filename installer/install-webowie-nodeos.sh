#!/bin/sh
set -eu

UPSTREAM_REPO="${UPSTREAM_REPO:-https://github.com/tobychui/arozos.git}"
UPSTREAM_REF="${UPSTREAM_REF:-master}"
WEBOWIE_RAW="${WEBOWIE_RAW:-https://raw.githubusercontent.com/puchadave/arozos-alpine/main}"
SRC="${SRC:-/usr/local/src/webOwie_nodeOS-upstream}"
INSTALL="${INSTALL:-/opt/webOwie_nodeOS}"
PORT="${PORT:-8080}"
NODE_HOSTNAME="${NODE_HOSTNAME:-webOwie-nodeOS}"
SERVICE_NAME="${SERVICE_NAME:-webowie-nodeos}"
SERVICE_USER="${SERVICE_USER:-webowie}"
SERVICE_GROUP="${SERVICE_GROUP:-webowie}"

log() { printf '\n==> %s\n' "$*"; }
die() { printf '\nERROR: %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "Run this installer as root."
[ -f /etc/alpine-release ] || die "webOwie_nodeOS requires Alpine Linux."

if [ -e "$INSTALL/system/ao.db" ] || [ -e "$INSTALL/files" ]; then
  die "Existing webOwie_nodeOS installation detected at $INSTALL. Use scripts/update-webowie-nodeos.sh instead of reinstalling."
fi

log "Installing Alpine build/runtime dependencies"
apk update
apk add --no-cache \
  bash ca-certificates git go make tar curl wget ffmpeg \
  net-tools iproute2 procps util-linux coreutils findutils tzdata shadow
update-ca-certificates

log "Checking Go toolchain"
go version
GO_VERSION="$(go env GOVERSION | sed 's/^go//')"
GO_MAJOR="${GO_VERSION%%.*}"
GO_REST="${GO_VERSION#*.}"
GO_MINOR="${GO_REST%%.*}"
if [ "$GO_MAJOR" -lt 1 ] || { [ "$GO_MAJOR" -eq 1 ] && [ "$GO_MINOR" -lt 25 ]; }; then
  die "Current ArozOS upstream requires Go >= 1.25; installed: $(go env GOVERSION)"
fi

log "Creating webOwie service account"
if ! getent group "$SERVICE_GROUP" >/dev/null 2>&1; then
  addgroup -S "$SERVICE_GROUP"
fi
if ! id "$SERVICE_USER" >/dev/null 2>&1; then
  adduser -S -D -H -h "$INSTALL" -s /sbin/nologin -G "$SERVICE_GROUP" "$SERVICE_USER"
fi

log "Fetching current ArozOS upstream source"
rm -rf "$SRC"
mkdir -p "$(dirname "$SRC")"
git clone --depth=1 --branch "$UPSTREAM_REF" "$UPSTREAM_REPO" "$SRC"
UPSTREAM_SHA="$(git -C "$SRC" rev-parse HEAD)"

log "Building native webOwie_nodeOS core from ArozOS upstream"
cd "$SRC/src"
go mod download
CGO_ENABLED=0 go build -trimpath -ldflags='-s -w' -o /tmp/webowie-nodeos .

log "Building upstream runtime bundle"
make web
[ -f "$SRC/src/dist/web.tar.gz" ] || die "Upstream build did not create dist/web.tar.gz"

log "Installing webOwie_nodeOS runtime"
rm -rf "$INSTALL"
mkdir -p "$INSTALL"
install -m 0755 /tmp/webowie-nodeos "$INSTALL/webowie-nodeos"
tar -xzf "$SRC/src/dist/web.tar.gz" -C "$INSTALL"
mkdir -p "$INSTALL/files" "$INSTALL/tmp" "$INSTALL/vendor-res"

log "Applying webOwie_nodeOS branding layer"
curl -fsSL --retry 3 "$WEBOWIE_RAW/branding/apply-branding.sh" -o /tmp/webowie-branding.sh
chmod 0755 /tmp/webowie-branding.sh
INSTALL="$INSTALL" /tmp/webowie-branding.sh

cat >"$INSTALL/vendor-res/upstream.json" <<EOF
{
  "repository": "$UPSTREAM_REPO",
  "ref": "$UPSTREAM_REF",
  "commit": "$UPSTREAM_SHA"
}
EOF

log "Configuring OpenRC service"
cat >"/etc/conf.d/$SERVICE_NAME" <<EOF_CONF
WEBOWIE_NODEOS_OPTS="-host=0.0.0.0 -port=${PORT} -hostname=${NODE_HOSTNAME} -allow_pkg_install=false -enable_hwman=false -enable_pwman=false -enable_docker=false -allow_upnp=false -arozcast_turn=false -max_upload_size=1024 -buffpool_size=256 -upload_buf=25 -root=${INSTALL}/files -tmp=${INSTALL}/tmp"
EOF_CONF

cat >"/etc/init.d/$SERVICE_NAME" <<EOF_SERVICE
#!/sbin/openrc-run
name="webOwie_nodeOS"
description="webOwie_nodeOS Alpine node environment"
command="${INSTALL}/webowie-nodeos"
command_args="\${WEBOWIE_NODEOS_OPTS}"
command_user="${SERVICE_USER}:${SERVICE_GROUP}"
directory="${INSTALL}"
command_background="yes"
pidfile="/run/\${RC_SVCNAME}.pid"

depend() {
  need net
  after firewall
}
EOF_SERVICE
chmod 0755 "/etc/init.d/$SERVICE_NAME"
rc-update add "$SERVICE_NAME" default >/dev/null 2>&1 || true

# Remove the legacy service name created by early versions of this repository.
if [ -f /etc/init.d/arozos ]; then
  rc-service arozos stop >/dev/null 2>&1 || true
  rc-update del arozos default >/dev/null 2>&1 || true
fi

chown -R "$SERVICE_USER:$SERVICE_GROUP" "$INSTALL"

log "Starting webOwie_nodeOS"
rc-service "$SERVICE_NAME" restart
sleep 2
rc-service "$SERVICE_NAME" status || true

IP="$(ip -4 -o addr show scope global 2>/dev/null | awk '{split($4,a,"/"); print a[1]; exit}')"
printf '\nwebOwie_nodeOS is available at: http://%s:%s/\n' "${IP:-LXC-IP}" "$PORT"
printf 'Service: rc-service %s status\n' "$SERVICE_NAME"
printf 'ArozOS upstream commit: %s\n' "$UPSTREAM_SHA"
