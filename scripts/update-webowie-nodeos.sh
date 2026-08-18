#!/bin/sh
set -eu

UPSTREAM_REPO="${UPSTREAM_REPO:-https://github.com/tobychui/arozos.git}"
UPSTREAM_REF="${UPSTREAM_REF:-master}"
WEBOWIE_RAW="${WEBOWIE_RAW:-https://raw.githubusercontent.com/puchadave/arozos-alpine/main}"
INSTALL="${INSTALL:-/opt/webOwie_nodeOS}"
SERVICE_NAME="${SERVICE_NAME:-webowie-nodeos}"
SERVICE_USER="${SERVICE_USER:-webowie}"
SERVICE_GROUP="${SERVICE_GROUP:-webowie}"
WORK="${WORK:-/tmp/webowie-nodeos-update}"

log() { printf '\n==> %s\n' "$*"; }
die() { printf '\nERROR: %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "Run this updater as root."
[ -f /etc/alpine-release ] || die "This updater requires Alpine Linux."
[ -d "$INSTALL/system" ] || die "webOwie_nodeOS installation not found at $INSTALL"
[ -f "/etc/init.d/$SERVICE_NAME" ] || die "OpenRC service $SERVICE_NAME not found"

apk add --no-cache ca-certificates git go make tar curl ffmpeg >/dev/null

rm -rf "$WORK"
mkdir -p "$WORK/src" "$WORK/runtime" "$WORK/preserve"

log "Fetching latest ArozOS upstream"
git clone --depth=1 --branch "$UPSTREAM_REF" "$UPSTREAM_REPO" "$WORK/src"
UPSTREAM_SHA="$(git -C "$WORK/src" rev-parse HEAD)"
CURRENT_SHA=""
if [ -f "$INSTALL/vendor-res/upstream.json" ]; then
  CURRENT_SHA="$(sed -n 's/.*"commit": "\([^"]*\)".*/\1/p' "$INSTALL/vendor-res/upstream.json" | head -n1)"
fi

if [ -n "$CURRENT_SHA" ] && [ "$CURRENT_SHA" = "$UPSTREAM_SHA" ]; then
  printf 'webOwie_nodeOS is already based on upstream commit %s\n' "$UPSTREAM_SHA"
  rm -rf "$WORK"
  exit 0
fi

log "Building new upstream core"
cd "$WORK/src/src"
go mod download
CGO_ENABLED=0 go build -trimpath -ldflags='-s -w' -o "$WORK/webowie-nodeos" .
make web
[ -f "$WORK/src/src/dist/web.tar.gz" ] || die "Upstream build did not create web.tar.gz"
tar -xzf "$WORK/src/src/dist/web.tar.gz" -C "$WORK/runtime"

log "Preserving mutable node state"
for path in \
  system/dev.uuid \
  system/ao.db \
  system/smtp_conf.json \
  system/storage.json \
  system/cron.json \
  system/bridge.json \
  system/auth/authlog.db \
  system/aecron \
  system/logs \
  system/storage; do
  if [ -e "$INSTALL/$path" ]; then
    mkdir -p "$WORK/preserve/$(dirname "$path")"
    cp -a "$INSTALL/$path" "$WORK/preserve/$path"
  fi
done

log "Stopping webOwie_nodeOS"
rc-service "$SERVICE_NAME" stop

rollback_needed=1
rollback() {
  if [ "$rollback_needed" -eq 1 ]; then
    echo "ERROR: update failed. Attempting to restart existing service." >&2
    rc-service "$SERVICE_NAME" start >/dev/null 2>&1 || true
  fi
}
trap rollback EXIT INT TERM

log "Installing updated core and runtime"
cp "$WORK/webowie-nodeos" "$INSTALL/webowie-nodeos.new"
chmod 0755 "$INSTALL/webowie-nodeos.new"

rm -rf "$INSTALL/web.new" "$INSTALL/system.new"
cp -a "$WORK/runtime/web" "$INSTALL/web.new"
cp -a "$WORK/runtime/system" "$INSTALL/system.new"

for path in \
  system/dev.uuid \
  system/ao.db \
  system/smtp_conf.json \
  system/storage.json \
  system/cron.json \
  system/bridge.json \
  system/auth/authlog.db \
  system/aecron \
  system/logs \
  system/storage; do
  if [ -e "$WORK/preserve/$path" ]; then
    target_rel="${path#system/}"
    rm -rf "$INSTALL/system.new/$target_rel"
    mkdir -p "$INSTALL/system.new/$(dirname "$target_rel")"
    cp -a "$WORK/preserve/$path" "$INSTALL/system.new/$target_rel"
  fi
done

rm -rf "$INSTALL/web.old" "$INSTALL/system.old"
mv "$INSTALL/web" "$INSTALL/web.old"
mv "$INSTALL/system" "$INSTALL/system.old"
mv "$INSTALL/web.new" "$INSTALL/web"
mv "$INSTALL/system.new" "$INSTALL/system"
mv "$INSTALL/webowie-nodeos" "$INSTALL/webowie-nodeos.old"
mv "$INSTALL/webowie-nodeos.new" "$INSTALL/webowie-nodeos"

log "Reapplying webOwie_nodeOS branding"
curl -fsSL --retry 3 "$WEBOWIE_RAW/branding/apply-branding.sh" -o "$WORK/apply-branding.sh"
chmod 0755 "$WORK/apply-branding.sh"
INSTALL="$INSTALL" "$WORK/apply-branding.sh"

cat >"$INSTALL/vendor-res/upstream.json" <<EOF
{
  "repository": "$UPSTREAM_REPO",
  "ref": "$UPSTREAM_REF",
  "commit": "$UPSTREAM_SHA"
}
EOF

chown -R "$SERVICE_USER:$SERVICE_GROUP" "$INSTALL"

log "Starting updated webOwie_nodeOS"
rc-service "$SERVICE_NAME" start
sleep 2
rc-service "$SERVICE_NAME" status

rollback_needed=0
trap - EXIT INT TERM
rm -rf "$INSTALL/web.old" "$INSTALL/system.old" "$INSTALL/webowie-nodeos.old" "$WORK"

printf '\nUpdated webOwie_nodeOS from %s to %s\n' "${CURRENT_SHA:-unknown}" "$UPSTREAM_SHA"
