#!/bin/bash
# ==============================================================================
#  Ionfetch - Installation & Setup Script
#  Usage:
#    curl -fsSL https://raw.githubusercontent.com/sirayu-pn/Ionfetch/main/install.sh | bash
#    or locally: ./install.sh [--user] [--uninstall]
# ==============================================================================

set -euo pipefail

# Configuration
REPO="${IONFETCH_REPO:-sirayu-pn/Ionfetch}"
BRANCH="${IONFETCH_BRANCH:-main}"
RAW_BASE_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}"
BIN_NAME="ionfetch"

# Colors
C_RESET=$'\e[0m'
C_GREEN=$'\e[1;92m'
C_YELLOW=$'\e[93m'
C_RED=$'\e[91m'
C_CYAN=$'\e[96m'
C_GRAY=$'\e[90m'

info()    { printf '%s[INFO]%s %s\n' "$C_CYAN" "$C_RESET" "$*"; }
success() { printf '%s[SUCCESS]%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
warn()    { printf '%s[WARN]%s %s\n' "$C_YELLOW" "$C_RESET" "$*"; }
error()   { printf '%s[ERROR]%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; exit 1; }

# Parse arguments
INSTALL_MODE="system"
UNINSTALL=0

for arg in "$@"; do
    case "$arg" in
        --user)
            INSTALL_MODE="user"
            ;;
        --uninstall|-u)
            UNINSTALL=1
            ;;
        -h|--help)
            cat <<EOF
Ionfetch Installer

Usage:
  ./install.sh [options]

Options:
  --user         Install to ~/.local/bin (no root / sudo required)
  --uninstall    Uninstall ionfetch from your system
  -h, --help     Show this help message

EOF
            exit 0
            ;;
    esac
done

# Determine installation path
if [[ "$INSTALL_MODE" == "user" ]]; then
    INSTALL_DIR="$HOME/.local/bin"
    SUDO=""
else
    INSTALL_DIR="/usr/local/bin"
    if [[ $EUID -ne 0 ]]; then
        if command -v sudo >/dev/null 2>&1; then
            SUDO="sudo"
        else
            warn "Root or sudo not detected. Switching to user mode (~/.local/bin)..."
            INSTALL_MODE="user"
            INSTALL_DIR="$HOME/.local/bin"
            SUDO=""
        fi
    else
        SUDO=""
    fi
fi

TARGET_BIN="${INSTALL_DIR}/${BIN_NAME}"

# Handle Uninstallation
if [[ $UNINSTALL -eq 1 ]]; then
    info "Uninstalling ${BIN_NAME}..."
    if [[ -f "$TARGET_BIN" ]]; then
        $SUDO rm -f "$TARGET_BIN"
        success "Removed ${TARGET_BIN}"
    elif [[ -f "/usr/local/bin/${BIN_NAME}" ]]; then
        $SUDO rm -f "/usr/local/bin/${BIN_NAME}"
        success "Removed /usr/local/bin/${BIN_NAME}"
    elif [[ -f "$HOME/.local/bin/${BIN_NAME}" ]]; then
        rm -f "$HOME/.local/bin/${BIN_NAME}"
        success "Removed $HOME/.local/bin/${BIN_NAME}"
    else
        warn "Binary ${BIN_NAME} not found."
    fi
    exit 0
fi

info "Installing ${BIN_NAME} to ${TARGET_BIN}..."

# Ensure directory exists
if [[ "$INSTALL_MODE" == "user" ]]; then
    mkdir -p "$INSTALL_DIR"
else
    $SUDO mkdir -p "$INSTALL_DIR"
fi

# Locate source file (Local clone vs Remote curl)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || echo "")"

if [[ -n "$SCRIPT_DIR" && -f "${SCRIPT_DIR}/ionfetch.sh" ]]; then
    info "Installing from local file: ${SCRIPT_DIR}/ionfetch.sh"
    $SUDO cp -f "${SCRIPT_DIR}/ionfetch.sh" "$TARGET_BIN"
elif [[ -f "./ionfetch.sh" ]]; then
    info "Installing from local file: ./ionfetch.sh"
    $SUDO cp -f "./ionfetch.sh" "$TARGET_BIN"
else
    info "Downloading from GitHub (${REPO}@${BRANCH})..."
    TMP_FILE="$(mktemp)"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "${RAW_BASE_URL}/ionfetch.sh" -o "$TMP_FILE" || error "Failed to download ionfetch.sh using curl"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO "$TMP_FILE" "${RAW_BASE_URL}/ionfetch.sh" || error "Failed to download ionfetch.sh using wget"
    else
        error "Neither curl nor wget found. Please install curl or wget first."
    fi

    $SUDO cp -f "$TMP_FILE" "$TARGET_BIN"
    rm -f "$TMP_FILE"
fi

# Set executable permission
$SUDO chmod 755 "$TARGET_BIN"

# Check if INSTALL_DIR is in PATH
if ! echo "$PATH" | tr ':' '\n' | grep -qx "$INSTALL_DIR"; then
    warn "${INSTALL_DIR} is not in your PATH."
    printf "  %sTo use '%s' directly, add this to your ~/.bashrc or ~/.zshrc:%s\n" "$C_GRAY" "$BIN_NAME" "$C_RESET"
    printf "  %sexport PATH=\"%s:\$PATH\"%s\n\n" "$C_CYAN" "$INSTALL_DIR" "$C_RESET"
fi

success "Successfully installed ${BIN_NAME}!"
printf "\n"
printf "%sRun it anytime by typing:%s\n" "$C_GREEN" "$C_RESET"
printf "  %s%s%s\n\n" "$C_CYAN" "$BIN_NAME" "$C_RESET"
