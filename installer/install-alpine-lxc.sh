#!/bin/sh
set -eu

REPO="${REPO:-https://github.com/tobychui/arozos.git}"
REF="${REF:-master}"
SRC="${SRC:-/usr/local/src/arozos}"
INSTALL="${INSTALL:-/opt/arozos}"
PORT="${PORT:-8080}"
AROZ_HOSTNAME="${AROZ_HOSTNAME:-arozos}"
SERVICE_USER="${SERVICE_USER:-arozos}"
SERVICE_GROUP="${SERVICE_GROUP:-arozos}"

log() { printf '\n==> %s\n' "$*"; }
die() { printf '\nERROR: %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "Run this installer as root."
[ -f /etc/alpine-release ] || die "This installer is intended for Alpine Linux."

log "Installing Alpine dependencies"
apk update
apk add --no-cache \
  bash ca-certificates git go make tar curl wget ffmpeg \
  net-tools iproute2 procps util-linux coreutils findutils tzdata shadow
update-ca-certificates

log "Checking Go version"
go version
GO_VERSION="$(go env GOVERSION | sed 's/^go//')"
GO_MAJOR="${GO_VERSION%%.*}"
GO_REST="${GO_VERSION#*.}"
GO_MINOR="${GO_REST%%.*}"
if [ "$GO_MAJOR" -lt 1 ] || { [ "$GO_MAJOR" -eq 1 ] && [ "$GO_MINOR" -lt 25 ]; }; then
  die "ArozOS master currently requires Go >= 1.25; installed: $(go env GOVERSION)"
fi

log "Creating service account"
if ! getent group "$SERVICE_GROUP" >/dev/null 2>&1; then
  addgroup -S "$SERVICE_GROUP"
fi
if ! id "$SERVICE_USER" >/dev/null 2>&1; then
  adduser -S -D -H -h "$INSTALL" -s /sbin/nologin -G "$SERVICE_GROUP" "$SERVICE_USER"
fi

log "Cloning ArozOS source"
rm -rf "$SRC"
mkdir -p "$(dirname "$SRC")"
git clone --depth=1 --branch "$REF" "$REPO" "$SRC"

log "Building native ArozOS binary"
cd "$SRC/src"
go mod download
CGO_ENABLED=0 go build -trimpath -ldflags='-s -w' -o /tmp/arozos .

log "Building runtime web/system bundle"
make web
[ -f "$SRC/src/dist/web.tar.gz" ] || die "Build did not create dist/web.tar.gz"

log "Installing into $INSTALL"
rm -rf "$INSTALL"
mkdir -p "$INSTALL" "$INSTALL/files" "$INSTALL/tmp"
install -m 0755 /tmp/arozos "$INSTALL/arozos"
tar -xzf "$SRC/src/dist/web.tar.gz" -C "$INSTALL"
mkdir -p "$INSTALL/files" "$INSTALL/tmp"
chown -R "$SERVICE_USER:$SERVICE_GROUP" "$INSTALL"

log "Configuring OpenRC"
cat >/etc/conf.d/arozos <<EOF_CONF
AROZOS_OPTS="-host=0.0.0.0 -port=${PORT} -hostname=${AROZ_HOSTNAME} -allow_pkg_install=false -enable_hwman=false -enable_pwman=false -enable_docker=false -allow_upnp=false -arozcast_turn=false -max_upload_size=1024 -buffpool_size=256 -upload_buf=25 -root=${INSTALL}/files -tmp=${INSTALL}/tmp"
EOF_CONF

cat >/etc/init.d/arozos <<EOF_SERVICE
#!/sbin/openrc-run
name="ArozOS"
description="ArozOS Cloud / Web Desktop"
command="${INSTALL}/arozos"
command_args="\${AROZOS_OPTS}"
command_user="${SERVICE_USER}:${SERVICE_GROUP}"
directory="${INSTALL}"
command_background="yes"
pidfile="/run/\${RC_SVCNAME}.pid"

depend() {
  need net
  after firewall
}
EOF_SERVICE
chmod 0755 /etc/init.d/arozos
rc-update add arozos default >/dev/null 2>&1 || true

log "Starting ArozOS"
rc-service arozos restart
sleep 2
rc-service arozos status || true

IP="$(ip -4 -o addr show scope global 2>/dev/null | awk '{split($4,a,"/"); print a[1]; exit}')"
printf '\nArozOS should now be available at: http://%s:%s/\n' "${IP:-LXC-IP}" "$PORT"
printf 'Service status: rc-service arozos status\n'
