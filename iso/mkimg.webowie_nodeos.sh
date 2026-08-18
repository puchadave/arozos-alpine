profile_webowie_nodeos() {
    profile_standard

    title="webOwie_nodeOS Live"
    desc="Alpine Linux 3.24 live installer and recovery environment for webOwie_nodeOS"
    profile_abbrev="webowie"
    image_name="webOwie_nodeOS-live"
    hostname="webowie-nodeos-live"
    arch="x86_64"
    output_format="iso"
    image_ext="iso"

    # Keep the standard Alpine LTS kernel and complete modloop. Proxmox/QEMU
    # network drivers such as virtio_net therefore remain available.
    kernel_flavors="lts"
    kernel_cmdline="${kernel_cmdline:-} console=tty0 console=ttyS0,115200"
    syslinux_serial="0 115200"

    # Packages listed here are copied onto the ISO. The matching apkovl world
    # file installs the tools into the running live root at boot.
    apks="$apks \
        alpine-conf \
        busybox-extras \
        ca-certificates \
        curl \
        wget \
        git \
        tar \
        net-tools \
        iproute2 \
        iputils \
        pciutils \
        ethtool \
        openssh"

    apkovl="scripts/genapkovl-webowie-nodeos.sh"
}
