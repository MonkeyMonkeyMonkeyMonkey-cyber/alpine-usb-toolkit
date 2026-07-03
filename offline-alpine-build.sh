#!/bin/bash
# offline-alpine-build.sh
# Complete Alpine Linux custom ISO build script with ClamAV, menu system, and bandwidth throttling
# For offline USB data transfer and scanning operations

set -e

# Configuration
OUTDIR="./iso-output"
ROOTFS="./alpine-root"
ISOTMP="./iso-build"
ISO_MOUNT="/mnt/iso"
PACKAGES="clamav rsync tar diffutils coreutils util-linux openrc dialog bash less nano pv e2fsprogs dosfstools badblocks smartmontools lsof"
CLAMAV_DB_DIR="./clamav-dbs"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prereqs() {
    log_info "Checking prerequisites..."
    
    if [ ! -d "$CLAMAV_DB_DIR" ] || [ -z "$(ls -A $CLAMAV_DB_DIR/*.cvd 2>/dev/null)" ]; then
        log_error "ClamAV database files not found in $CLAMAV_DB_DIR"
        log_info "Expected files: main.cvd, daily.cvd, bytecode.cvd"
        exit 1
    fi
    
    if [ ! -d "$ISO_MOUNT" ] || [ -z "$(ls -A $ISO_MOUNT 2>/dev/null)" ]; then
        log_error "Alpine Extended ISO not mounted at $ISO_MOUNT"
        exit 1
    fi
    
    log_info "✓ ClamAV databases found"
    log_info "✓ Alpine ISO mounted"
}

extract_rootfs() {
    log_info "Extracting Alpine minirootfs..."
    
    rm -rf "$ROOTFS"
    mkdir -p "$ROOTFS"
    
    MINIROOTFS=$(ls $ISO_MOUNT/alpine-minirootfs-*.tar.gz 2>/dev/null | head -1)
    if [ -z "$MINIROOTFS" ]; then
        log_error "alpine-minirootfs not found on ISO"
        exit 1
    fi
    
    tar -xzf "$MINIROOTFS" -C "$ROOTFS"
    log_info "✓ Rootfs extracted"
}

configure_repos() {
    log_info "Configuring APK repositories..."
    
    mkdir -p "$ROOTFS/etc/apk"
    cat > "$ROOTFS/etc/apk/repositories" << EOF
$ISO_MOUNT/apks/x86_64
EOF
    
    log_info "✓ Repositories configured"
}

bind_mounts() {
    log_info "Setting up bind mounts..."
    
    mount --bind /dev "$ROOTFS/dev" || true
    mount --bind /sys "$ROOTFS/sys" || true
    mount --bind /proc "$ROOTFS/proc" || true
    mount --bind "$ISO_MOUNT" "$ROOTFS/mnt/iso" || true
    
    log_info "✓ Bind mounts ready"
}

unbind_mounts() {
    log_info "Cleaning up bind mounts..."
    
    umount "$ROOTFS/dev" 2>/dev/null || true
    umount "$ROOTFS/sys" 2>/dev/null || true
    umount "$ROOTFS/proc" 2>/dev/null || true
    umount "$ROOTFS/mnt/iso" 2>/dev/null || true
    
    log_info "✓ Bind mounts cleaned"
}

install_packages() {
    log_info "Installing packages: $PACKAGES"
    
    chroot "$ROOTFS" apk add --no-cache $PACKAGES
    
    log_info "✓ Packages installed"
}

install_clamav_dbs() {
    log_info "Installing ClamAV virus databases..."
    
    mkdir -p "$ROOTFS/var/lib/clamav"
    
    cp "$CLAMAV_DB_DIR"/*.cvd "$ROOTFS/var/lib/clamav/"
    chroot "$ROOTFS" chown clamav:clamav /var/lib/clamav/*.cvd 2>/dev/null || true
    
    log_info "✓ ClamAV databases installed:"
    ls -lh "$ROOTFS/var/lib/clamav"/*.cvd
}

create_menu_system() {
    log_info "Creating interactive menu system with enhanced features..."
    
    mkdir -p "$ROOTFS/opt/menu"
    
    # Copy main menu script from repo
    if [ -f "./main-menu.sh" ]; then
        cp ./main-menu.sh "$ROOTFS/opt/menu/main-menu.sh"
        chmod +x "$ROOTFS/opt/menu/main-menu.sh"
        log_info "✓ Menu system installed"
    else
        log_warn "main-menu.sh not found in current directory"
        log_info "Creating minimal menu stub..."
        cat > "$ROOTFS/opt/menu/main-menu.sh" << 'MENU_STUB'
#!/bin/bash
echo "Main menu not found. Please ensure main-menu.sh is in the repository."
echo "For now, you have access to: cp, rsync, tar, clamav, and other tools."
bash
MENU_STUB
        chmod +x "$ROOTFS/opt/menu/main-menu.sh"
    fi
}

create_boot_scripts() {
    log_info "Creating boot scripts..."
    
    cat >> "$ROOTFS/root/.profile" << 'PROFILE_EOF'

# Auto-launch menu on login
if [ -z "$MENU_LAUNCHED" ]; then
    export MENU_LAUNCHED=1
    exec /opt/menu/main-menu.sh
fi
PROFILE_EOF

    mkdir -p "$ROOTFS/etc/local.d"
    
    cat > "$ROOTFS/etc/local.d/usb-mount.start" << 'STARTUP_EOF'
#!/bin/sh
echo "[$(date)] Starting USB auto-mount..." >> /var/log/data-tools/boot.log
mkdir -p /mnt/usb /var/log/data-tools
for device in /dev/sd[a-z][0-9] /dev/hd[a-z][0-9]; do
    if [ -b "$device" ]; then
        if mount "$device" /mnt/usb 2>/dev/null; then
            echo "[$(date)] Mounted $device at /mnt/usb" >> /var/log/data-tools/boot.log
            break
        fi
    fi
done
echo "[$(date)] USB mount check complete" >> /var/log/data-tools/boot.log
STARTUP_EOF
    
    chmod +x "$ROOTFS/etc/local.d/usb-mount.start"
    chroot "$ROOTFS" rc-update add local >/dev/null 2>&1 || true
    
    log_info "✓ Boot scripts created"
}

prepare_iso_dir() {
    log_info "Preparing ISO directory structure..."
    rm -rf "$ISOTMP"
    mkdir -p "$ISOTMP/boot/syslinux"
    log_info "✓ ISO directory ready"
}

copy_kernel() {
    log_info "Copying kernel and initramfs..."
    cp "$ROOTFS/boot/vmlinuz-virt" "$ISOTMP/boot/"
    cp "$ROOTFS/boot/initramfs-virt" "$ISOTMP/boot/"
    log_info "✓ Kernel and initramfs copied"
}

create_bootloader_config() {
    log_info "Creating bootloader configuration..."
    cat > "$ISOTMP/boot/syslinux/isolinux.cfg" << 'EOF'
UI vesamenu.c32
PROMPT 0
TIMEOUT 50
DEFAULT linux

LABEL linux
    MENU LABEL Alpine Linux (Data Transfer & ClamAV)
    KERNEL ../vmlinuz-virt
    APPEND initrd=../initramfs-virt alpine_dev=ata root=/dev/ram0 modloop=alpine.squashfs
    TEXT HELP
    Boot Alpine Linux with ClamAV pre-loaded
    Interactive menu-driven interface
    ENDTEXT
EOF
    log_info "✓ Bootloader config created"
}

create_squashfs() {
    log_info "Creating squashfs image (this may take a few minutes)..."
    mksquashfs "$ROOTFS" "$ISOTMP/alpine.squashfs" -comp xz -processors 4
    log_info "✓ Squashfs created:"
    ls -lh "$ISOTMP/alpine.squashfs"
}

create_iso() {
    log_info "Creating ISO image..."
    rm -rf "$OUTDIR"
    mkdir -p "$OUTDIR"
    
    cp "$ISO_MOUNT/syslinux/isohdpfx.bin" "$ISOTMP/boot/syslinux/" 2>/dev/null || log_warn "isohdpfx.bin not found"
    cp "$ISO_MOUNT/syslinux/vesamenu.c32" "$ISOTMP/boot/syslinux/" 2>/dev/null || log_warn "vesamenu.c32 not found"
    
    xorriso -as mkisofs \
        -o "$OUTDIR/alpine-data-clamav.iso" \
        -isohybrid-mbr "$ISOTMP/boot/syslinux/isohdpfx.bin" \
        -c boot.cat \
        -b boot/syslinux/isolinux.bin \
        -no-emul-boot \
        -boot-load-size 4 \
        -boot-info-table \
        "$ISOTMP"
    
    log_info "✓ ISO created successfully:"
    ls -lh "$OUTDIR/alpine-data-clamav.iso"
}

cleanup() {
    log_info "Cleaning up..."
    unbind_mounts
    rm -rf "$ISOTMP" "$ROOTFS"
    log_info "✓ Cleanup complete"
}

main() {
    log_info "=== Alpine Custom ISO Build (Offline) ==="
    log_info ""
    
    check_prereqs
    extract_rootfs
    configure_repos
    bind_mounts
    install_packages
    install_clamav_dbs
    create_menu_system
    create_boot_scripts
    unbind_mounts
    prepare_iso_dir
    copy_kernel
    create_bootloader_config
    create_squashfs
    create_iso
    cleanup
    
    log_info ""
    log_info "=== Build Complete ==="
    log_info "Your ISO is ready: $OUTDIR/alpine-data-clamav.iso"
    log_info ""
    log_info "To write to USB:"
    log_info "  sudo dd if=$OUTDIR/alpine-data-clamav.iso of=/dev/sdX bs=4M status=progress"
    log_info "  sudo sync"
}

trap cleanup EXIT
main
