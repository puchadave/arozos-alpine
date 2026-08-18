#!/bin/sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
DIST="${DIST:-$ROOT/dist}"
UPSTREAM_REPO="${UPSTREAM_REPO:-https://github.com/tobychui/arozos.git}"
UPSTREAM_REF="${UPSTREAM_REF:-master}"
PKGVER="${WEBOWIE_PKGVER:-0.1.0_git$(date -u +%Y%m%d%H%M%S)}"
WORK="${WORK:-/tmp/webowie-nodeos-apk}"

[ "$(id -u)" -eq 0 ] || {
  echo "ERROR: build-apk.sh must run as root inside the Alpine build container" >&2
  exit 1
}

[ "$(apk --print-arch)" = "x86_64" ] || {
  echo "ERROR: current APK pipeline builds x86_64 packages only" >&2
  exit 1
}

cat >/etc/apk/repositories <<'EOF_REPOS'
https://dl-cdn.alpinelinux.org/alpine/v3.24/main
https://dl-cdn.alpinelinux.org/alpine/v3.24/community
EOF_REPOS

apk update
apk add \
  alpine-sdk sudo bash ca-certificates git go make tar curl
update-ca-certificates
apk update

rm -rf "$WORK"
mkdir -p "$WORK" "$DIST"

if ! id builder >/dev/null 2>&1; then
  adduser -D builder
fi
addgroup builder abuild 2>/dev/null || true
addgroup builder wheel 2>/dev/null || true
mkdir -p /etc/sudoers.d
printf '%%wheel ALL=(ALL) NOPASSWD: ALL\n' > /etc/sudoers.d/webowie-abuild
chmod 0440 /etc/sudoers.d/webowie-abuild

mkdir -p "$WORK/pkg" "$WORK/runtime" /home/builder/packages
cp -a "$ROOT/packaging/." "$WORK/pkg/"
chown -R builder:builder "$WORK" /home/builder/packages

su builder -s /bin/sh -c "
set -eu

git clone --depth=1 --branch '$UPSTREAM_REF' '$UPSTREAM_REPO' '$WORK/upstream'
UPSTREAM_SHA=\$(git -C '$WORK/upstream' rev-parse HEAD)

cd '$WORK/upstream/src'
go mod download
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
  go build -trimpath -ldflags='-s -w' -o '$WORK/runtime/webowie-nodeos' .

make web
test -f dist/web.tar.gz
tar -xzf dist/web.tar.gz -C '$WORK/runtime'
mkdir -p '$WORK/runtime/files' '$WORK/runtime/tmp' '$WORK/runtime/vendor-res'

INSTALL='$WORK/runtime' sh '$ROOT/branding/apply-branding.sh'

cat >'$WORK/runtime/vendor-res/upstream.json' <<EOF_UPSTREAM
{
  \"repository\": \"$UPSTREAM_REPO\",
  \"ref\": \"$UPSTREAM_REF\",
  \"commit\": \"\$UPSTREAM_SHA\"
}
EOF_UPSTREAM

# The upstream web/system bundle can contain helper executables for multiple
# CPU architectures. A native x86_64 Alpine package must not expose ARM or
# other foreign ELF binaries to abuild dependency tracing.
echo 'Scanning runtime for foreign-architecture ELF files'
find '$WORK/runtime' -type f | while IFS= read -r candidate; do
  desc=\$(file -b \"\$candidate\" 2>/dev/null || true)
  case \"\$desc\" in
    *ELF*)
      case \"\$desc\" in
        *x86-64*) ;;
        *)
          echo \"Removing non-x86_64 ELF: \$candidate (\$desc)\"
          rm -f \"\$candidate\"
          ;;
      esac
      ;;
  esac
done

test -x '$WORK/runtime/webowie-nodeos'
chmod 0755 '$WORK/runtime/webowie-nodeos'
tar -C '$WORK' -czf '$WORK/pkg/webowie-nodeos-runtime.tar.gz' runtime

cd '$WORK/pkg'
WEBOWIE_PKGVER='$PKGVER' abuild checksum
abuild-keygen -ain
WEBOWIE_PKGVER='$PKGVER' abuild -r
"

APK="$(find /home/builder/packages -type f -name 'webowie-nodeos-*.apk' | head -n1)"
[ -n "$APK" ] && [ -s "$APK" ] || {
  echo "ERROR: abuild did not produce a webowie-nodeos APK" >&2
  exit 1
}

cp "$APK" "$DIST/webowie-nodeos-x86_64.apk"
printf '%s\n' "$PKGVER" > "$DIST/webowie-nodeos-version.txt"
sha256sum "$DIST/webowie-nodeos-x86_64.apk" > "$DIST/webowie-nodeos-x86_64.apk.sha256"

printf 'Built %s\n' "$DIST/webowie-nodeos-x86_64.apk"
printf 'Package version: %s\n' "$PKGVER"
