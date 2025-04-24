#!/bin/bash
set -e

# Function: Detect package manager
detect_package_manager() {
  if command -v apt &> /dev/null; then
    echo "apt"
  elif command -v dnf &> /dev/null; then
    echo "dnf"
  elif command -v pacman &> /dev/null; then
    echo "pacman"
  else
    echo "unknown"
  fi
}

# Function: Check if user can use sudo
check_sudo() {
  if ! command -v sudo &> /dev/null; then
    echo "❌ 'sudo' is required but not found. Please install dependencies manually."
    exit 1
  elif ! sudo -n true 2>/dev/null; then
    echo "❌ This script requires sudo to install packages, but you are not allowed to use it (or no passwordless sudo)."
    echo "Run this script as a user with sudo privileges or install dependencies manually."
    exit 1
  fi
}

# Function: Install dependencies
install_dependencies() {
  local pm=$1
  echo "Installing missing dependencies with $pm..."
  case "$pm" in
    apt)
      sudo apt update && sudo apt install -y curl unzip fontconfig
      ;;
    dnf)
      sudo dnf install -y curl unzip fontconfig
      ;;
    pacman)
      sudo pacman -Sy --noconfirm curl unzip fontconfig
      ;;
    *)
      echo "Unsupported package manager. Please install curl, unzip, and fontconfig manually."
      exit 1
      ;;
  esac
}

# Step 1: Detect and check
PM=$(detect_package_manager)

# If package manager requires sudo, make sure we're allowed
if [[ "$PM" != "unknown" ]]; then
  check_sudo
  install_dependencies "$PM"
else
  echo "⚠️ Unknown package manager. Skipping automatic dependency install."
fi

# Prompt for font
read -p "Enter the Nerd Font name to install (e.g., FiraCode, Hack, JetBrainsMono): " FONT_NAME

# Format
ZIP_NAME="${FONT_NAME}.zip"
DOWNLOAD_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/${ZIP_NAME}"
FONT_DIR="$HOME/.local/share/fonts/${FONT_NAME}"
TMP_ZIP="/tmp/${ZIP_NAME}"

# Step 2: Download and install font locally
echo "Downloading $FONT_NAME from Nerd Fonts..."
mkdir -p "$FONT_DIR"
curl -L -o "$TMP_ZIP" "$DOWNLOAD_URL"

echo "Extracting..."
unzip -q "$TMP_ZIP" -d "$FONT_DIR"
rm "$TMP_ZIP"

echo "Refreshing font cache..."
fc-cache -fv "$FONT_DIR"

echo "✅ $FONT_NAME Nerd Font installed for user: $USER"
