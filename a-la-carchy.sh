#!/bin/bash

# A La Carchy - Omarchy Linux Debloater
# Pick and choose what you want to remove, à la carte style!

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Package mapping: "Display Name|package-name|description"
declare -a PACKAGES=(
    "1Password|1password|Password manager"
    "Aether|aether|P2P discussion platform"
    "Alacritty|alacritty|GPU-accelerated terminal emulator"
    "Calculator|gnome-calculator|Simple calculator application"
    "Chromium|chromium|Open-source web browser"
    "Docker|docker|Container platform"
    "Document Viewer|evince|PDF and document viewer"
    "Ghostty|ghostty|Terminal emulator"
    "Image Viewer|imv|Lightweight image viewer"
    "Kdenlive|kdenlive|Video editing software"
    "LibreOffice|libreoffice-fresh|Office suite (complete)"
    "LibreOffice Base|libreoffice-fresh-base|Database management"
    "LibreOffice Calc|libreoffice-fresh-calc|Spreadsheet application"
    "LibreOffice Draw|libreoffice-fresh-draw|Drawing application"
    "LibreOffice Impress|libreoffice-fresh-impress|Presentation software"
    "LibreOffice Math|libreoffice-fresh-math|Formula editor"
    "LibreOffice Writer|libreoffice-fresh-writer|Word processor"
    "LocalSend|localsend-bin|Local file sharing"
    "Media Player|mpv|Minimal media player"
    "Neovim|neovim|Hyperextensible Vim-based text editor"
    "OBS Studio|obs-studio|Video recording and streaming"
    "Obsidian|obsidian|Note-taking application"
    "Pinta|pinta|Image editing program"
    "Signal|signal-desktop|Private messaging application"
    "Spotify|spotify|Music streaming service"
    "Typora|typora|Markdown editor"
    "Xournal++|xournalpp|Handwriting note-taking software"
)

# Check if dialog is installed, and install if needed
if ! command -v dialog &> /dev/null; then
    echo -e "${YELLOW}Dialog is not installed. Installing it now...${NC}"
    if ! sudo pacman -S --noconfirm dialog; then
        echo -e "${RED}Error: Failed to install dialog.${NC}"
        echo "Please install it manually with: sudo pacman -S dialog"
        exit 1
    fi
    echo -e "${GREEN}Dialog installed successfully!${NC}"
    echo
fi

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    echo -e "${RED}Error: Do not run this script as root!${NC}"
    echo "The script will ask for sudo password when needed."
    exit 1
fi

# Detect AUR helper
AUR_HELPER=""
if command -v yay &> /dev/null; then
    AUR_HELPER="yay"
elif command -v paru &> /dev/null; then
    AUR_HELPER="paru"
else
    echo -e "${YELLOW}Warning: No AUR helper (yay/paru) detected.${NC}"
    echo "Will use pacman only (some packages may not be removable)."
    AUR_HELPER="sudo pacman"
fi

echo -e "${BLUE}Using package manager: ${AUR_HELPER}${NC}"

# Build dialog checklist options
DIALOG_OPTIONS=()
for i in "${!PACKAGES[@]}"; do
    IFS='|' read -r display_name package_name description <<< "${PACKAGES[$i]}"
    # Check if package is installed
    if pacman -Qi "$package_name" &> /dev/null; then
        DIALOG_OPTIONS+=("$package_name" "$display_name - $description" "OFF")
    fi
done

# Check if any packages are installed
if [ ${#DIALOG_OPTIONS[@]} -eq 0 ]; then
    dialog --title "A La Carchy" \
           --msgbox "No preinstalled packages found!\n\nEither they are already removed or package names need to be updated." 10 60
    clear
    exit 0
fi

# Show package selection dialog
TEMP_FILE=$(mktemp)
dialog --title "A La Carchy - Omarchy Debloater" \
       --backtitle "Select packages to remove (Space to select, Enter to confirm)" \
       --checklist "Choose packages to remove:" 25 80 15 \
       "${DIALOG_OPTIONS[@]}" 2>"$TEMP_FILE"

# Check if user cancelled
if [ $? -ne 0 ]; then
    clear
    echo -e "${YELLOW}Operation cancelled.${NC}"
    rm -f "$TEMP_FILE"
    exit 0
fi

# Read selected packages
SELECTED_PACKAGES=$(cat "$TEMP_FILE")
rm -f "$TEMP_FILE"

# Check if any packages were selected
if [ -z "$SELECTED_PACKAGES" ]; then
    clear
    echo -e "${YELLOW}No packages selected. Nothing to do.${NC}"
    exit 0
fi

# Remove quotes and convert to array
SELECTED_PACKAGES=$(echo "$SELECTED_PACKAGES" | tr -d '"')
read -ra PKG_ARRAY <<< "$SELECTED_PACKAGES"

clear
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
echo -e "${BLUE}       A La Carchy - Confirmation             ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
echo
echo -e "${YELLOW}The following packages will be removed:${NC}"
echo
for pkg in "${PKG_ARRAY[@]}"; do
    echo -e "  ${RED}✗${NC} $pkg"
done
echo
echo -e "${RED}WARNING: This will remove the packages and their dependencies!${NC}"
echo -e "${YELLOW}Make sure you have backups of any important data.${NC}"
echo
read -p "Do you want to continue? (yes/no): " -r
echo

if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo -e "${YELLOW}Operation cancelled.${NC}"
    exit 0
fi

# Remove packages
echo -e "${BLUE}Starting package removal...${NC}"
echo

if [ "$AUR_HELPER" = "sudo pacman" ]; then
    sudo pacman -Rns "${PKG_ARRAY[@]}"
else
    $AUR_HELPER -Rns "${PKG_ARRAY[@]}"
fi

# Check if removal was successful
if [ $? -eq 0 ]; then
    echo
    echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
    echo -e "${GREEN}    Packages removed successfully! ✓         ${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
    echo
    echo -e "${BLUE}You may want to run:${NC}"
    echo -e "  ${AUR_HELPER} -Sc  ${YELLOW}# Clean package cache${NC}"
    echo
else
    echo
    echo -e "${RED}═══════════════════════════════════════════════${NC}"
    echo -e "${RED}    Package removal failed!                   ${NC}"
    echo -e "${RED}═══════════════════════════════════════════════${NC}"
    exit 1
fi
