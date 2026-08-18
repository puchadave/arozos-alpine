#!/bin/sh
set -eu
PROFILE="${1:-iso/mkimg.webowie_nodeos.sh}"
OVERLAY="${2:-iso/genapkovl-webowie-nodeos.sh}"

fail() { echo "FAIL: $*" >&2; exit 1; }

grep -q 'profile_webowie_nodeos()' "$PROFILE" || fail "custom ISO profile missing"
grep -q 'profile_standard' "$PROFILE" || fail "ISO must inherit Alpine standard profile"
grep -q 'hostname="webowie-nodeos-live"' "$PROFILE" || fail "live hostname missing"
grep -q 'arch="x86_64"' "$PROFILE" || fail "ISO must be x86_64-only"
grep -q 'net-tools' "$PROFILE" || fail "net-tools not included on ISO"
grep -q 'iproute2' "$PROFILE" || fail "iproute2 not included on ISO"
grep -q 'apkovl="scripts/genapkovl-webowie-nodeos.sh"' "$PROFILE" || fail "custom apkovl not wired"

grep -q '^net-tools$' "$OVERLAY" || fail "net-tools not installed in live root"
grep -q '^iproute2$' "$OVERLAY" || fail "iproute2 not installed in live root"
grep -q 'rc_add networking boot' "$OVERLAY" || fail "OpenRC networking not enabled"
grep -q 'modprobe virtio_net' "$OVERLAY" || fail "virtio_net preload missing"
grep -q 'modprobe e1000' "$OVERLAY" || fail "e1000 fallback preload missing"
grep -q 'modprobe vmxnet3' "$OVERLAY" || fail "vmxnet3 fallback preload missing"
grep -q '/sys/class/net/' "$OVERLAY" || fail "dynamic NIC discovery missing"

if grep -qi 'multiboot' "$PROFILE" "$OVERLAY"; then
  fail "multiboot configuration must not be present"
fi

echo "PASS: webOwie_nodeOS live ISO profile invariants"
