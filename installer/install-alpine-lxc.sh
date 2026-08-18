#!/bin/sh
set -eu

URL="${WEBOWIE_INSTALLER_URL:-https://raw.githubusercontent.com/puchadave/arozos-alpine/main/installer/install-webowie-nodeos.sh}"
TMP="$(mktemp /tmp/webowie-nodeos-installer.XXXXXX)"
trap 'rm -f "$TMP"' EXIT INT TERM

printf 'Legacy installer path detected. Switching to webOwie_nodeOS installer.\n'
curl -fsSL --retry 3 "$URL" -o "$TMP"
chmod 0755 "$TMP"
exec /bin/sh "$TMP" "$@"
