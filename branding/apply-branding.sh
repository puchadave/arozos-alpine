#!/bin/sh
set -eu

INSTALL="${INSTALL:-/opt/webOwie_nodeOS}"
BRAND="webOwie_nodeOS"
VENDOR="webOwie"
PROJECT_URL="https://github.com/puchadave/arozos-alpine"

[ -d "$INSTALL" ] || {
  echo "ERROR: runtime directory not found: $INSTALL" >&2
  exit 1
}

mkdir -p "$INSTALL/vendor-res"

cat >"$INSTALL/vendor-res/vendor_info.json" <<'EOF'
{
  "vendor": "webOwie",
  "url": "https://github.com/puchadave/arozos-alpine",
  "model": "webOwie_nodeOS",
  "desc": "Alpine-native webOwie node operating environment powered by ArozOS"
}
EOF

replace() {
  file="$1"
  from="$2"
  to="$3"
  [ -f "$file" ] || return 0
  sed -i "s|$from|$to|g" "$file"
}

# Login / authentication branding
replace "$INSTALL/web/login.html" 'ArozOS - Login' 'webOwie_nodeOS - Login'
replace "$INSTALL/web/login.html" '>ArozOS</span>' '>webOwie_nodeOS</span>'
replace "$INSTALL/web/login.html" 'https://os.aroz.org">ArozOS</a>' 'https://github.com/puchadave/arozos-alpine">webOwie_nodeOS</a>'

# Desktop and mobile shell branding
replace "$INSTALL/web/desktop.html" '<title>ArozOS Desktop</title>' '<title>webOwie_nodeOS Desktop</title>'
replace "$INSTALL/web/mobile.html" '<title>ArozOS</title>' '<title>webOwie_nodeOS</title>'

# PWA metadata
replace "$INSTALL/web/manifest.webmanifest" '"name": "ArozOS Mobile"' '"name": "webOwie_nodeOS"'
replace "$INSTALL/web/manifest.webmanifest" '"short_name": "ArozOS"' '"short_name": "webOwie"'
replace "$INSTALL/web/manifest.webmanifest" 'Connecting to your arozos with one shortcut' 'Connect to your webOwie_nodeOS with one shortcut'

# Boot/error fallback page. Keep explicit upstream attribution.
replace "$INSTALL/web/index.html" '<title>ArOZ Online Bootloader</title>' '<title>webOwie_nodeOS Bootloader</title>'
replace "$INSTALL/web/index.html" 'ArozOS Cloud Operating System, Developed by tobychui since 2016.' 'webOwie_nodeOS, powered by ArozOS. ArozOS developed by tobychui / IMUSLAB since 2016.'

cat >"$INSTALL/vendor-res/NOTICE.txt" <<EOF
$BRAND
Vendor: $VENDOR
Project: $PROJECT_URL

webOwie_nodeOS is an Alpine/OpenRC deployment and branding layer built on ArozOS.
ArozOS upstream: https://github.com/tobychui/arozos
ArozOS is licensed under GNU GPL-3.0.
EOF

printf 'Applied %s branding to %s\n' "$BRAND" "$INSTALL"
