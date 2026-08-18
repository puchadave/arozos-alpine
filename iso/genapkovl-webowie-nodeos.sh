#!/bin/sh -e

HOSTNAME="${1:-webowie-nodeos-live}"

cleanup() {
    rm -rf "$tmp"
}

makefile() {
    OWNER="$1"
    PERMS="$2"
    FILENAME="$3"
    cat > "$FILENAME"
    chown "$OWNER" "$FILENAME"
    chmod "$PERMS" "$FILENAME"
}

rc_add() {
    mkdir -p "$tmp/etc/runlevels/$2"
    ln -sf "/etc/init.d/$1" "$tmp/etc/runlevels/$2/$1"
}

tmp="$(mktemp -d)"
trap cleanup EXIT

mkdir -p "$tmp/etc"
makefile root:root 0644 "$tmp/etc/hostname" <<EOF_HOST
$HOSTNAME
EOF_HOST

# Only configure loopback statically. The boot service below discovers the
# actual Proxmox/QEMU interface name and adds DHCP configuration dynamically.
mkdir -p "$tmp/etc/network"
makefile root:root 0644 "$tmp/etc/network/interfaces" <<'EOF_NET'
auto lo
iface lo inet loopback
EOF_NET

mkdir -p "$tmp/etc/apk"
makefile root:root 0644 "$tmp/etc/apk/world" <<'EOF_WORLD'
alpine-base
alpine-conf
busybox-extras
ca-certificates
curl
wget
git
tar
net-tools
iproute2
iputils
pciutils
ethtool
openssh
EOF_WORLD

# Load common virtual NIC drivers explicitly and dynamically add every
# discovered non-loopback interface to ifupdown before networking starts.
mkdir -p "$tmp/etc/init.d"
makefile root:root 0755 "$tmp/etc/init.d/webowie-net-prep" <<'EOF_SERVICE'
#!/sbin/openrc-run

description="Prepare Proxmox/QEMU networking for webOwie_nodeOS Live"

depend() {
    need modloop
    before networking
}

start() {
    ebegin "Preparing virtual network interfaces"

    modprobe virtio_pci 2>/dev/null || true
    modprobe virtio_net 2>/dev/null || true
    modprobe e1000 2>/dev/null || true
    modprobe e1000e 2>/dev/null || true
    modprobe vmxnet3 2>/dev/null || true

    count=0
    while [ "$count" -lt 15 ]; do
        found=0
        for nicpath in /sys/class/net/*; do
            [ -e "$nicpath" ] || continue
            nic="${nicpath##*/}"
            [ "$nic" = "lo" ] && continue
            found=1
            break
        done
        [ "$found" -eq 1 ] && break
        sleep 1
        count=$((count + 1))
    done

    configured=0
    for nicpath in /sys/class/net/*; do
        [ -e "$nicpath" ] || continue
        nic="${nicpath##*/}"
        [ "$nic" = "lo" ] && continue

        ip link set "$nic" up 2>/dev/null || true
        einfo "Detected NIC: $nic"

        if ! grep -Eq "^[[:space:]]*iface[[:space:]]+$nic[[:space:]]" /etc/network/interfaces; then
            {
                echo
                echo "auto $nic"
                echo "iface $nic inet dhcp"
            } >> /etc/network/interfaces
        fi
        configured=$((configured + 1))
    done

    if [ "$configured" -eq 0 ]; then
        eend 1 "No non-loopback network interface detected"
        return 1
    fi

    eend 0
}
EOF_SERVICE

makefile root:root 0644 "$tmp/etc/motd" <<'EOF_MOTD'
webOwie_nodeOS Live - Alpine Linux 3.24

Network diagnostics:
  ip addr
  ifconfig
  ip route
  netstat -rn

Install Alpine to disk with:
  setup-alpine
EOF_MOTD

# Alpine live boot services, based on the official genapkovl-dhcp profile.
rc_add devfs sysinit
rc_add dmesg sysinit
rc_add mdev sysinit
rc_add hwdrivers sysinit
rc_add modloop sysinit

rc_add hwclock boot
rc_add modules boot
rc_add sysctl boot
rc_add hostname boot
rc_add bootmisc boot
rc_add syslog boot
rc_add webowie-net-prep boot
rc_add networking boot

rc_add sshd default

rc_add mount-ro shutdown
rc_add killprocs shutdown
rc_add savecache shutdown

tar -c -C "$tmp" etc | gzip -9n > "$HOSTNAME.apkovl.tar.gz"
