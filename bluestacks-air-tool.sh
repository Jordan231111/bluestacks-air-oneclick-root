#!/bin/bash
set -e

# Globals
BLUESTACKS_APP_PATH="/Applications/BlueStacks.app"
# ADB_PORT is not used, but let's keep it here for future use
# ADB_PORT=5555
ARCH="arm64-v8a"
BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# --- Helper Functions ---

function print_usage() {
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  root      - Patch BlueStacks to include Magisk."
    echo "  unroot    - Restore original BlueStacks installation."
    echo "  help      - Show this help message."
    echo ""
    echo "Root Options:"
    echo "  -o, --output <path>    - Path to save the patched initrd.img. (Disables in-place modification)"
    echo "  -b, --backup-dir <dir> - Directory to store the original initrd.img backup."
    echo "  -a, --apk <path>       - Path to the Magisk APK file (e.g., magisk.apk)."
    echo ""
    echo "Unroot Options:"
    echo "  -b, --backup-dir <dir> - Directory where the original initrd.img backup is stored."
}

function abspath() {
  if [[ "$1" == /* ]]; then
    echo "$1"
  else
    echo "$(pwd)/$1"
  fi
}

function check_bluestacks() {
    if [ ! -d "$BLUESTACKS_APP_PATH" ]; then
        echo "[!] BlueStacks not found at $BLUESTACKS_APP_PATH"
        exit 1
    fi
    local plist_file="$BLUESTACKS_APP_PATH/Contents/Info.plist"
    local bs_version
    bs_version=$(defaults read "$plist_file" CFBundleShortVersionString 2>/dev/null)
    echo "[*] Found BlueStacks Air version $bs_version"
}

# --- Rooting Logic ---

function do_root() {
    local initrd_output=""
    local backup_dir=""
    local magisk_apk_path=""
    local inplace=1

    # Parse root command options
    shift # remove 'root' from args
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -o|--output)
                initrd_output=$(abspath "$2")
                mkdir -p "$(dirname "$initrd_output")"
                inplace=0
                shift 2
                ;;
            -b|--backup-dir)
                backup_dir=$(abspath "$2")
                mkdir -p "$backup_dir"
                shift 2
                ;;
            -a|--apk)
                magisk_apk_path=$(abspath "$2")
                shift 2
                ;;
            *)
                echo "Unknown option: $1"
                print_usage
                exit 1
                ;;
        esac
    done

    # Check for Magisk APK
    if [ -z "$magisk_apk_path" ]; then
        # Attempt auto-download of the latest Kitsune Magisk APK
        echo "[*] Magisk APK not specified – attempting to download latest Kitsune Magisk…"

        if ! command -v curl >/dev/null 2>&1; then
            echo "[!] curl is required to auto-download the Magisk APK. Please install curl or provide the APK manually (-a)." >&2
            exit 1
        fi

        # Fetch latest release metadata from GitHub API and parse for app-release.apk browser_download_url
        LATEST_API="https://api.github.com/repos/1q23lyc45/KitsuneMagisk/releases/latest"
        DL_URL=$(curl -fsSL "$LATEST_API" | grep -E 'browser_download_url.*app-release\.apk"' | head -n 1 | cut -d '"' -f 4)

        if [[ -z "$DL_URL" ]]; then
            echo "[!] Unable to determine download URL for Kitsune Magisk APK. Provide it manually with -a." >&2
            exit 1
        fi

        magisk_apk_path="$BASE_DIR/KitsuneMagisk-latest.apk"
        echo "[*] Downloading Magisk from: $DL_URL"
        curl -fL "$DL_URL" -o "$magisk_apk_path" || { echo "[!] Failed to download Magisk APK." >&2; exit 1; }
        echo "[*] Magisk downloaded to $magisk_apk_path"
    fi

    if [ ! -f "$magisk_apk_path" ]; then
        echo "[!] Magisk APK not found at: $magisk_apk_path"
        exit 1
    fi

    echo ""
    echo '=================================================='
    echo '**        BlueStacks Air Magisk Installer       **'
    echo '=================================================='
    echo ""

    if [ $inplace -eq 1 ]; then
        pkill -x BlueStacks || true # Don't fail if not running
        echo 'Checklist:'
        echo '* You have started BlueStacks for the first time.'
        echo '* BlueStacks is closed before proceeding.'
        echo ''
    fi

    read -p "Continue? (y/n): " confirm && [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || exit 0
    echo ""

    local initrd_path="$BLUESTACKS_APP_PATH/Contents/img/initrd_hvf.img"
    local initrd_backup_path
    if [ -n "$backup_dir" ]; then
        initrd_backup_path="$backup_dir/initrd_hvf.img"
    else
        initrd_backup_path="$initrd_path.bak"
    fi

    if [ -z "$initrd_output" ]; then
        initrd_output="$initrd_path"
    fi

    # Use a secure temporary directory
    local temp_dir
    temp_dir=$(mktemp -d)
    function cleanup() {
        echo "[*] Cleaning up temporary files..."
        rm -rf "$temp_dir"
    }
    trap cleanup EXIT

    local magisk_bin_dir="$temp_dir/magisk-bin"
    mkdir -p "$magisk_bin_dir"

    echo '[*] Preparing Magisk...'
    unzip -oq "$magisk_apk_path" -d "$temp_dir/magisk"

    local bin_names=("magisk64" "magiskinit" "magiskpolicy")
    for bin_name in "${bin_names[@]}"; do
        local src_so="$temp_dir/magisk/lib/$ARCH/lib$bin_name.so"
        if [ -f "$src_so" ]; then
            cp "$src_so" "$magisk_bin_dir/$bin_name"
        else
            echo "[!] Failed to find required binary: $bin_name in APK."
            exit 1
        fi
    done
    cp "$temp_dir/magisk/assets/stub.apk" "$magisk_bin_dir/stub.apk"

    echo "[*] Backing up initrd to $initrd_backup_path"
    if [ ! -f "$initrd_backup_path" ]; then
        cp "$initrd_path" "$initrd_backup_path"
    fi

    local build_dir="$temp_dir/build"
    mkdir -p "$build_dir"
    cd "$build_dir"

    echo '[*] Patching initrd...'
    mkdir initrd
    cd initrd

    # Some BlueStacks versions ship initrd_hvf.img compressed, others don't.
    # Test if the file is gzip by attempting to list (-t); fall back to cat on failure.
    if gzip -t "$initrd_backup_path" >/dev/null 2>&1; then
        gzip -dc "$initrd_backup_path" | cpio -id
    else
        cat "$initrd_backup_path" | cpio -id
    fi

    # Copy magisk files
    cp -r "$magisk_bin_dir" boot/magisk
    chmod 700 boot/magisk/*
    cp "$BASE_DIR/magisk.rc" boot/magisk.rc

    # Patch stage2.sh
    # Using a temp file for sed to be compatible with both GNU and BSD sed.
    sed -e 's/exec \/init//' boot/stage2.sh > boot/stage2.sh.tmp
    cat << EOF >> boot/stage2.sh.tmp
log_echo "Installing magisk.rc"
cat /boot/magisk.rc >> /init.bst.rc
die_if_error "Cannot install magisk.rc"

exec /init
EOF
    mv boot/stage2.sh.tmp boot/stage2.sh

    echo "[*] Repacking initrd to $initrd_output"
    find . | cpio -H newc -o | gzip > "$initrd_output"

    cd "$BASE_DIR"

    if [ $inplace -eq 1 ]; then
        echo '[*] Starting BlueStacks...'
        open -n "$BLUESTACKS_APP_PATH"

        echo '[*] Rooting process complete.'
        echo ""
        echo 'Next Steps:'
        echo "1. Install the Magisk APK ('$magisk_apk_path') in BlueStacks."
        echo "2. Open the Kitsune Mask app and follow the on-screen prompts for additional setup."
        echo "3. After reboot, your BlueStacks should be rooted."
    else
        echo '[*] Patched initrd created successfully.'
        echo ""
        echo 'Next Steps:'
        echo "1. Manually copy the patched initrd to the BlueStacks app directory:"
        echo "   sudo cp \"$initrd_output\" \"$initrd_path\""
        echo "2. Start BlueStacks."
        echo "3. Install the Magisk APK ('$magisk_apk_path') in BlueStacks."
        echo "4. Open the Kitsune Mask app and follow prompts for additional setup."
    fi
}

# --- Unrooting Logic ---

function do_unroot() {
    local backup_dir=""

    # Parse unroot command options
    shift # remove 'unroot' from args
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -b|--backup-dir)
                backup_dir=$(abspath "$2")
                shift 2
                ;;
            *)
                echo "Unknown option: $1"
                print_usage
                exit 1
                ;;
        esac
    done

    local initrd_path="$BLUESTACKS_APP_PATH/Contents/img/initrd_hvf.img"
    local initrd_backup_path
    if [ -n "$backup_dir" ]; then
        initrd_backup_path="$backup_dir/initrd_hvf.img"
    else
        initrd_backup_path="$initrd_path.bak"
    fi

    echo ""
    echo '=================================================='
    echo '**       BlueStacks Air Magisk Uninstaller      **'
    echo '=================================================='
    echo ""

    if [ ! -f "$initrd_backup_path" ]; then
        echo "[!] initrd backup not found at: $initrd_backup_path"
        echo "If your backup is in a different location, please specify it with -b/--backup-dir."
        exit 1
    fi

    read -p "This will restore the original initrd. Are you sure? (y/n): " confirm && [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || exit 0
    echo ""

    pkill -x BlueStacks || true # Don't fail if not running

    echo "[*] Restoring original initrd from $initrd_backup_path..."
    if [ "$(id -u)" -ne 0 ]; then
        echo "This script needs to copy a file into the /Applications directory."
        echo "Please enter your password to grant sudo permissions."
        sudo cp "$initrd_backup_path" "$initrd_path"
    else
        cp "$initrd_backup_path" "$initrd_path"
    fi

    echo "[*] Starting BlueStacks..."
    open -n "$BLUESTACKS_APP_PATH"
    echo '[*] Unrooting process complete.'
}

# --- Main Script ---

function main() {
    if [[ $# -eq 0 ]]; then
        print_usage
        exit 1
    fi

    check_bluestacks

    case "$1" in
        root)
            do_root "$@"
            ;;
        unroot)
            do_unroot "$@"
            ;;
        help)
            print_usage
            ;;
        *)
            echo "Invalid command: $1"
            print_usage
            exit 1
            ;;
    esac

    echo ""
    echo "[*] Done."
}

main "$@" 