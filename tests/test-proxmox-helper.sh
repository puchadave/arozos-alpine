#!/bin/sh
set -eu
SCRIPT="${1:-proxmox/webowie-nodeos.sh}"
[ -f "$SCRIPT" ] || { echo "FAIL: missing $SCRIPT"; exit 1; }
grep -q 'pveam update' "$SCRIPT" || { echo 'FAIL: missing pveam update'; exit 1; }
grep -q 'pct create' "$SCRIPT" || { echo 'FAIL: missing pct create'; exit 1; }
grep -q 'unprivileged 1' "$SCRIPT" || { echo 'FAIL: container must be unprivileged'; exit 1; }
grep -Eq 'ALPINE_VERSION=.*3\.24' "$SCRIPT" || { echo 'FAIL: Alpine 3.24 template not pinned'; exit 1; }
grep -q 'install-webowie-nodeos.sh' "$SCRIPT" || { echo 'FAIL: production installer not invoked'; exit 1; }
grep -q '127.0.0.1:8080' "$SCRIPT" || { echo 'FAIL: nodeOS healthcheck missing'; exit 1; }
grep -q 'WEBOWIE_MODE' "$SCRIPT" || { echo 'FAIL: generated/unattended mode missing'; exit 1; }
grep -q 'Default Installation' "$SCRIPT" || { echo 'FAIL: default menu missing'; exit 1; }
grep -q 'Advanced Installation' "$SCRIPT" || { echo 'FAIL: advanced menu missing'; exit 1; }
echo PASS
