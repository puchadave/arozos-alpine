#!/bin/sh
set -eu
PAGE="${1:-proxmox/configurator/index.html}"
[ -f "$PAGE" ] || { echo "FAIL: missing $PAGE"; exit 1; }
grep -q 'WEBOWIE_MODE' "$PAGE" && grep -q 'generated' "$PAGE" || { echo 'FAIL: generated mode command missing'; exit 1; }
grep -q 'CTID' "$PAGE" || { echo 'FAIL: CTID field missing'; exit 1; }
grep -q 'MEMORY' "$PAGE" || { echo 'FAIL: memory field missing'; exit 1; }
grep -q 'BRIDGE' "$PAGE" || { echo 'FAIL: bridge field missing'; exit 1; }
grep -q 'webowie-nodeos.sh' "$PAGE" || { echo 'FAIL: helper URL missing'; exit 1; }
echo PASS
