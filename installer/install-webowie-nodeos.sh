#!/bin/sh
set -eu

REPO="${WEBOWIE_REPO:-puchadave/arozos-alpine}"
SERVICE_NAME="${SERVICE_NAME:-webowie-nodeos}"
APK_ASSET="${APK_ASSET:-webowie-nodeos-x86_64.apk}"
APK_URL="${APK_URL:-https://github.com/${REPO}/releases/download/apk-latest/${APK_ASSET}}"
TMP_APK="${TMP_APK:-/tmp/${APK_ASSET}}"

log() { printf '\n==> %s\n' "$*"; }
die() { printf '\nERROR: %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "Run this installer as root."
[ -f /etc/alpine-release ] || die "webOwie_nodeOS requires Alpine Linux."

ARCH="$(apk --print-arch)"
case "$ARCH" in
  x86_64) ;;
  *) die "Unsupported Alpine architecture for current release: $ARCH" ;;
esac

log "Downloading production webOwie_nodeOS APK"
apk add --no-cache ca-certificates curl
update-ca-certificates
curl -fL --retry 3 "$APK_URL" -o "$TMP_APK"

log "Installing webOwie_nodeOS"
apk add --no-cache --allow-untrusted "$TMP_APK"
rm -f "$TMP_APK"

log "Enabling OpenRC service"
rc-update add "$SERVICE_NAME" default >/dev/null 2>&1 || true
rc-service "$SERVICE_NAME" restart

ok=0
for i in $(seq 1 20); do
  if curl -fsS http://127.0.0.1:8080/ >/dev/null 2>&1; then
    ok=1
    break
  fi
  sleep 1
done

if [ "$ok" -ne 1 ]; then
  rc-service "$SERVICE_NAME" status || true
  tail -n 100 /var/log/webowie-nodeos.log 2>/dev/null || true
  die "webOwie_nodeOS did not become ready on port 8080"
fi

IP="$(ip -4 -o addr show scope global 2>/dev/null | awk '{split($4,a,"/"); print a[1]; exit}')"
printf '\nwebOwie_nodeOS is running at: http://%s:8080/\n' "${IP:-SERVER-IP}"
printf 'Service: rc-service %s status\n' "$SERVICE_NAME"
