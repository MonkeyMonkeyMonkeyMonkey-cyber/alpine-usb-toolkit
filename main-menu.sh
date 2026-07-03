#!/bin/bash
# Alpine Data Transfer & ClamAV Tool - Complete Main Menu
# Full implementation with all features

set -e

# Configuration
LOG_DIR="/var/log/data-tools"
SCAN_LOG="$LOG_DIR/clamav-scan.log"
COPY_LOG="$LOG_DIR/copy-transfers.log"
HEALTH_LOG="$LOG_DIR/drive-health.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

mkdir -p "$LOG_DIR"

log_info() { echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$LOG_DIR/menu.log"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_DIR/menu.log"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_DIR/menu.log"; }
log_action() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_DIR/menu.log"; }

show_spinner() {
    local pid=$1 label=$2
    local spinner=( '⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏' )
    local i=0
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r${CYAN}%s${NC} ${MAGENTA}%s${NC}" "$label" "${spinner[$((i % 10))]}"
        ((i++))
        sleep 0.1
    done
    printf "\r${GREEN}✓${NC} %s\n" "$label"
}

show_banner() {
    clear
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════════════════╗"
    echo "║     Alpine Data Transfer & ClamAV Scanner          ║"
    echo "║      (Offline USB Data Management Tool v2.0)       ║"
    echo "╚════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

main_menu() {
    while true; do
        show_banner
        echo ""
        echo -e "${CYAN}=== MAIN MENU ===${NC}"
        echo ""
        echo "  1) Copy/Transfer Data"
        echo "  2) Scan for Viruses (ClamAV)"
        echo "  3) Verify Data Integrity"
        echo "  4) USB Drive Management"
        echo "  5) View Logs"
        echo "  6) Settings"
        echo "  7) Exit"
        echo ""
        read -p "Select option [1-7]: " choice
        
        case "$choice" in
            1) copy_menu ;;
            2) scan_menu ;;
            3) verify_menu ;;
            4) system_menu ;;
            5) logs_menu ;;
            6) settings_menu ;;
            7) log_action "Exit"; echo "Goodbye!"; exit 0 ;;
            *) log_error "Invalid option" ;;
        esac
    done
}

copy_menu() {
    while true; do
        show_banner
        echo -e "${CYAN}=== DATA TRANSFER ===${NC}"
        echo ""
        echo "  1) List USB drives"
        echo "  2) Copy files"
        echo "  3) Rsync sync"
        echo "  4) Create tar archive"
        echo "  5) Back"
        echo ""
        read -p "Select [1-5]: " choice
        case "$choice" in
            1) list_drives ;; 2) copy_files ;; 3) rsync_files ;; 4) create_archive ;; 5) break ;; *) log_error "Invalid" ;;
        esac
        read -p "Press Enter..."
    done
}

scan_menu() {
    while true; do
        show_banner
        echo -e "${CYAN}=== VIRUS SCANNING ===${NC}"
        echo ""
        echo "  1) Quick scan"
        echo "  2) Full scan"
        echo "  3) Scan path"
        echo "  4) View report"
        echo "  5) Back"
        echo ""
        read -p "Select [1-5]: " choice
        case "$choice" in
            1) quick_scan ;; 2) full_scan ;; 3) scan_path ;; 4) view_scan_report ;; 5) break ;; *) log_error "Invalid" ;;
        esac
        read -p "Press Enter..."
    done
}

verify_menu() {
    while true; do
        show_banner
        echo -e "${CYAN}=== DATA VERIFICATION ===${NC}"
        echo ""
        echo "  1) Calculate SHA256"
        echo "  2) Verify checksum"
        echo "  3) Compare directories"
        echo "  4) Back"
        echo ""
        read -p "Select [1-4]: " choice
        case "$choice" in
            1) calculate_checksum ;; 2) verify_checksum ;; 3) compare_dirs ;; 4) break ;; *) log_error "Invalid" ;;
        esac
        read -p "Press Enter..."
    done
}

system_menu() {
    while true; do
        show_banner
        echo -e "${CYAN}=== USB MANAGEMENT ===${NC}"
        echo ""
        echo "  1) Mount drive"
        echo "  2) Health check"
        echo "  3) Safe eject"
        echo "  4) List partitions"
        echo "  5) Disk usage"
        echo "  6) File manager"
        echo "  7) Back"
        echo ""
        read -p "Select [1-7]: " choice
        case "$choice" in
            1) mount_drive ;; 2) health_check_menu ;; 3) eject_menu ;; 4) list_partitions ;; 5) disk_usage ;; 6) file_manager ;; 7) break ;; *) log_error "Invalid" ;;
        esac
        read -p "Press Enter..."
    done
}

health_check_menu() {
    show_banner
    echo -e "${CYAN}=== USB Health Check ===${NC}"
    echo ""
    lsblk -d -o NAME,SIZE,TYPE
    echo ""
    read -p "Device (e.g., /dev/sdb1): " device
    read -p "Mount point (e.g., /mnt/usb): " mountpoint
    [ -z "$device" ] && return
    check_usb_health "$device" "$mountpoint"
}

eject_menu() {
    show_banner
    echo -e "${CYAN}=== Safe Eject ===${NC}"
    echo ""
    lsblk -d -o NAME,SIZE,TYPE,MOUNTPOINTS
    echo ""
    read -p "Device: " device
    read -p "Mount point: " mountpoint
    [ -z "$device" ] && return
    safely_eject_usb "$device" "$mountpoint"
}

logs_menu() {
    while true; do
        show_banner
        echo -e "${CYAN}=== LOGS ===${NC}"
        echo ""
        echo "  1) Menu activity"
        echo "  2) Copy transfers"
        echo "  3) Scan reports"
        echo "  4) Health logs"
        echo "  5) Export logs"
        echo "  6) Back"
        echo ""
        read -p "Select [1-6]: " choice
        case "$choice" in
            1) view_log "$LOG_DIR/menu.log" ;; 2) view_log "$COPY_LOG" ;; 3) view_log "$SCAN_LOG" ;; 4) view_log "$HEALTH_LOG" ;; 5) export_logs ;; 6) break ;; *) log_error "Invalid" ;;
        esac
        read -p "Press Enter..."
    done
}

settings_menu() {
    while true; do
        show_banner
        echo -e "${CYAN}=== SETTINGS ===${NC}"
        echo ""
        echo "  1) ClamAV info"
        echo "  2) System info"
        echo "  3) Log retention"
        echo "  4) Back"
        echo ""
        read -p "Select [1-4]: " choice
        case "$choice" in
            1) show_clamav_info ;; 2) system_info ;; 3) set_log_retention ;; 4) break ;; *) log_error "Invalid" ;;
        esac
        read -p "Press Enter..."
    done
}

list_drives() {
    show_banner
    echo -e "${CYAN}=== Connected USB Drives ===${NC}"
    echo ""
    lsblk -d -o NAME,SIZE,TYPE,VENDOR,MODEL
    log_action "Listed drives"
}

copy_files() {
    show_banner
    echo -e "${CYAN}=== Copy Files ===${NC}"
    echo ""
    read -p "Source: " src
    read -p "Destination: " dst
    [ ! -e "$src" ] && { log_error "Source not found"; return; }
    mkdir -p "$dst"
    cp -rv "$src" "$dst" 2>&1 | tee -a "$COPY_LOG" &
    show_spinner $! "Copying"
    log_action "Copied: $src -> $dst"
    echo -e "${GREEN}Complete!${NC}"
}

rsync_files() {
    show_banner
    echo -e "${CYAN}=== Rsync Sync ===${NC}"
    echo ""
    read -p "Source: " src
    read -p "Destination: " dst
    [ ! -e "$src" ] && { log_error "Source not found"; return; }
    mkdir -p "$dst"
    rsync -av --progress "$src" "$dst" 2>&1 | tee -a "$COPY_LOG"
    log_action "Synced: $src -> $dst"
    echo -e "${GREEN}Complete!${NC}"
}

create_archive() {
    show_banner
    echo -e "${CYAN}=== Create Archive ===${NC}"
    echo ""
    read -p "Source: " src
    read -p "Name (no .tar.gz): " name
    [ ! -e "$src" ] && { log_error "Source not found"; return; }
    tar -czf "${name}.tar.gz" -C "$(dirname "$src")" "$(basename "$src")" 2>&1 | tee -a "$COPY_LOG" &
    show_spinner $! "Creating"
    log_action "Created: ${name}.tar.gz"
    echo -e "${GREEN}Complete!${NC}"
}

quick_scan() {
    show_banner
    echo -e "${CYAN}=== Quick Scan ===${NC}"
    echo ""
    clamscan -r /mnt /media 2>&1 | tee -a "$SCAN_LOG" &
    show_spinner $! "Scanning"
    log_action "Quick scan done"
}

full_scan() {
    show_banner
    echo -e "${CYAN}=== Full Scan ===${NC}"
    echo ""
    read -p "Path (default /): " path
    path=${path:=/}
    clamscan -r "$path" 2>&1 | tee -a "$SCAN_LOG" &
    show_spinner $! "Full scan"
    log_action "Full scan done"
}

scan_path() {
    show_banner
    echo -e "${CYAN}=== Scan Path ===${NC}"
    echo ""
    read -p "Path: " path
    [ ! -e "$path" ] && { log_error "Invalid path"; return; }
    clamscan -r "$path" 2>&1 | tee -a "$SCAN_LOG" &
    show_spinner $! "Scanning"
    log_action "Scanned: $path"
}

view_scan_report() {
    show_banner
    echo -e "${CYAN}=== Scan Report ===${NC}"
    echo ""
    [ -f "$SCAN_LOG" ] && tail -100 "$SCAN_LOG" | less || log_error "No reports"
}

calculate_checksum() {
    show_banner
    echo -e "${CYAN}=== Calculate SHA256 ===${NC}"
    echo ""
    read -p "File: " file
    [ ! -f "$file" ] && { log_error "Not found"; return; }
    echo ""
    sha256sum "$file" | tee -a "$LOG_DIR/checksums.log"
    log_action "Checksum: $file"
}

verify_checksum() {
    show_banner
    echo -e "${CYAN}=== Verify Checksum ===${NC}"
    echo ""
    read -p "Checksum file: " chkfile
    read -p "Directory: " dir
    [ ! -f "$chkfile" ] || [ ! -d "$dir" ] && { log_error "Invalid"; return; }
    cd "$dir" && sha256sum -c "$chkfile" 2>&1 | tee -a "$LOG_DIR/verification.log"
    log_action "Verified checksums"
}

compare_dirs() {
    show_banner
    echo -e "${CYAN}=== Compare Dirs ===${NC}"
    echo ""
    read -p "Dir 1: " dir1
    read -p "Dir 2: " dir2
    [ ! -d "$dir1" ] || [ ! -d "$dir2" ] && { log_error "Invalid"; return; }
    diff -r "$dir1" "$dir2" 2>&1 | tee -a "$LOG_DIR/comparison.log" | head -50
    log_action "Compared dirs"
}

mount_drive() {
    show_banner
    echo -e "${CYAN}=== Mount Drive ===${NC}"
    echo ""
    lsblk -d -o NAME,SIZE
    echo ""
    read -p "Device (e.g., sdb1): " device
    read -p "Mount point (default /mnt/usb): " mountpoint
    mountpoint=${mountpoint:=/mnt/usb}
    mkdir -p "$mountpoint"
    mount "/dev/$device" "$mountpoint" 2>&1 && log_action "Mounted: $device" || log_error "Mount failed"
}

check_usb_health() {
    local device=$1 mountpoint=$2
    show_banner
    echo -e "${CYAN}=== USB Health ===${NC}"
    echo ""
    echo "Device: $device"
    echo "Mount: $mountpoint"
    echo ""
    mountpoint -q "$mountpoint" || { log_warn "Not mounted"; return 1; }
    echo -e "${YELLOW}Checking...${NC}"
    echo ""
    {
        echo "=== Health Check ==="
        echo "Date: $(date)"
        echo "--- System Logs ---"
        dmesg | grep -i -E "(sdb|usb|error)" | tail -20 || echo "No errors"
        echo ""
        echo "--- Filesystem ---"
        fsck.ext4 -n "$device" 2>&1 | tail -10 || echo "N/A"
        echo ""
        echo "--- Usage ---"
        df -h "$mountpoint"
    } | tee -a "$HEALTH_LOG"
    echo ""
    echo -e "${GREEN}Done!${NC}"
}

safely_eject_usb() {
    local device=$1 mountpoint=$2
    show_banner
    echo -e "${CYAN}=== Safe Eject ===${NC}"
    echo ""
    echo -e "${YELLOW}Syncing...${NC}"
    sync
    echo -e "${YELLOW}Unmounting...${NC}"
    if umount "$mountpoint" 2>/dev/null; then
        echo -e "${GREEN}✓ Unmounted${NC}"
    else
        log_error "Unmount failed"
        return
    fi
    echo ""
    echo -e "${GREEN}Safe to remove!${NC}"
    log_action "Ejected: $device"
}

list_partitions() {
    show_banner
    echo -e "${CYAN}=== Partitions ===${NC}"
    echo ""
    lsblk -h -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS
    log_action "Listed partitions"
}

disk_usage() {
    show_banner
    echo -e "${CYAN}=== Disk Usage ===${NC}"
    echo ""
    df -h | grep -E "(Filesystem|/dev|/mnt)"
    log_action "Checked usage"
}

file_manager() {
    show_banner
    echo -e "${CYAN}=== File Manager ===${NC}"
    echo ""
    read -p "Path (default /): " path
    path=${path:=/}
    while true; do
        echo -e "${MAGENTA}Current: $path${NC}"
        ls -lhA "$path" | head -15
        echo ""
        read -p "[l]s, [c]d, [b]ack: " choice
        case "$choice" in
            l) ls -lhA "$path" ;;
            c) read -p "Dir: " newpath; [ -d "$newpath" ] && path="$newpath" ;;
            b) break ;;
        esac
    done
}

view_log() {
    show_banner
    [ -f "$1" ] && less "$1" || log_error "Not found"
}

export_logs() {
    show_banner
    echo -e "${CYAN}=== Export Logs ===${NC}"
    echo ""
    read -p "Destination: " dest
    mkdir -p "$dest"
    cp -r "$LOG_DIR"/* "$dest/" 2>&1
    log_action "Exported to: $dest"
    echo -e "${GREEN}Done!${NC}"
}

show_clamav_info() {
    show_banner
    echo -e "${CYAN}=== ClamAV Info ===${NC}"
    echo ""
    clamscan --version
    echo ""
    echo "Databases:"
    ls -lh /var/lib/clamav/*.cvd 2>/dev/null || echo "None found"
    log_action "Viewed ClamAV info"
}

system_info() {
    show_banner
    echo -e "${CYAN}=== System Info ===${NC}"
    echo ""
    echo "Hostname: $(hostname)"
    echo "Uptime: $(uptime)"
    echo "CPU: $(nproc) cores"
    echo "Memory:"
    free -h
    echo "Kernel: $(uname -r)"
    log_action "Viewed system info"
}

set_log_retention() {
    show_banner
    echo -e "${CYAN}=== Log Retention ===${NC}"
    echo ""
    read -p "Days (default 30): " days
    days=${days:=30}
    echo "$days" > "$LOG_DIR/.retention"
    log_action "Retention: $days days"
    echo -e "${GREEN}Updated!${NC}"
}

main_menu
