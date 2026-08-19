#!/usr/bin/env bash
set -Eeuo pipefail

# webOwie_nodeOS Proxmox LXC helper
# Creates an unprivileged Alpine Linux 3.24 LXC and installs the production
# webOwie_nodeOS APK through the canonical in-container installer.

PRODUCT="webOwie_nodeOS"
ALPINE_VERSION="${ALPINE_VERSION:-3.24}"
WEBOWIE_REPO="${WEBOWIE_REPO:-puchadave/arozos-alpine}"
INSTALLER_URL="${INSTALLER_URL:-https://raw.githubusercontent.com/${WEBOWIE_REPO}/main/installer/install-webowie-nodeos.sh}"
WEBOWIE_MODE="${WEBOWIE_MODE:-interactive}"

CORES="${CORES:-2}"
MEMORY="${MEMORY:-2048}"
SWAP="${SWAP:-512}"
DISK="${DISK:-8}"
BRIDGE="${BRIDGE:-vmbr0}"
IP_CONFIG="${IP_CONFIG:-dhcp}"
GATEWAY="${GATEWAY:-}"
VLAN_TAG="${VLAN_TAG:-}"
ONBOOT="${ONBOOT:-1}"
ROOTFS_STORAGE="${ROOTFS_STORAGE:-}"
TEMPLATE_STORAGE="${TEMPLATE_STORAGE:-}"
CTID="${CTID:-}"
HOSTNAME="${HOSTNAME:-}"

log() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
warn() { printf '\n\033[1;33mWARN: %s\033[0m\n' "$*" >&2; }
die() { printf '\n\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

need_cmd() { command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"; }

validate_uint() {
  local name="$1" value="$2"
  [[ "$value" =~ ^[0-9]+$ ]] || die "$name must be a positive integer (got: $value)"
  (( value > 0 )) || die "$name must be greater than zero"
}

find_storage() {
  local content="$1"
  pvesm status -content "$content" 2>/dev/null | awk 'NR>1 && $3=="active" {print $1; exit}'
}

next_ctid() {
  pvesh get /cluster/nextid 2>/dev/null
}

show_defaults() {
  cat <<EOF_DEFAULTS
Default Installation
  Alpine:          ${ALPINE_VERSION}
  Container:       unprivileged
  CPU:             ${CORES} cores
  RAM:             ${MEMORY} MiB
  Swap:            ${SWAP} MiB
  Disk:            ${DISK} GiB
  Bridge:          ${BRIDGE}
  Network:         ${IP_CONFIG}
  Start at boot:   ${ONBOOT}
  nodeOS port:     8080
EOF_DEFAULTS
}

prompt() {
  local label="$1" default="$2" value
  read -r -p "$label [$default]: " value
  printf '%s' "${value:-$default}"
}

advanced_installation() {
  local suggested_id
  suggested_id="${CTID:-$(next_ctid)}"
  CTID="$(prompt 'Container ID' "$suggested_id")"
  HOSTNAME="$(prompt 'Hostname' "${HOSTNAME:-webowie-nodeos-${CTID}}")"
  CORES="$(prompt 'CPU cores' "$CORES")"
  MEMORY="$(prompt 'Memory MiB' "$MEMORY")"
  SWAP="$(prompt 'Swap MiB' "$SWAP")"
  DISK="$(prompt 'Disk GiB' "$DISK")"
  BRIDGE="$(prompt 'Bridge' "$BRIDGE")"
  IP_CONFIG="$(prompt 'IP (dhcp or CIDR)' "$IP_CONFIG")"
  if [[ "$IP_CONFIG" != "dhcp" ]]; then
    GATEWAY="$(prompt 'Gateway' "${GATEWAY:-}")"
  fi
  VLAN_TAG="$(prompt 'VLAN tag (blank = none)' "$VLAN_TAG")"
}

interactive_menu() {
  while true; do
    printf '\n\033[1m%s Proxmox Helper\033[0m\n' "$PRODUCT"
    printf '  1) Default Installation\n'
    printf '  2) Advanced Installation\n'
    printf '  3) User Defaults\n'
    printf '  4) Settings / current values\n'
    printf '  0) Exit\n\n'
    read -r -p 'Select: ' choice
    case "$choice" in
      1) return 0 ;;
      2) advanced_installation; return 0 ;;
      3|4) show_defaults ;;
      0) exit 0 ;;
      *) warn "Unknown selection: $choice" ;;
    esac
  done
}

preflight() {
  [[ "$(id -u)" -eq 0 ]] || die "Run this helper as root on the Proxmox VE host."
  need_cmd pveversion
  need_cmd pveam
  need_cmd pvesm
  need_cmd pvesh
  need_cmd pct
  pveversion >/dev/null 2>&1 || die "This does not appear to be a Proxmox VE host."

  ROOTFS_STORAGE="${ROOTFS_STORAGE:-$(find_storage rootdir)}"
  TEMPLATE_STORAGE="${TEMPLATE_STORAGE:-$(find_storage vztmpl)}"
  [[ -n "$ROOTFS_STORAGE" ]] || die "No active Proxmox storage with 'rootdir' content found."
  [[ -n "$TEMPLATE_STORAGE" ]] || die "No active Proxmox storage with 'vztmpl' content found."
  ip link show "$BRIDGE" >/dev/null 2>&1 || die "Bridge not found: $BRIDGE"
}

resolve_identity() {
  CTID="${CTID:-$(next_ctid)}"
  HOSTNAME="${HOSTNAME:-webowie-nodeos-${CTID}}"
  [[ "$CTID" =~ ^[0-9]+$ ]] || die "CTID must be numeric."
  pct status "$CTID" >/dev/null 2>&1 && die "Container ID $CTID already exists."
  validate_uint CORES "$CORES"
  validate_uint MEMORY "$MEMORY"
  validate_uint SWAP "$SWAP"
  validate_uint DISK "$DISK"
}

resolve_template() {
  log "Refreshing Proxmox appliance catalog"
  pveam update >/dev/null

  TEMPLATE="$(pveam available --section system | awk -v needle="alpine-${ALPINE_VERSION}-default" '$2 ~ needle {print $2; exit}')"
  [[ -n "$TEMPLATE" ]] || die "No Alpine ${ALPINE_VERSION} LXC template found in pveam catalog."
  TEMPLATE_REF="${TEMPLATE_STORAGE}:vztmpl/${TEMPLATE}"

  if ! pveam list "$TEMPLATE_STORAGE" 2>/dev/null | awk '{print $1}' | grep -Fqx "$TEMPLATE_REF"; then
    log "Downloading ${TEMPLATE} to ${TEMPLATE_STORAGE}"
    pveam download "$TEMPLATE_STORAGE" "$TEMPLATE"
  else
    log "Using cached template ${TEMPLATE_REF}"
  fi
}

create_container() {
  local net0
  net0="name=eth0,bridge=${BRIDGE},ip=${IP_CONFIG},type=veth"
  [[ -n "$GATEWAY" && "$IP_CONFIG" != "dhcp" ]] && net0+=",gw=${GATEWAY}"
  [[ -n "$VLAN_TAG" ]] && net0+=",tag=${VLAN_TAG}"

  log "Creating unprivileged Alpine ${ALPINE_VERSION} LXC ${CTID}"
  pct create "$CTID" "$TEMPLATE_REF" \
    --arch amd64 \
    --ostype alpine \
    --hostname "$HOSTNAME" \
    --cores "$CORES" \
    --memory "$MEMORY" \
    --swap "$SWAP" \
    --rootfs "${ROOTFS_STORAGE}:${DISK}" \
    --net0 "$net0" \
    --unprivileged 1 \
    --features nesting=1,keyctl=1 \
    --onboot "$ONBOOT"

  pct start "$CTID"
}

wait_for_network() {
  log "Waiting for network inside CT ${CTID}"
  local i
  for i in $(seq 1 45); do
    if pct exec "$CTID" -- sh -c 'ip route 2>/dev/null | grep -q "^default"' >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  die "Container started but did not obtain a default route. Container ${CTID} was left intact for diagnostics."
}

install_nodeos() {
  log "Installing production ${PRODUCT}"
  pct exec "$CTID" -- sh -c "apk add --no-cache ca-certificates curl >/dev/null && update-ca-certificates >/dev/null 2>&1 || true; curl -fsSL --retry 3 '$INSTALLER_URL' -o /root/install-webowie-nodeos.sh; chmod 0755 /root/install-webowie-nodeos.sh; /bin/sh /root/install-webowie-nodeos.sh"
}

healthcheck() {
  log "Running nodeOS health check"
  local i
  for i in $(seq 1 30); do
    if pct exec "$CTID" -- sh -c 'curl -fsS http://127.0.0.1:8080/ >/dev/null' >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  pct exec "$CTID" -- rc-service webowie-nodeos status || true
  die "nodeOS did not become ready on 127.0.0.1:8080. Container ${CTID} was left intact."
}

show_result() {
  local ipaddr
  ipaddr="$(pct exec "$CTID" -- sh -c "ip -4 -o addr show dev eth0 scope global | awk '{split(\$4,a,\"/\"); print a[1]; exit}'" 2>/dev/null || true)"
  cat <<EOF_RESULT

============================================================
 ${PRODUCT} installation complete
============================================================
 CTID:       ${CTID}
 Hostname:   ${HOSTNAME}
 Address:    http://${ipaddr:-CT-IP}:8080/
 Container:  unprivileged
 Alpine:     ${ALPINE_VERSION}

 Proxmox:    pct status ${CTID}
 Console:    pct enter ${CTID}
 nodeOS:     pct exec ${CTID} -- rc-service webowie-nodeos status
============================================================
EOF_RESULT
}

main() {
  if [[ "$WEBOWIE_MODE" != "generated" && "$WEBOWIE_MODE" != "unattended" ]]; then
    interactive_menu
  fi
  preflight
  resolve_identity
  show_defaults
  resolve_template
  create_container
  wait_for_network
  install_nodeos
  healthcheck
  show_result
}

main "$@"
