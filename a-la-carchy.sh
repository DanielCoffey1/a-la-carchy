#!/bin/bash

# A La Carchy - Omarchy Linux Debloater
# Pick and choose what you want to remove, à la carte style!

# Clean, minimal color scheme
RESET='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'
SELECTED_BG='\033[7m'
CHECKED='\033[38;5;10m'

# Default packages offered for removal
# List from: https://github.com/basecamp/omarchy/blob/master/install/packages.sh
DEFAULT_APPS=(
    "1password-beta"
    "1password-cli"
    "docker"
    "docker-buildx"
    "docker-compose"
    "gnome-calculator"
    "kdenlive"
    "libreoffice-fresh"
    "localsend"
    "obs-studio"
    "obsidian"
    "omarchy-chromium"
    "pinta"
    "signal-desktop"
    "spotify"
    "typora"
    "xournalpp"
)

# Default webapps offered for removal
# List from: https://github.com/basecamp/omarchy/blob/master/install/packaging/webapps.sh
DEFAULT_WEBAPPS=(
    "Basecamp"
    "ChatGPT"
    "Discord"
    "Figma"
    "Fizzy"
    "GitHub"
    "Google Contacts"
    "Google Maps"
    "Google Messages"
    "Google Photos"
    "HEY"
    "WhatsApp"
    "X"
    "YouTube"
    "Zoom"
)

# Summary log for tracking completed actions
declare -a SUMMARY_LOG=()

# Hyprland tiling config path
TILING_CONF="$HOME/.local/share/omarchy/default/hypr/bindings/tiling-v2.conf"

# Hyprland monitors config path
MONITORS_CONF="$HOME/.config/hypr/monitors.conf"

# Hyprland bindings config path
BINDINGS_CONF="$HOME/.config/hypr/bindings.conf"

# XCompose config path
XCOMPOSE_CONF="$HOME/.XCompose"

# Hyprland input config path
INPUT_CONF="$HOME/.config/hypr/input.conf"

# Suspend state file path
SUSPEND_STATE="$HOME/.local/state/omarchy/toggles/suspend-on"

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    echo "Error: Do not run this script as root!"
    echo "The script will ask for sudo password when needed."
    exit 1
fi

# Function to check if package is installed
is_package_installed() {
    pacman -Qi "$1" &>/dev/null
}

# Function to check if webapp is installed
is_webapp_installed() {
    [[ -f "$HOME/.local/share/applications/$1.desktop" ]]
}

# Function to rebind close window from SUPER+W to SUPER+Q
rebind_close_window() {
    clear
    echo
    echo
    echo -e "${BOLD}  Rebind Close Window${RESET}"
    echo
    echo -e "  ${DIM}Changes SUPER+W (Omarchy default) to SUPER+Q for closing windows.${RESET}"
    echo
    echo

    if [[ ! -f "$TILING_CONF" ]]; then
        echo -e "  ${DIM}✗${RESET}  tiling-v2.conf not found at $TILING_CONF"
        echo
        SUMMARY_LOG+=("✗  Rebind close window -- failed (config not found)")
        return 1
    fi

    # Check if already changed
    if grep -q "SUPER, Q, Close window, killactive" "$TILING_CONF"; then
        echo -e "  ${DIM}Already set to SUPER+Q. Nothing to do.${RESET}"
        echo
        SUMMARY_LOG+=("--  Rebind close window -- already set")
        return 0
    fi

    printf "  ${BOLD}Continue?${RESET} ${DIM}(yes/no)${RESET} "
    read -r < /dev/tty

    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo
        echo "  Cancelled."
        echo
        SUMMARY_LOG+=("--  Rebind close window -- cancelled")
        return 0
    fi

    echo

    # Create backup
    local backup_file="${TILING_CONF}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$TILING_CONF" "$backup_file"
    echo -e "    ${DIM}Backup saved: $backup_file${RESET}"

    # Replace SUPER, W with SUPER, Q for killactive
    sed -i 's/bindd = SUPER, W, Close window, killactive,/bindd = SUPER, Q, Close window, killactive,/' "$TILING_CONF"

    echo -e "    ${CHECKED}✓${RESET}  Close window rebound to SUPER+Q"
    SUMMARY_LOG+=("✓  Rebind close window to SUPER+Q")
    echo
    echo -e "  ${DIM}Reload Hyprland or log out/in to apply.${RESET}"
    echo
    echo
}

# Function to backup config directories
backup_configs() {
    clear
    echo
    echo
    echo -e "${BOLD}  Backup Config${RESET}"
    echo
    echo -e "  ${DIM}Creates an archive of your Omarchy config directories and a restore script.${RESET}"
    echo
    echo

    local timestamp=$(date +%Y%m%d_%H%M%S)
    local archive="$HOME/omarchy-backup-${timestamp}.tar.gz"
    local restore_script="$HOME/restore-omarchy-config.sh"

    # Directories to back up (relative to ~/.config)
    local config_dirs=(
        "hypr"
        "waybar"
        "mako"
        "omarchy"
        "walker"
        "alacritty"
        "kitty"
        "ghostty"
    )

    # Check which dirs exist
    local existing_dirs=()
    for d in "${config_dirs[@]}"; do
        if [[ -d "$HOME/.config/$d" ]]; then
            existing_dirs+=(".config/$d")
        fi
    done

    if [[ ${#existing_dirs[@]} -eq 0 ]]; then
        echo -e "  ${DIM}✗${RESET}  No config directories found to back up."
        echo
        SUMMARY_LOG+=("✗  Backup config -- failed (no config dirs found)")
        return 1
    fi

    echo -e "  ${DIM}Directories to back up:${RESET}"
    for d in "${existing_dirs[@]}"; do
        echo "    ${DIM}•${RESET}  ~/$d"
    done
    echo
    echo

    printf "  ${BOLD}Continue?${RESET} ${DIM}(yes/no)${RESET} "
    read -r < /dev/tty

    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo
        echo "  Cancelled."
        echo
        SUMMARY_LOG+=("--  Backup config -- cancelled")
        return 0
    fi

    echo

    # Create archive (follow symlinks with -h)
    if tar -czhf "$archive" -C "$HOME" "${existing_dirs[@]}" 2>/dev/null; then
        echo -e "    ${CHECKED}✓${RESET}  Archive created: $archive"
    else
        echo -e "    ${DIM}✗${RESET}  Failed to create archive."
        echo
        SUMMARY_LOG+=("✗  Backup config -- failed (archive creation error)")
        return 1
    fi

    # Generate restore script
    cat > "$restore_script" << 'RESTORE_EOF'
#!/bin/bash
# Omarchy Config Restore Script
ARCHIVE="ARCHIVE_PLACEHOLDER"

if [[ ! -f "$ARCHIVE" ]]; then
    echo "Error: Archive not found: $ARCHIVE"
    exit 1
fi

echo "This will restore Omarchy config files from:"
echo "  $ARCHIVE"
echo
echo "Existing config files will be overwritten."
echo
printf "Continue? (yes/no) "
read -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Cancelled."
    exit 0
fi

echo
if tar -xzhf "$ARCHIVE" -C "$HOME"; then
    echo "Config restored successfully."
    echo "Reload Hyprland or log out/in to apply changes."
else
    echo "Failed to restore config."
    exit 1
fi
RESTORE_EOF

    # Patch in the actual archive path
    sed -i "s|ARCHIVE_PLACEHOLDER|$archive|" "$restore_script"
    chmod +x "$restore_script"

    echo -e "    ${CHECKED}✓${RESET}  Restore script: $restore_script"
    echo
    echo -e "  ${DIM}To restore later, run: bash ~/restore-omarchy-config.sh${RESET}"
    echo
    echo
    SUMMARY_LOG+=("✓  Backup config created")
}

# Function to set monitor scaling to 4K
set_monitor_4k() {
    clear
    echo
    echo
    echo -e "${BOLD}  Set Monitor Scaling: 4K${RESET}"
    echo
    echo -e "  ${DIM}Configures monitor scaling optimized for 4K displays.${RESET}"
    echo -e "  ${DIM}Sets GDK_SCALE=1.75 and monitor scale to 1.666667.${RESET}"
    echo
    echo

    if [[ ! -f "$MONITORS_CONF" ]]; then
        echo -e "  ${DIM}✗${RESET}  monitors.conf not found at $MONITORS_CONF"
        echo
        SUMMARY_LOG+=("✗  Monitor scaling 4K -- failed (config not found)")
        return 1
    fi

    printf "  ${BOLD}Continue?${RESET} ${DIM}(yes/no)${RESET} "
    read -r < /dev/tty

    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo
        echo "  Cancelled."
        echo
        SUMMARY_LOG+=("--  Monitor scaling 4K -- cancelled")
        return 0
    fi

    echo

    # Create backup
    local backup_file="${MONITORS_CONF}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$MONITORS_CONF" "$backup_file"
    echo -e "    ${DIM}Backup saved: $backup_file${RESET}"

    # Write new config
    cat > "$MONITORS_CONF" << 'EOF'
# See https://wiki.hyprland.org/Configuring/Monitors/
# List current monitors and resolutions possible: hyprctl monitors
# Format: monitor = [port], resolution, position, scale

# Optimized for 27" or 32" 4K monitors
env = GDK_SCALE,1.75
monitor=,preferred,auto,1.666667
EOF

    echo -e "    ${CHECKED}✓${RESET}  Monitor scaling set to 4K"
    SUMMARY_LOG+=("✓  Monitor scaling set to 4K")
    echo
    echo -e "  ${DIM}Hyprland will auto-reload the config.${RESET}"
    echo
    echo
}

# Function to set monitor scaling to 1080p/1440p
set_monitor_1080_1440() {
    clear
    echo
    echo
    echo -e "${BOLD}  Set Monitor Scaling: 1080p / 1440p${RESET}"
    echo
    echo -e "  ${DIM}Configures monitor scaling for 1080p or 1440p displays.${RESET}"
    echo -e "  ${DIM}Sets GDK_SCALE=1 and monitor scale to 1 (no scaling).${RESET}"
    echo
    echo

    if [[ ! -f "$MONITORS_CONF" ]]; then
        echo -e "  ${DIM}✗${RESET}  monitors.conf not found at $MONITORS_CONF"
        echo
        SUMMARY_LOG+=("✗  Monitor scaling 1080p/1440p -- failed (config not found)")
        return 1
    fi

    printf "  ${BOLD}Continue?${RESET} ${DIM}(yes/no)${RESET} "
    read -r < /dev/tty

    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo
        echo "  Cancelled."
        echo
        SUMMARY_LOG+=("--  Monitor scaling 1080p/1440p -- cancelled")
        return 0
    fi

    echo

    # Create backup
    local backup_file="${MONITORS_CONF}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$MONITORS_CONF" "$backup_file"
    echo -e "    ${DIM}Backup saved: $backup_file${RESET}"

    # Write new config
    cat > "$MONITORS_CONF" << 'EOF'
# See https://wiki.hyprland.org/Configuring/Monitors/
# List current monitors and resolutions possible: hyprctl monitors
# Format: monitor = [port], resolution, position, scale

# Straight 1x setup for 1080p or 1440p displays
env = GDK_SCALE,1
monitor=,preferred,auto,1
EOF

    echo -e "    ${CHECKED}✓${RESET}  Monitor scaling set to 1080p/1440p"
    SUMMARY_LOG+=("✓  Monitor scaling set to 1080p/1440p")
    echo
    echo -e "  ${DIM}Hyprland will auto-reload the config.${RESET}"
    echo
    echo
}

bind_shutdown() {
    clear
    echo
    echo
    echo -e "${BOLD}  Bind Shutdown to SUPER+ALT+S${RESET}"
    echo
    echo -e "  ${DIM}Adds a keybinding to shutdown the system with SUPER+ALT+S.${RESET}"
    echo
    echo

    if [[ ! -f "$BINDINGS_CONF" ]]; then
        echo -e "  ${DIM}✗${RESET}  bindings.conf not found at $BINDINGS_CONF"
        echo
        SUMMARY_LOG+=("✗  Bind shutdown -- failed (config not found)")
        return 1
    fi

    if grep -q "SUPER ALT, S, Shutdown" "$BINDINGS_CONF"; then
        echo -e "  ${DIM}Already bound. Nothing to do.${RESET}"
        echo
        SUMMARY_LOG+=("--  Bind shutdown -- already set")
        return 0
    fi

    printf "  ${BOLD}Continue?${RESET} ${DIM}(yes/no)${RESET} "
    read -r < /dev/tty

    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo
        echo "  Cancelled."
        echo
        SUMMARY_LOG+=("--  Bind shutdown -- cancelled")
        return 0
    fi

    echo

    local backup_file="${BINDINGS_CONF}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$BINDINGS_CONF" "$backup_file"
    echo -e "  ${DIM}Backup: $backup_file${RESET}"

    echo "" >> "$BINDINGS_CONF"
    echo "bindd = SUPER ALT, S, Shutdown, exec, systemctl poweroff" >> "$BINDINGS_CONF"

    echo -e "  ${DIM}✓${RESET}  Bound SUPER+ALT+S to shutdown"
    SUMMARY_LOG+=("✓  Bound shutdown to SUPER+ALT+S")
    echo
}

bind_restart() {
    clear
    echo
    echo
    echo -e "${BOLD}  Bind Restart to SUPER+ALT+R${RESET}"
    echo
    echo -e "  ${DIM}Adds a keybinding to restart the system with SUPER+ALT+R.${RESET}"
    echo
    echo

    if [[ ! -f "$BINDINGS_CONF" ]]; then
        echo -e "  ${DIM}✗${RESET}  bindings.conf not found at $BINDINGS_CONF"
        echo
        SUMMARY_LOG+=("✗  Bind restart -- failed (config not found)")
        return 1
    fi

    if grep -q "SUPER ALT, R, Restart" "$BINDINGS_CONF"; then
        echo -e "  ${DIM}Already bound. Nothing to do.${RESET}"
        echo
        SUMMARY_LOG+=("--  Bind restart -- already set")
        return 0
    fi

    printf "  ${BOLD}Continue?${RESET} ${DIM}(yes/no)${RESET} "
    read -r < /dev/tty

    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo
        echo "  Cancelled."
        echo
        SUMMARY_LOG+=("--  Bind restart -- cancelled")
        return 0
    fi

    echo

    local backup_file="${BINDINGS_CONF}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$BINDINGS_CONF" "$backup_file"
    echo -e "  ${DIM}Backup: $backup_file${RESET}"

    echo "" >> "$BINDINGS_CONF"
    echo "bindd = SUPER ALT, R, Restart, exec, systemctl reboot" >> "$BINDINGS_CONF"

    echo -e "  ${DIM}✓${RESET}  Bound SUPER+ALT+R to restart"
    SUMMARY_LOG+=("✓  Bound restart to SUPER+ALT+R")
    echo
}

unbind_shutdown() {
    clear
    echo
    echo
    echo -e "${BOLD}  Unbind Shutdown (SUPER+ALT+S)${RESET}"
    echo
    echo -e "  ${DIM}Removes the shutdown keybinding from bindings.conf.${RESET}"
    echo
    echo

    if [[ ! -f "$BINDINGS_CONF" ]]; then
        echo -e "  ${DIM}✗${RESET}  bindings.conf not found at $BINDINGS_CONF"
        echo
        SUMMARY_LOG+=("✗  Unbind shutdown -- failed (config not found)")
        return 1
    fi

    if ! grep -q "SUPER ALT, S, Shutdown" "$BINDINGS_CONF"; then
        echo -e "  ${DIM}Not bound. Nothing to do.${RESET}"
        echo
        SUMMARY_LOG+=("--  Unbind shutdown -- not bound")
        return 0
    fi

    printf "  ${BOLD}Continue?${RESET} ${DIM}(yes/no)${RESET} "
    read -r < /dev/tty

    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo
        echo "  Cancelled."
        echo
        SUMMARY_LOG+=("--  Unbind shutdown -- cancelled")
        return 0
    fi

    echo

    local backup_file="${BINDINGS_CONF}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$BINDINGS_CONF" "$backup_file"
    echo -e "  ${DIM}Backup: $backup_file${RESET}"

    sed -i '/SUPER ALT, S, Shutdown/d' "$BINDINGS_CONF"

    echo -e "  ${DIM}✓${RESET}  Unbound SUPER+ALT+S (shutdown)"
    SUMMARY_LOG+=("✓  Unbound shutdown (SUPER+ALT+S)")
    echo
}

unbind_restart() {
    clear
    echo
    echo
    echo -e "${BOLD}  Unbind Restart (SUPER+ALT+R)${RESET}"
    echo
    echo -e "  ${DIM}Removes the restart keybinding from bindings.conf.${RESET}"
    echo
    echo

    if [[ ! -f "$BINDINGS_CONF" ]]; then
        echo -e "  ${DIM}✗${RESET}  bindings.conf not found at $BINDINGS_CONF"
        echo
        SUMMARY_LOG+=("✗  Unbind restart -- failed (config not found)")
        return 1
    fi

    if ! grep -q "SUPER ALT, R, Restart" "$BINDINGS_CONF"; then
        echo -e "  ${DIM}Not bound. Nothing to do.${RESET}"
        echo
        SUMMARY_LOG+=("--  Unbind restart -- not bound")
        return 0
    fi

    printf "  ${BOLD}Continue?${RESET} ${DIM}(yes/no)${RESET} "
    read -r < /dev/tty

    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo
        echo "  Cancelled."
        echo
        SUMMARY_LOG+=("--  Unbind restart -- cancelled")
        return 0
    fi

    echo

    local backup_file="${BINDINGS_CONF}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$BINDINGS_CONF" "$backup_file"
    echo -e "  ${DIM}Backup: $backup_file${RESET}"

    sed -i '/SUPER ALT, R, Restart/d' "$BINDINGS_CONF"

    echo -e "  ${DIM}✓${RESET}  Unbound SUPER+ALT+R (restart)"
    SUMMARY_LOG+=("✓  Unbound restart (SUPER+ALT+R)")
    echo
}

bind_theme_menu() {
    clear
    echo
    echo
    echo -e "${BOLD}  Bind Theme Menu to ALT+T${RESET}"
    echo
    echo -e "  ${DIM}Adds a keybinding to open the theme menu with ALT+T.${RESET}"
    echo
    echo

    if [[ ! -f "$BINDINGS_CONF" ]]; then
        echo -e "  ${DIM}✗${RESET}  bindings.conf not found at $BINDINGS_CONF"
        echo
        SUMMARY_LOG+=("✗  Bind theme menu -- failed (config not found)")
        return 1
    fi

    if grep -q "ALT, T, Theme menu" "$BINDINGS_CONF"; then
        echo -e "  ${DIM}Already bound. Nothing to do.${RESET}"
        echo
        SUMMARY_LOG+=("--  Bind theme menu -- already set")
        return 0
    fi

    printf "  ${BOLD}Continue?${RESET} ${DIM}(yes/no)${RESET} "
    read -r < /dev/tty

    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo
        echo "  Cancelled."
        echo
        SUMMARY_LOG+=("--  Bind theme menu -- cancelled")
        return 0
    fi

    echo

    local backup_file="${BINDINGS_CONF}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$BINDINGS_CONF" "$backup_file"
    echo -e "  ${DIM}Backup: $backup_file${RESET}"

    echo "" >> "$BINDINGS_CONF"
    echo "bindd = ALT, T, Theme menu, exec, omarchy-launch-walker -m menus:omarchythemes --width 800 --minheight 400" >> "$BINDINGS_CONF"

    echo -e "  ${DIM}✓${RESET}  Bound ALT+T to theme menu"
    SUMMARY_LOG+=("✓  Bound theme menu to ALT+T")
    echo
}

unbind_theme_menu() {
    clear
    echo
    echo
    echo -e "${BOLD}  Unbind Theme Menu (ALT+T)${RESET}"
    echo
    echo -e "  ${DIM}Removes the theme menu keybinding from bindings.conf.${RESET}"
    echo
    echo

    if [[ ! -f "$BINDINGS_CONF" ]]; then
        echo -e "  ${DIM}✗${RESET}  bindings.conf not found at $BINDINGS_CONF"
        echo
        SUMMARY_LOG+=("✗  Unbind theme menu -- failed (config not found)")
        return 1
    fi

    if ! grep -q "ALT, T, Theme menu" "$BINDINGS_CONF"; then
        echo -e "  ${DIM}Not bound. Nothing to do.${RESET}"
        echo
        SUMMARY_LOG+=("--  Unbind theme menu -- not bound")
        return 0
    fi

    printf "  ${BOLD}Continue?${RESET} ${DIM}(yes/no)${RESET} "
    read -r < /dev/tty

    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo
        echo "  Cancelled."
        echo
        SUMMARY_LOG+=("--  Unbind theme menu -- cancelled")
        return 0
    fi

    echo

    local backup_file="${BINDINGS_CONF}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$BINDINGS_CONF" "$backup_file"
    echo -e "  ${DIM}Backup: $backup_file${RESET}"

    sed -i '/ALT, T, Theme menu/d' "$BINDINGS_CONF"

    echo -e "  ${DIM}✓${RESET}  Unbound ALT+T (theme menu)"
    SUMMARY_LOG+=("✓  Unbound theme menu (ALT+T)")
    echo
}

restore_capslock() {
    clear
    echo
    echo
    echo -e "${BOLD}  Restore Caps Lock Key${RESET}"
    echo
    echo -e "  ${DIM}Returns Caps Lock to normal behavior (typing in CAPITALS).${RESET}"
    echo -e "  ${DIM}Moves compose key to Right Alt, so shortcuts still work:${RESET}"
    echo -e "  ${DIM}  • Right Alt + Space + Space → em dash (—)${RESET}"
    echo -e "  ${DIM}  • Right Alt + Space + n → your name${RESET}"
    echo -e "  ${DIM}  • Right Alt + Space + e → your email${RESET}"
    echo -e "  ${DIM}  • Right Alt + m + s → 😄 (and all other emojis)${RESET}"
    echo
    echo

    if [[ ! -f "$INPUT_CONF" ]]; then
        echo -e "  ${DIM}✗${RESET}  input.conf not found at $INPUT_CONF"
        echo
        SUMMARY_LOG+=("✗  Restore Caps Lock -- failed (config not found)")
        return 1
    fi

    # Check if already using ralt
    if grep -q "kb_options = compose:ralt" "$INPUT_CONF"; then
        echo -e "  ${DIM}Caps Lock already restored. Nothing to do.${RESET}"
        echo
        SUMMARY_LOG+=("--  Restore Caps Lock -- already set")
        return 0
    fi

    # Check if compose:caps exists
    if ! grep -q "kb_options = compose:caps" "$INPUT_CONF"; then
        echo -e "  ${DIM}compose:caps not found in config. Nothing to do.${RESET}"
        echo
        SUMMARY_LOG+=("--  Restore Caps Lock -- compose:caps not found")
        return 0
    fi

    printf "  ${BOLD}Continue?${RESET} ${DIM}(yes/no)${RESET} "
    read -r < /dev/tty

    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo
        echo "  Cancelled."
        echo
        SUMMARY_LOG+=("--  Restore Caps Lock -- cancelled")
        return 0
    fi

    echo

    # Create backup
    local backup_file="${INPUT_CONF}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$INPUT_CONF" "$backup_file"
    echo -e "  ${DIM}Backup: $backup_file${RESET}"

    # Replace compose:caps with compose:ralt
    sed -i 's/kb_options = compose:caps/kb_options = compose:ralt/' "$INPUT_CONF"

    echo -e "  ${CHECKED}✓${RESET}  Caps Lock restored (compose moved to Right Alt)"
    SUMMARY_LOG+=("✓  Restored Caps Lock (compose on Right Alt)")
    echo
    echo -e "  ${DIM}Hyprland will auto-reload the config.${RESET}"
    echo
}

use_capslock_compose() {
    clear
    echo
    echo
    echo -e "${BOLD}  Use Caps Lock for Compose${RESET}"
    echo
    echo -e "  ${DIM}Returns to Omarchy default: Caps Lock as compose key.${RESET}"
    echo -e "  ${DIM}  • Caps Lock + Space + Space → em dash (—)${RESET}"
    echo -e "  ${DIM}  • Caps Lock + m + s → 😄 (emojis)${RESET}"
    echo -e "  ${DIM}  • No Caps Lock for CAPITALS${RESET}"
    echo
    echo

    if [[ ! -f "$INPUT_CONF" ]]; then
        echo -e "  ${DIM}✗${RESET}  input.conf not found at $INPUT_CONF"
        echo
        SUMMARY_LOG+=("✗  Use Caps Lock compose -- failed (config not found)")
        return 1
    fi

    # Check if already using caps
    if grep -q "kb_options = compose:caps" "$INPUT_CONF"; then
        echo -e "  ${DIM}Already using Caps Lock for compose. Nothing to do.${RESET}"
        echo
        SUMMARY_LOG+=("--  Use Caps Lock compose -- already set")
        return 0
    fi

    # Check if compose:ralt exists
    if ! grep -q "kb_options = compose:ralt" "$INPUT_CONF"; then
        echo -e "  ${DIM}compose:ralt not found in config. Nothing to do.${RESET}"
        echo
        SUMMARY_LOG+=("--  Use Caps Lock compose -- compose:ralt not found")
        return 0
    fi

    printf "  ${BOLD}Continue?${RESET} ${DIM}(yes/no)${RESET} "
    read -r < /dev/tty

    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo
        echo "  Cancelled."
        echo
        SUMMARY_LOG+=("--  Use Caps Lock compose -- cancelled")
        return 0
    fi

    echo

    # Create backup
    local backup_file="${INPUT_CONF}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$INPUT_CONF" "$backup_file"
    echo -e "  ${DIM}Backup: $backup_file${RESET}"

    # Replace compose:ralt with compose:caps
    sed -i 's/kb_options = compose:ralt/kb_options = compose:caps/' "$INPUT_CONF"

    echo -e "  ${CHECKED}✓${RESET}  Caps Lock now used for compose (Omarchy default)"
    SUMMARY_LOG+=("✓  Caps Lock used for compose")
    echo
    echo -e "  ${DIM}Hyprland will auto-reload the config.${RESET}"
    echo
}

swap_alt_super() {
    clear
    echo
    echo
    echo -e "${BOLD}  Swap Alt and Super Keys${RESET}"
    echo
    echo -e "  ${DIM}Makes Alt behave as Super and Super behave as Alt.${RESET}"
    echo -e "  ${DIM}Useful for macOS-like shortcuts (Alt+Q to close, etc).${RESET}"
    echo
    echo -e "  ${DIM}After this tweak:${RESET}"
    echo -e "  ${DIM}  • Alt + Return → Terminal (was Super + Return)${RESET}"
    echo -e "  ${DIM}  • Alt + Q → Close window (was Super + Q)${RESET}"
    echo -e "  ${DIM}  • Alt + Space → App launcher (was Super + Space)${RESET}"
    echo
    echo

    if [[ ! -f "$INPUT_CONF" ]]; then
        echo -e "  ${DIM}✗${RESET}  input.conf not found at $INPUT_CONF"
        echo
        SUMMARY_LOG+=("✗  Swap Alt/Super -- failed (config not found)")
        return 1
    fi

    # Check if already swapped
    if grep -q "altwin:swap_alt_win" "$INPUT_CONF"; then
        echo -e "  ${DIM}Alt and Super already swapped. Nothing to do.${RESET}"
        echo
        SUMMARY_LOG+=("--  Swap Alt/Super -- already swapped")
        return 0
    fi

    # Check if kb_options line exists
    if ! grep -q "kb_options = " "$INPUT_CONF"; then
        echo -e "  ${DIM}kb_options not found in config. Nothing to do.${RESET}"
        echo
        SUMMARY_LOG+=("--  Swap Alt/Super -- kb_options not found")
        return 0
    fi

    printf "  ${BOLD}Continue?${RESET} ${DIM}(yes/no)${RESET} "
    read -r < /dev/tty

    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo
        echo "  Cancelled."
        echo
        SUMMARY_LOG+=("--  Swap Alt/Super -- cancelled")
        return 0
    fi

    echo

    # Create backup
    local backup_file="${INPUT_CONF}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$INPUT_CONF" "$backup_file"
    echo -e "  ${DIM}Backup: $backup_file${RESET}"

    # Append altwin:swap_alt_win to kb_options (handles both compose:caps and compose:ralt)
    sed -i 's/\(kb_options = [^#]*\)/\1,altwin:swap_alt_win/' "$INPUT_CONF"

    echo -e "  ${CHECKED}✓${RESET}  Alt and Super keys swapped"
    SUMMARY_LOG+=("✓  Swapped Alt and Super keys")
    echo
    echo -e "  ${DIM}Hyprland will auto-reload the config.${RESET}"
    echo
}

restore_alt_super() {
    clear
    echo
    echo
    echo -e "${BOLD}  Restore Alt and Super Keys${RESET}"
    echo
    echo -e "  ${DIM}Returns Alt and Super to their normal behavior.${RESET}"
    echo -e "  ${DIM}Super key will be used for window management (Omarchy default).${RESET}"
    echo
    echo

    if [[ ! -f "$INPUT_CONF" ]]; then
        echo -e "  ${DIM}✗${RESET}  input.conf not found at $INPUT_CONF"
        echo
        SUMMARY_LOG+=("✗  Restore Alt/Super -- failed (config not found)")
        return 1
    fi

    # Check if swap is active
    if ! grep -q "altwin:swap_alt_win" "$INPUT_CONF"; then
        echo -e "  ${DIM}Alt and Super not swapped. Nothing to do.${RESET}"
        echo
        SUMMARY_LOG+=("--  Restore Alt/Super -- not swapped")
        return 0
    fi

    printf "  ${BOLD}Continue?${RESET} ${DIM}(yes/no)${RESET} "
    read -r < /dev/tty

    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo
        echo "  Cancelled."
        echo
        SUMMARY_LOG+=("--  Restore Alt/Super -- cancelled")
        return 0
    fi

    echo

    # Create backup
    local backup_file="${INPUT_CONF}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$INPUT_CONF" "$backup_file"
    echo -e "  ${DIM}Backup: $backup_file${RESET}"

    # Remove altwin:swap_alt_win from kb_options
    sed -i 's/,altwin:swap_alt_win//' "$INPUT_CONF"

    echo -e "  ${CHECKED}✓${RESET}  Alt and Super keys restored to normal"
    SUMMARY_LOG+=("✓  Restored Alt and Super keys")
    echo
    echo -e "  ${DIM}Hyprland will auto-reload the config.${RESET}"
    echo
}

enable_suspend() {
    clear
    echo
    echo
    echo -e "${BOLD}  Enable Suspend${RESET}"
    echo
    echo -e "  ${DIM}Adds the Suspend option to the Omarchy system menu.${RESET}"
    echo -e "  ${DIM}Access via: Super+Alt+Space → System → Suspend${RESET}"
    echo
    echo

    # Check if already enabled
    if [[ -f "$SUSPEND_STATE" ]]; then
        echo -e "  ${DIM}Suspend already enabled. Nothing to do.${RESET}"
        echo
        SUMMARY_LOG+=("--  Enable suspend -- already enabled")
        return 0
    fi

    printf "  ${BOLD}Continue?${RESET} ${DIM}(yes/no)${RESET} "
    read -r < /dev/tty

    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo
        echo "  Cancelled."
        echo
        SUMMARY_LOG+=("--  Enable suspend -- cancelled")
        return 0
    fi

    echo

    # Create state directory and file
    mkdir -p "$(dirname "$SUSPEND_STATE")"
    touch "$SUSPEND_STATE"

    echo -e "  ${CHECKED}✓${RESET}  Suspend enabled in system menu"
    SUMMARY_LOG+=("✓  Enabled suspend")
    echo
}

disable_suspend() {
    clear
    echo
    echo
    echo -e "${BOLD}  Disable Suspend${RESET}"
    echo
    echo -e "  ${DIM}Removes the Suspend option from the Omarchy system menu.${RESET}"
    echo
    echo

    # Check if already disabled
    if [[ ! -f "$SUSPEND_STATE" ]]; then
        echo -e "  ${DIM}Suspend already disabled. Nothing to do.${RESET}"
        echo
        SUMMARY_LOG+=("--  Disable suspend -- already disabled")
        return 0
    fi

    printf "  ${BOLD}Continue?${RESET} ${DIM}(yes/no)${RESET} "
    read -r < /dev/tty

    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo
        echo "  Cancelled."
        echo
        SUMMARY_LOG+=("--  Disable suspend -- cancelled")
        return 0
    fi

    echo

    # Remove state file
    rm -f "$SUSPEND_STATE"

    echo -e "  ${CHECKED}✓${RESET}  Suspend disabled in system menu"
    SUMMARY_LOG+=("✓  Disabled suspend")
    echo
}

enable_hibernation() {
    clear
    echo
    echo
    echo -e "${BOLD}  Enable Hibernation${RESET}"
    echo
    echo -e "  ${DIM}Creates a swap subvolume on your boot drive sized to match your RAM.${RESET}"
    echo -e "  ${DIM}Adds Hibernate option to system menu and enables suspend-to-hibernate.${RESET}"
    echo
    echo -e "  ${DIM}Note: Requires free space equal to your RAM (e.g., 32GB RAM = 32GB space).${RESET}"
    echo
    echo

    # Check if already enabled
    if omarchy-hibernation-available 2>/dev/null; then
        echo -e "  ${DIM}Hibernation already enabled. Nothing to do.${RESET}"
        echo
        SUMMARY_LOG+=("--  Enable hibernation -- already enabled")
        return 0
    fi

    printf "  ${BOLD}Continue?${RESET} ${DIM}(yes/no)${RESET} "
    read -r < /dev/tty

    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo
        echo "  Cancelled."
        echo
        SUMMARY_LOG+=("--  Enable hibernation -- cancelled")
        return 0
    fi

    echo
    echo -e "  ${DIM}Running omarchy-hibernation-setup...${RESET}"
    echo

    # Run the setup script (it has its own confirmation via gum)
    if omarchy-hibernation-setup; then
        echo
        echo -e "  ${CHECKED}✓${RESET}  Hibernation enabled"
        SUMMARY_LOG+=("✓  Enabled hibernation")
    else
        echo
        echo -e "  ${DIM}Hibernation setup was cancelled or failed.${RESET}"
        SUMMARY_LOG+=("--  Enable hibernation -- cancelled or failed")
    fi
    echo
}

disable_hibernation() {
    clear
    echo
    echo
    echo -e "${BOLD}  Disable Hibernation${RESET}"
    echo
    echo -e "  ${DIM}Removes the swap subvolume and hibernation configuration.${RESET}"
    echo -e "  ${DIM}Frees up disk space equal to your RAM size.${RESET}"
    echo
    echo

    # Check if hibernation is enabled
    if ! omarchy-hibernation-available 2>/dev/null; then
        echo -e "  ${DIM}Hibernation not enabled. Nothing to do.${RESET}"
        echo
        SUMMARY_LOG+=("--  Disable hibernation -- not enabled")
        return 0
    fi

    printf "  ${BOLD}Continue?${RESET} ${DIM}(yes/no)${RESET} "
    read -r < /dev/tty

    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo
        echo "  Cancelled."
        echo
        SUMMARY_LOG+=("--  Disable hibernation -- cancelled")
        return 0
    fi

    echo
    echo -e "  ${DIM}Running omarchy-hibernation-remove...${RESET}"
    echo

    # Run the remove script (it has its own confirmation via gum)
    if omarchy-hibernation-remove; then
        echo
        echo -e "  ${CHECKED}✓${RESET}  Hibernation disabled"
        SUMMARY_LOG+=("✓  Disabled hibernation")
    else
        echo
        echo -e "  ${DIM}Hibernation removal was cancelled or failed.${RESET}"
        SUMMARY_LOG+=("--  Disable hibernation -- cancelled or failed")
    fi
    echo
}

enable_fingerprint() {
    clear
    echo
    echo
    echo -e "${BOLD}  Enable Fingerprint Authentication${RESET}"
    echo
    echo -e "  ${DIM}Sets up fingerprint scanner for authentication.${RESET}"
    echo -e "  ${DIM}Works for: sudo, polkit prompts, and lock screen.${RESET}"
    echo
    echo -e "  ${DIM}Note: Requires a fingerprint sensor and you'll need to enroll your finger.${RESET}"
    echo
    echo

    # Check if already enabled (fprintd installed)
    if pacman -Qi fprintd &>/dev/null; then
        echo -e "  ${DIM}Fingerprint authentication already set up.${RESET}"
        echo -e "  ${DIM}To re-enroll, disable first then enable again.${RESET}"
        echo
        SUMMARY_LOG+=("--  Enable fingerprint -- already enabled")
        return 0
    fi

    printf "  ${BOLD}Continue?${RESET} ${DIM}(yes/no)${RESET} "
    read -r < /dev/tty

    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo
        echo "  Cancelled."
        echo
        SUMMARY_LOG+=("--  Enable fingerprint -- cancelled")
        return 0
    fi

    echo
    echo -e "  ${DIM}Running omarchy-setup-fingerprint...${RESET}"
    echo

    # Run the setup script
    if omarchy-setup-fingerprint; then
        echo
        echo -e "  ${CHECKED}✓${RESET}  Fingerprint authentication enabled"
        SUMMARY_LOG+=("✓  Enabled fingerprint authentication")
    else
        echo
        echo -e "  ${DIM}Fingerprint setup failed or was cancelled.${RESET}"
        SUMMARY_LOG+=("--  Enable fingerprint -- failed or cancelled")
    fi
    echo
}

disable_fingerprint() {
    clear
    echo
    echo
    echo -e "${BOLD}  Disable Fingerprint Authentication${RESET}"
    echo
    echo -e "  ${DIM}Removes fingerprint authentication and uninstalls packages.${RESET}"
    echo
    echo

    # Check if fingerprint is enabled
    if ! pacman -Qi fprintd &>/dev/null; then
        echo -e "  ${DIM}Fingerprint authentication not set up. Nothing to do.${RESET}"
        echo
        SUMMARY_LOG+=("--  Disable fingerprint -- not enabled")
        return 0
    fi

    printf "  ${BOLD}Continue?${RESET} ${DIM}(yes/no)${RESET} "
    read -r < /dev/tty

    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo
        echo "  Cancelled."
        echo
        SUMMARY_LOG+=("--  Disable fingerprint -- cancelled")
        return 0
    fi

    echo
    echo -e "  ${DIM}Running omarchy-setup-fingerprint --remove...${RESET}"
    echo

    # Run the remove script
    if omarchy-setup-fingerprint --remove; then
        echo
        echo -e "  ${CHECKED}✓${RESET}  Fingerprint authentication disabled"
        SUMMARY_LOG+=("✓  Disabled fingerprint authentication")
    else
        echo
        echo -e "  ${DIM}Fingerprint removal failed.${RESET}"
        SUMMARY_LOG+=("--  Disable fingerprint -- failed")
    fi
    echo
}

# Build list of installed packages and webapps
declare -a INSTALLED_ITEMS=()
declare -a INSTALLED_NAMES=()
declare -a INSTALLED_TYPES=()  # "package" or "webapp"

# Check for installed packages
declare -a pkg_items=()
for pkg in "${DEFAULT_APPS[@]}"; do
    if is_package_installed "$pkg"; then
        pkg_items+=("$pkg")
    fi
done

if [ ${#pkg_items[@]} -gt 0 ]; then
    INSTALLED_ITEMS+=("__header_apps__")
    INSTALLED_NAMES+=("Apps")
    INSTALLED_TYPES+=("header")
    for pkg in "${pkg_items[@]}"; do
        INSTALLED_ITEMS+=("$pkg")
        INSTALLED_NAMES+=("$pkg")
        INSTALLED_TYPES+=("package")
    done
fi

# Check for installed webapps
declare -a webapp_items=()
for webapp in "${DEFAULT_WEBAPPS[@]}"; do
    if is_webapp_installed "$webapp"; then
        webapp_items+=("$webapp")
    fi
done

if [ ${#webapp_items[@]} -gt 0 ]; then
    INSTALLED_ITEMS+=("__header_webapps__")
    INSTALLED_NAMES+=("Web Apps")
    INSTALLED_TYPES+=("header")
    for webapp in "${webapp_items[@]}"; do
        INSTALLED_ITEMS+=("$webapp")
        INSTALLED_NAMES+=("$webapp")
        INSTALLED_TYPES+=("webapp")
    done
fi

# Add tweaks section
INSTALLED_ITEMS+=("__header_tweaks__")
INSTALLED_NAMES+=("Tweaks")
INSTALLED_TYPES+=("header")

INSTALLED_ITEMS+=("__reset_keybinds__")
INSTALLED_NAMES+=("Rebind close window to SUPER+Q")
INSTALLED_TYPES+=("action")

INSTALLED_ITEMS+=("__backup_configs__")
INSTALLED_NAMES+=("Backup config (creates restore script)")
INSTALLED_TYPES+=("action")

INSTALLED_ITEMS+=("__monitor_4k__")
INSTALLED_NAMES+=("Set monitor scaling: 4K")
INSTALLED_TYPES+=("action")

INSTALLED_ITEMS+=("__monitor_1080_1440__")
INSTALLED_NAMES+=("Set monitor scaling: 1080p / 1440p")
INSTALLED_TYPES+=("action")

INSTALLED_ITEMS+=("__bind_shutdown__")
INSTALLED_NAMES+=("Bind shutdown to SUPER+ALT+S")
INSTALLED_TYPES+=("action")

INSTALLED_ITEMS+=("__bind_restart__")
INSTALLED_NAMES+=("Bind restart to SUPER+ALT+R")
INSTALLED_TYPES+=("action")

INSTALLED_ITEMS+=("__unbind_shutdown__")
INSTALLED_NAMES+=("Unbind shutdown (SUPER+ALT+S)")
INSTALLED_TYPES+=("action")

INSTALLED_ITEMS+=("__unbind_restart__")
INSTALLED_NAMES+=("Unbind restart (SUPER+ALT+R)")
INSTALLED_TYPES+=("action")

INSTALLED_ITEMS+=("__bind_theme_menu__")
INSTALLED_NAMES+=("Bind theme menu to ALT+T")
INSTALLED_TYPES+=("action")

INSTALLED_ITEMS+=("__unbind_theme_menu__")
INSTALLED_NAMES+=("Unbind theme menu (ALT+T)")
INSTALLED_TYPES+=("action")

INSTALLED_ITEMS+=("__restore_capslock__")
INSTALLED_NAMES+=("Restore Caps Lock (move compose to Right Alt)")
INSTALLED_TYPES+=("action")

INSTALLED_ITEMS+=("__use_capslock_compose__")
INSTALLED_NAMES+=("Use Caps Lock for compose (Omarchy default)")
INSTALLED_TYPES+=("action")

INSTALLED_ITEMS+=("__swap_alt_super__")
INSTALLED_NAMES+=("Swap Alt and Super keys (macOS-like)")
INSTALLED_TYPES+=("action")

INSTALLED_ITEMS+=("__restore_alt_super__")
INSTALLED_NAMES+=("Restore Alt and Super keys (Omarchy default)")
INSTALLED_TYPES+=("action")

INSTALLED_ITEMS+=("__enable_suspend__")
INSTALLED_NAMES+=("Enable suspend in system menu")
INSTALLED_TYPES+=("action")

INSTALLED_ITEMS+=("__disable_suspend__")
INSTALLED_NAMES+=("Disable suspend in system menu")
INSTALLED_TYPES+=("action")

INSTALLED_ITEMS+=("__enable_hibernation__")
INSTALLED_NAMES+=("Enable hibernation (uses RAM-sized disk space)")
INSTALLED_TYPES+=("action")

INSTALLED_ITEMS+=("__disable_hibernation__")
INSTALLED_NAMES+=("Disable hibernation (frees disk space)")
INSTALLED_TYPES+=("action")

INSTALLED_ITEMS+=("__enable_fingerprint__")
INSTALLED_NAMES+=("Enable fingerprint authentication")
INSTALLED_TYPES+=("action")

INSTALLED_ITEMS+=("__disable_fingerprint__")
INSTALLED_NAMES+=("Disable fingerprint authentication")
INSTALLED_TYPES+=("action")

# Selection state
declare -a SELECTED=()
for ((i=0; i<${#INSTALLED_ITEMS[@]}; i++)); do
    SELECTED[$i]=0
done

# Start cursor on first selectable item (skip leading header)
CURSOR=0
for ((i=0; i<${#INSTALLED_ITEMS[@]}; i++)); do
    if [[ "${INSTALLED_TYPES[$i]}" != "header" ]]; then
        CURSOR=$i
        break
    fi
done
SCROLL_OFFSET=0

# Helper function to center text (truncates to fit terminal width)
center_text() {
    local text="$1"
    local term_width=$(tput cols)
    local text_length=${#text}
    # Truncate if text is wider than terminal
    if [ $text_length -gt $term_width ]; then
        text="${text:0:$term_width}"
        text_length=$term_width
    fi
    local padding=$(( (term_width - text_length) / 2 ))
    if [ $padding -lt 0 ]; then
        padding=0
    fi
    printf "%*s%s\n" $padding "" "$text"
}

# Function to draw the interface
draw_interface() {
    local term_height=$(tput lines)
    local term_width=$(tput cols)

    # Determine layout mode based on terminal size
    local show_ascii=0
    local show_subtitle=0
    local compact=0
    if [ $term_width -ge 50 ] && [ $term_height -ge 20 ]; then
        show_ascii=1
    fi
    if [ $term_height -ge 16 ]; then
        show_subtitle=1
    fi
    if [ $term_height -lt 14 ]; then
        compact=1
    fi

    # Calculate header lines used
    local header_lines=2  # top blank + status line
    if [ $show_ascii -eq 1 ]; then
        header_lines=$((header_lines + 4))  # 2 art lines + blank + subtitle area
    else
        header_lines=$((header_lines + 2))  # bold title + blank
    fi
    if [ $show_subtitle -eq 1 ]; then
        header_lines=$((header_lines + 2))  # subtitle + blank
    fi
    if [ $compact -eq 0 ]; then
        header_lines=$((header_lines + 1))  # blank after status
    fi
    # footer takes 3 lines
    local footer_lines=3

    # Count section headers for extra line budget (each header adds a blank line)
    local header_count=0
    for ((i=0; i<${#INSTALLED_ITEMS[@]}; i++)); do
        if [[ "${INSTALLED_TYPES[$i]}" == "header" ]]; then
            ((header_count++))
        fi
    done

    # Calculate max visible items
    local MAX_VISIBLE=$((term_height - header_lines - footer_lines - header_count))
    if [ $MAX_VISIBLE -lt 3 ]; then
        MAX_VISIBLE=3
    fi

    # Clamp cursor and scroll offset to valid range
    local total=${#INSTALLED_ITEMS[@]}
    if [ $CURSOR -ge $total ]; then
        CURSOR=$((total - 1))
    fi
    if [ $SCROLL_OFFSET -gt $((total - MAX_VISIBLE)) ]; then
        SCROLL_OFFSET=$((total - MAX_VISIBLE))
    fi
    if [ $SCROLL_OFFSET -lt 0 ]; then
        SCROLL_OFFSET=0
    fi
    if [ $CURSOR -lt $SCROLL_OFFSET ]; then
        SCROLL_OFFSET=$CURSOR
    fi
    if [ $CURSOR -ge $((SCROLL_OFFSET + MAX_VISIBLE)) ]; then
        SCROLL_OFFSET=$((CURSOR - MAX_VISIBLE + 1))
    fi

    # Calculate visible range
    local visible_start=$SCROLL_OFFSET
    local visible_end=$((SCROLL_OFFSET + MAX_VISIBLE))
    if [ $visible_end -gt $total ]; then
        visible_end=$total
    fi

    # Clear and redraw everything (simpler, no glitches)
    clear
    # Re-read terminal size after clear for most accurate dimensions
    term_width=$(tput cols)
    term_height=$(tput lines)

    # Title - centered
    echo
    if [ $term_width -ge 44 ] && [ $show_ascii -eq 1 ]; then
        local title1=" ▄▀█   █   ▄▀█   █▀▀ ▄▀█ █▀█ █▀▀ █ █ █▄█"
        local title2=" █▀█   █▄▄ █▀█   █▄▄ █▀█ █▀▄ █▄▄ █▀█  █ "
        echo -en "${BOLD}"
        center_text "$title1"
        center_text "$title2"
        echo -en "${RESET}"
    else
        echo -en "${BOLD}"
        center_text "A La Carchy"
        echo -en "${RESET}"
    fi
    if [ $show_subtitle -eq 1 ]; then
        echo
        echo -en "${DIM}"
        center_text "Omarchy Linux Debloater"
        echo -en "${RESET}"
    fi
    echo
    if [ $compact -eq 0 ]; then
        echo
    fi

    # Calculate selection count
    local selected_count=0
    for ((i=0; i<${#INSTALLED_ITEMS[@]}; i++)); do
        if [ ${SELECTED[$i]} -eq 1 ]; then
            ((selected_count++))
        fi
    done

    # Show count if any selected - centered
    if [ $selected_count -gt 0 ]; then
        echo -en "${CHECKED}"
        center_text "${selected_count} applications selected"
        echo -en "${RESET}"
    else
        echo -en "${DIM}"
        center_text "Select applications to remove"
        echo -en "${RESET}"
    fi
    if [ $compact -eq 0 ]; then
        echo
    fi

    # Draw package list - centered
    # Find longest package name for proper centering
    local max_name_len=0
    for name in "${INSTALLED_NAMES[@]}"; do
        local len=${#name}
        if [ $len -gt $max_name_len ]; then
            max_name_len=$len
        fi
    done

    # Add space for checkbox
    local item_width=$((max_name_len + 6))
    # Cap item_width to terminal width minus margins
    local max_item_width=$((term_width - 4))
    if [ $item_width -gt $max_item_width ]; then
        item_width=$max_item_width
    fi
    local left_margin=$(( (term_width - item_width) / 2 ))
    if [ $left_margin -lt 0 ]; then
        left_margin=0
    fi

    # Max display length for item names (item_width minus checkbox "[ ]  " = 5 chars)
    local max_display_name=$((item_width - 6))

    for ((i=visible_start; i<visible_end; i++)); do
        if [[ "${INSTALLED_TYPES[$i]}" == "header" ]]; then
            # Section header - render as a divider line
            local header_text="${INSTALLED_NAMES[$i]}"
            local dash_total=$((item_width - ${#header_text} - 2))
            if [ $dash_total -lt 2 ]; then
                dash_total=2
            fi
            local dash_left=$((dash_total / 2))
            local dash_right=$((dash_total - dash_left))
            local left_dashes=$(printf '%*s' $dash_left '' | tr ' ' '-')
            local right_dashes=$(printf '%*s' $dash_right '' | tr ' ' '-')
            # Add blank line before header (except the very first item)
            if [ $i -gt 0 ]; then
                echo
            fi
            printf "%*s${DIM}${left_dashes} ${BOLD}%s${RESET}${DIM} ${right_dashes}${RESET}\n" $left_margin "" "$header_text"
            continue
        fi

        # Truncate name if needed
        local display_name="${INSTALLED_NAMES[$i]}"
        if [ ${#display_name} -gt $max_display_name ] && [ $max_display_name -gt 1 ]; then
            display_name="${display_name:0:$((max_display_name - 1))}…"
        fi

        local checkbox="[ ]"
        local check_color=""
        if [ ${SELECTED[$i]} -eq 1 ]; then
            checkbox="[•]"
            check_color="${CHECKED}"
        fi

        if [ $i -eq $CURSOR ]; then
            # Highlighted line - centered with full width highlight
            local item_text="${checkbox}  ${display_name}"
            local padding_left=$(printf '%*s' $left_margin '')
            local pad_right=$((term_width - left_margin - item_width))
            if [ $pad_right -lt 0 ]; then
                pad_right=0
            fi
            local padding_right=$(printf '%*s' $pad_right '')
            printf "${padding_left}${SELECTED_BG}%-${item_width}s${RESET}${padding_right}\n" "$item_text"
        else
            # Normal line - centered
            printf "%*s${DIM}${check_color}${checkbox}${RESET}  ${display_name}\n" $left_margin ""
        fi
    done

    # Footer - centered
    echo
    local footer_row=$((term_height - 2))
    tput cup $footer_row 0
    echo -en "${DIM}"
    center_text "↑/↓ Navigate  •  Space Select  •  Enter Continue  •  Q Quit"
    echo -en "${RESET}"
}

# Function to handle key input
handle_input() {
    local key
    # Use a timeout loop so SIGWINCH trap can redraw between attempts.
    # read -t 1 returns 142 on timeout; loop until we get actual input.
    while true; do
        IFS= read -rsn1 -t 1 key < /dev/tty
        local rs=$?
        # 0 = got input, 1 = EOF/error — process the key
        # >128 = signal or timeout — loop to let trap redraw
        if [ $rs -le 1 ]; then
            break
        fi
    done

    local term_height=$(tput lines)
    local MAX_VISIBLE=$((term_height - 10))
    if [ $MAX_VISIBLE -lt 3 ]; then
        MAX_VISIBLE=3
    fi

    case "$key" in
        $'\x1b')  # ESC sequence
            read -rsn2 -t 0.1 key
            case "$key" in
                '[A')  # Up arrow
                    local new_cursor=$CURSOR
                    while [ $new_cursor -gt 0 ]; do
                        ((new_cursor--))
                        if [[ "${INSTALLED_TYPES[$new_cursor]}" != "header" ]]; then
                            CURSOR=$new_cursor
                            if [ $CURSOR -lt $SCROLL_OFFSET ]; then
                                SCROLL_OFFSET=$CURSOR
                            fi
                            break
                        fi
                    done
                    ;;
                '[B')  # Down arrow
                    local new_cursor=$CURSOR
                    while [ $new_cursor -lt $((${#INSTALLED_ITEMS[@]} - 1)) ]; do
                        ((new_cursor++))
                        if [[ "${INSTALLED_TYPES[$new_cursor]}" != "header" ]]; then
                            CURSOR=$new_cursor
                            if [ $CURSOR -ge $((SCROLL_OFFSET + MAX_VISIBLE)) ]; then
                                ((SCROLL_OFFSET++))
                            fi
                            break
                        fi
                    done
                    ;;
            esac
            ;;
        ' ')  # Space - toggle selection (skip headers)
            if [[ "${INSTALLED_TYPES[$CURSOR]}" != "header" ]]; then
                if [ ${SELECTED[$CURSOR]} -eq 0 ]; then
                    SELECTED[$CURSOR]=1
                else
                    SELECTED[$CURSOR]=0
                fi
            fi
            ;;
        '')  # Enter - confirm
            return 1
            ;;
        'q'|'Q')  # Quit
            return 2
            ;;
    esac
    return 0
}

# Main selection loop
cleanup() {
    tput cnorm
    clear
    stty sane
}
trap cleanup EXIT
trap 'draw_interface' WINCH

tput civis
stty -echo

while true; do
    draw_interface
    handle_input
    result=$?
    if [ $result -eq 1 ]; then
        # Enter pressed - continue to confirmation
        break
    elif [ $result -eq 2 ]; then
        # Q pressed - quit
        clear
        echo
        echo "Cancelled."
        echo
        exit 0
    fi
done

stty echo
tput cnorm

# Build lists of selected packages, webapps, and actions
declare -a SELECTED_PACKAGES=()
declare -a SELECTED_WEBAPPS=()
RESET_KEYBINDS=false
BACKUP_CONFIGS=false
MONITOR_4K=false
MONITOR_1080_1440=false
BIND_SHUTDOWN=false
BIND_RESTART=false
UNBIND_SHUTDOWN=false
UNBIND_RESTART=false
BIND_THEME_MENU=false
UNBIND_THEME_MENU=false
RESTORE_CAPSLOCK=false
USE_CAPSLOCK_COMPOSE=false
SWAP_ALT_SUPER=false
RESTORE_ALT_SUPER=false
ENABLE_SUSPEND=false
DISABLE_SUSPEND=false
ENABLE_HIBERNATION=false
DISABLE_HIBERNATION=false
ENABLE_FINGERPRINT=false
DISABLE_FINGERPRINT=false

for ((i=0; i<${#INSTALLED_ITEMS[@]}; i++)); do
    if [ ${SELECTED[$i]} -eq 1 ]; then
        case "${INSTALLED_TYPES[$i]}" in
            "package") SELECTED_PACKAGES+=("${INSTALLED_ITEMS[$i]}") ;;
            "webapp")  SELECTED_WEBAPPS+=("${INSTALLED_ITEMS[$i]}") ;;
            "action")
                if [[ "${INSTALLED_ITEMS[$i]}" == "__reset_keybinds__" ]]; then
                    RESET_KEYBINDS=true
                elif [[ "${INSTALLED_ITEMS[$i]}" == "__backup_configs__" ]]; then
                    BACKUP_CONFIGS=true
                elif [[ "${INSTALLED_ITEMS[$i]}" == "__monitor_4k__" ]]; then
                    MONITOR_4K=true
                elif [[ "${INSTALLED_ITEMS[$i]}" == "__monitor_1080_1440__" ]]; then
                    MONITOR_1080_1440=true
                elif [[ "${INSTALLED_ITEMS[$i]}" == "__bind_shutdown__" ]]; then
                    BIND_SHUTDOWN=true
                elif [[ "${INSTALLED_ITEMS[$i]}" == "__bind_restart__" ]]; then
                    BIND_RESTART=true
                elif [[ "${INSTALLED_ITEMS[$i]}" == "__unbind_shutdown__" ]]; then
                    UNBIND_SHUTDOWN=true
                elif [[ "${INSTALLED_ITEMS[$i]}" == "__unbind_restart__" ]]; then
                    UNBIND_RESTART=true
                elif [[ "${INSTALLED_ITEMS[$i]}" == "__bind_theme_menu__" ]]; then
                    BIND_THEME_MENU=true
                elif [[ "${INSTALLED_ITEMS[$i]}" == "__unbind_theme_menu__" ]]; then
                    UNBIND_THEME_MENU=true
                elif [[ "${INSTALLED_ITEMS[$i]}" == "__restore_capslock__" ]]; then
                    RESTORE_CAPSLOCK=true
                elif [[ "${INSTALLED_ITEMS[$i]}" == "__use_capslock_compose__" ]]; then
                    USE_CAPSLOCK_COMPOSE=true
                elif [[ "${INSTALLED_ITEMS[$i]}" == "__swap_alt_super__" ]]; then
                    SWAP_ALT_SUPER=true
                elif [[ "${INSTALLED_ITEMS[$i]}" == "__restore_alt_super__" ]]; then
                    RESTORE_ALT_SUPER=true
                elif [[ "${INSTALLED_ITEMS[$i]}" == "__enable_suspend__" ]]; then
                    ENABLE_SUSPEND=true
                elif [[ "${INSTALLED_ITEMS[$i]}" == "__disable_suspend__" ]]; then
                    DISABLE_SUSPEND=true
                elif [[ "${INSTALLED_ITEMS[$i]}" == "__enable_hibernation__" ]]; then
                    ENABLE_HIBERNATION=true
                elif [[ "${INSTALLED_ITEMS[$i]}" == "__disable_hibernation__" ]]; then
                    DISABLE_HIBERNATION=true
                elif [[ "${INSTALLED_ITEMS[$i]}" == "__enable_fingerprint__" ]]; then
                    ENABLE_FINGERPRINT=true
                elif [[ "${INSTALLED_ITEMS[$i]}" == "__disable_fingerprint__" ]]; then
                    DISABLE_FINGERPRINT=true
                fi
                ;;
        esac
    fi
done

# Check if anything was selected
if [ ${#SELECTED_PACKAGES[@]} -eq 0 ] && [ ${#SELECTED_WEBAPPS[@]} -eq 0 ] && [ "$RESET_KEYBINDS" = false ] && [ "$BACKUP_CONFIGS" = false ] && [ "$MONITOR_4K" = false ] && [ "$MONITOR_1080_1440" = false ] && [ "$BIND_SHUTDOWN" = false ] && [ "$BIND_RESTART" = false ] && [ "$UNBIND_SHUTDOWN" = false ] && [ "$UNBIND_RESTART" = false ] && [ "$BIND_THEME_MENU" = false ] && [ "$UNBIND_THEME_MENU" = false ] && [ "$RESTORE_CAPSLOCK" = false ] && [ "$USE_CAPSLOCK_COMPOSE" = false ] && [ "$SWAP_ALT_SUPER" = false ] && [ "$RESTORE_ALT_SUPER" = false ] && [ "$ENABLE_SUSPEND" = false ] && [ "$DISABLE_SUSPEND" = false ] && [ "$ENABLE_HIBERNATION" = false ] && [ "$DISABLE_HIBERNATION" = false ] && [ "$ENABLE_FINGERPRINT" = false ] && [ "$DISABLE_FINGERPRINT" = false ]; then
    clear
    echo
    echo "Nothing selected."
    echo
    exit 0
fi

# Handle keybind reset (runs its own confirmation flow)
if [ "$RESET_KEYBINDS" = true ]; then
    rebind_close_window
fi

# Handle backup (runs its own confirmation flow)
if [ "$BACKUP_CONFIGS" = true ]; then
    backup_configs
fi

# Handle monitor scaling (runs its own confirmation flow)
if [ "$MONITOR_4K" = true ]; then
    set_monitor_4k
fi

if [ "$MONITOR_1080_1440" = true ]; then
    set_monitor_1080_1440
fi

if [ "$BIND_SHUTDOWN" = true ]; then
    bind_shutdown
fi

if [ "$BIND_RESTART" = true ]; then
    bind_restart
fi

if [ "$UNBIND_SHUTDOWN" = true ]; then
    unbind_shutdown
fi

if [ "$UNBIND_RESTART" = true ]; then
    unbind_restart
fi

if [ "$BIND_THEME_MENU" = true ]; then
    bind_theme_menu
fi

if [ "$UNBIND_THEME_MENU" = true ]; then
    unbind_theme_menu
fi

if [ "$RESTORE_CAPSLOCK" = true ]; then
    restore_capslock
fi

if [ "$USE_CAPSLOCK_COMPOSE" = true ]; then
    use_capslock_compose
fi

if [ "$SWAP_ALT_SUPER" = true ]; then
    swap_alt_super
fi

if [ "$RESTORE_ALT_SUPER" = true ]; then
    restore_alt_super
fi

if [ "$ENABLE_SUSPEND" = true ]; then
    enable_suspend
fi

if [ "$DISABLE_SUSPEND" = true ]; then
    disable_suspend
fi

if [ "$ENABLE_HIBERNATION" = true ]; then
    enable_hibernation
fi

if [ "$DISABLE_HIBERNATION" = true ]; then
    disable_hibernation
fi

if [ "$ENABLE_FINGERPRINT" = true ]; then
    enable_fingerprint
fi

if [ "$DISABLE_FINGERPRINT" = true ]; then
    disable_fingerprint
fi

# If only action items were selected, show summary and exit
if [ ${#SELECTED_PACKAGES[@]} -eq 0 ] && [ ${#SELECTED_WEBAPPS[@]} -eq 0 ]; then
    trap - EXIT
    clear
    echo
    echo
    echo -e "${BOLD}  Summary${RESET}"
    echo
    for entry in "${SUMMARY_LOG[@]}"; do
        echo -e "  $entry"
    done
    echo
    echo
    exit 0
fi

# Confirmation screen
clear
echo
echo
echo -e "${BOLD}  Confirm Removal${RESET}"
echo
echo

if [ ${#SELECTED_PACKAGES[@]} -gt 0 ]; then
    echo -e "${DIM}  Packages (${#SELECTED_PACKAGES[@]}):${RESET}"
    for pkg in "${SELECTED_PACKAGES[@]}"; do
        echo "    ${DIM}•${RESET}  $pkg"
    done
    echo
fi

if [ ${#SELECTED_WEBAPPS[@]} -gt 0 ]; then
    echo -e "${DIM}  Web Apps (${#SELECTED_WEBAPPS[@]}):${RESET}"
    for webapp in "${SELECTED_WEBAPPS[@]}"; do
        echo "    ${DIM}•${RESET}  $webapp"
    done
    echo
fi

echo
if [ ${#SELECTED_PACKAGES[@]} -gt 0 ]; then
    echo -e "${DIM}  Packages will be removed with their dependencies.${RESET}"
fi
if [ ${#SELECTED_WEBAPPS[@]} -gt 0 ]; then
    echo -e "${DIM}  Web apps will be removed via omarchy-webapp-remove.${RESET}"
fi
echo
echo
printf "  ${BOLD}Continue?${RESET} ${DIM}(yes/no)${RESET} "
read -r < /dev/tty

if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo
    echo "  Cancelled."
    echo
    exit 0
fi

# Remove items
echo
TOTAL_ATTEMPTED=0
TOTAL_FAILED=0

# Remove packages one by one
if [ ${#SELECTED_PACKAGES[@]} -gt 0 ]; then
    echo "  Removing packages..."
    echo

    # Ensure we have sudo credentials before starting
    if ! sudo -n true 2>/dev/null; then
        echo -e "  ${DIM}Administrator privileges required for package removal${RESET}"
        if ! sudo true; then
            echo "  Failed to obtain sudo privileges"
            exit 1
        fi
        echo
    fi

    local_current=0
    local_total=${#SELECTED_PACKAGES[@]}

    for pkg in "${SELECTED_PACKAGES[@]}"; do
        ((local_current++))
        ((TOTAL_ATTEMPTED++))

        echo -e "  ${DIM}[$local_current/$local_total]${RESET} Removing $pkg..."

        if sudo pacman -Rns --noconfirm "$pkg" 2>/dev/null; then
            echo -e "    ${CHECKED}✓${RESET}  Removed: $pkg"
            SUMMARY_LOG+=("✓  Removed package: $pkg")
        else
            echo -e "    ${DIM}✗${RESET}  Failed: $pkg (may have dependencies)"
            SUMMARY_LOG+=("✗  Failed to remove package: $pkg")
            ((TOTAL_FAILED++))
        fi
    done
    echo
fi

# Remove webapps one by one
if [ ${#SELECTED_WEBAPPS[@]} -gt 0 ]; then
    echo "  Removing web apps..."
    echo

    local_current=0
    local_total=${#SELECTED_WEBAPPS[@]}

    for webapp in "${SELECTED_WEBAPPS[@]}"; do
        ((local_current++))
        ((TOTAL_ATTEMPTED++))

        echo -e "  ${DIM}[$local_current/$local_total]${RESET} Removing $webapp..."

        if omarchy-webapp-remove "$webapp" >/dev/null 2>&1; then
            echo -e "    ${CHECKED}✓${RESET}  Removed: $webapp"
            SUMMARY_LOG+=("✓  Removed web app: $webapp")
        else
            echo -e "    ${DIM}✗${RESET}  Failed: $webapp"
            SUMMARY_LOG+=("✗  Failed to remove web app: $webapp")
            ((TOTAL_FAILED++))
        fi
    done
    echo
fi

# Summary
TOTAL_SUCCESS=$((TOTAL_ATTEMPTED - TOTAL_FAILED))

trap - EXIT
clear
echo
echo
echo -e "${BOLD}  Summary${RESET}"
echo

for entry in "${SUMMARY_LOG[@]}"; do
    echo -e "  $entry"
done

echo
if [ $TOTAL_FAILED -eq 0 ]; then
    echo -e "  ${CHECKED}All $TOTAL_ATTEMPTED item(s) removed successfully.${RESET}"
    if [ ${#SELECTED_PACKAGES[@]} -gt 0 ]; then
        echo
        echo -e "  ${DIM}Optionally, clean your package cache:${RESET}"
        echo "  sudo pacman -Sc"
    fi
elif [ $TOTAL_SUCCESS -gt 0 ]; then
    echo -e "  ⚠  $TOTAL_SUCCESS of $TOTAL_ATTEMPTED item(s) removed. $TOTAL_FAILED failed."
else
    echo -e "  ✗  Could not remove any items. Check dependencies and permissions."
fi
echo
echo
