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

# Waybar config path
WAYBAR_CONF="$HOME/.config/waybar/config.jsonc"

# Hyprland looknfeel config path
LOOKNFEEL_CONF="$HOME/.config/hypr/looknfeel.conf"

# UWSM defaults config path
UWSM_DEFAULT="$HOME/.config/uwsm/default"

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

# Function to restore close window to SUPER+W (Omarchy default)
restore_close_window() {
    clear
    echo
    echo
    echo -e "${BOLD}  Restore Close Window${RESET}"
    echo
    echo -e "  ${DIM}Restores SUPER+W (Omarchy default) for closing windows.${RESET}"
    echo
    echo

    if [[ ! -f "$TILING_CONF" ]]; then
        echo -e "  ${DIM}✗${RESET}  tiling-v2.conf not found at $TILING_CONF"
        echo
        SUMMARY_LOG+=("✗  Restore close window -- failed (config not found)")
        return 1
    fi

    # Check if already set to SUPER+W
    if grep -q "SUPER, W, Close window, killactive" "$TILING_CONF"; then
        echo -e "  ${DIM}Already set to SUPER+W. Nothing to do.${RESET}"
        echo
        SUMMARY_LOG+=("--  Restore close window -- already set")
        return 0
    fi

    printf "  ${BOLD}Continue?${RESET} ${DIM}(yes/no)${RESET} "
    read -r < /dev/tty

    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo
        echo "  Cancelled."
        echo
        SUMMARY_LOG+=("--  Restore close window -- cancelled")
        return 0
    fi

    echo

    # Create backup
    local backup_file="${TILING_CONF}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$TILING_CONF" "$backup_file"
    echo -e "    ${DIM}Backup saved: $backup_file${RESET}"

    # Replace SUPER, Q with SUPER, W for killactive
    sed -i 's/bindd = SUPER, Q, Close window, killactive,/bindd = SUPER, W, Close window, killactive,/' "$TILING_CONF"

    echo -e "    ${CHECKED}✓${RESET}  Close window restored to SUPER+W"
    SUMMARY_LOG+=("✓  Restore close window to SUPER+W")
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

enable_fido2() {
    clear
    echo
    echo
    echo -e "${BOLD}  Enable FIDO2 Authentication${RESET}"
    echo
    echo -e "  ${DIM}Sets up FIDO2 security key for sudo authentication.${RESET}"
    echo -e "  ${DIM}Works for: sudo and polkit prompts (not lock screen).${RESET}"
    echo
    echo -e "  ${DIM}Note: Requires a FIDO2 device (YubiKey, etc) plugged in.${RESET}"
    echo
    echo

    # Check if already enabled (pam-u2f installed)
    if pacman -Qi pam-u2f &>/dev/null; then
        echo -e "  ${DIM}FIDO2 authentication already set up.${RESET}"
        echo -e "  ${DIM}To re-register, disable first then enable again.${RESET}"
        echo
        SUMMARY_LOG+=("--  Enable FIDO2 -- already enabled")
        return 0
    fi

    printf "  ${BOLD}Continue?${RESET} ${DIM}(yes/no)${RESET} "
    read -r < /dev/tty

    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo
        echo "  Cancelled."
        echo
        SUMMARY_LOG+=("--  Enable FIDO2 -- cancelled")
        return 0
    fi

    echo
    echo -e "  ${DIM}Running omarchy-setup-fido2...${RESET}"
    echo

    # Run the setup script
    if omarchy-setup-fido2; then
        echo
        echo -e "  ${CHECKED}✓${RESET}  FIDO2 authentication enabled"
        SUMMARY_LOG+=("✓  Enabled FIDO2 authentication")
    else
        echo
        echo -e "  ${DIM}FIDO2 setup failed or was cancelled.${RESET}"
        SUMMARY_LOG+=("--  Enable FIDO2 -- failed or cancelled")
    fi
    echo
}

disable_fido2() {
    clear
    echo
    echo
    echo -e "${BOLD}  Disable FIDO2 Authentication${RESET}"
    echo
    echo -e "  ${DIM}Removes FIDO2 authentication and uninstalls packages.${RESET}"
    echo
    echo

    # Check if FIDO2 is enabled
    if ! pacman -Qi pam-u2f &>/dev/null; then
        echo -e "  ${DIM}FIDO2 authentication not set up. Nothing to do.${RESET}"
        echo
        SUMMARY_LOG+=("--  Disable FIDO2 -- not enabled")
        return 0
    fi

    printf "  ${BOLD}Continue?${RESET} ${DIM}(yes/no)${RESET} "
    read -r < /dev/tty

    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo
        echo "  Cancelled."
        echo
        SUMMARY_LOG+=("--  Disable FIDO2 -- cancelled")
        return 0
    fi

    echo
    echo -e "  ${DIM}Running omarchy-setup-fido2 --remove...${RESET}"
    echo

    # Run the remove script
    if omarchy-setup-fido2 --remove; then
        echo
        echo -e "  ${CHECKED}✓${RESET}  FIDO2 authentication disabled"
        SUMMARY_LOG+=("✓  Disabled FIDO2 authentication")
    else
        echo
        echo -e "  ${DIM}FIDO2 removal failed.${RESET}"
        SUMMARY_LOG+=("--  Disable FIDO2 -- failed")
    fi
    echo
}

show_all_tray_icons() {
    clear
    echo
    echo
    echo -e "${BOLD}  Show All Tray Icons${RESET}"
    echo
    echo -e "  ${DIM}Reveals all system tray icons (Dropbox, 1Password, Steam, etc).${RESET}"
    echo -e "  ${DIM}Icons will always be visible instead of hidden under an expander.${RESET}"
    echo
    echo

    if [[ ! -f "$WAYBAR_CONF" ]]; then
        echo -e "  ${DIM}✗${RESET}  waybar config not found at $WAYBAR_CONF"
        echo
        SUMMARY_LOG+=("✗  Show all tray icons -- failed (config not found)")
        return 1
    fi

    # Check if already showing all icons (look for "tray", in modules-right, not the group definition)
    # The group definition has "group/tray-expander": (with colon), modules-right has "group/tray-expander", (with comma)
    if ! grep -q '"group/tray-expander",' "$WAYBAR_CONF"; then
        echo -e "  ${DIM}Tray icons already visible (or tray-expander not in modules).${RESET}"
        echo
        SUMMARY_LOG+=("--  Show all tray icons -- already set or not applicable")
        return 0
    fi

    printf "  ${BOLD}Continue?${RESET} ${DIM}(yes/no)${RESET} "
    read -r < /dev/tty

    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo
        echo "  Cancelled."
        echo
        SUMMARY_LOG+=("--  Show all tray icons -- cancelled")
        return 0
    fi

    echo

    # Create backup
    local backup_file="${WAYBAR_CONF}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$WAYBAR_CONF" "$backup_file"
    echo -e "  ${DIM}Backup: $backup_file${RESET}"

    # Replace group/tray-expander with tray (only the one with comma, not the group definition with colon)
    sed -i 's/"group\/tray-expander",/"tray",/' "$WAYBAR_CONF"

    # Restart waybar to apply
    if command -v omarchy-restart-waybar &>/dev/null; then
        omarchy-restart-waybar &>/dev/null || true
    fi

    echo -e "  ${CHECKED}✓${RESET}  All tray icons now visible"
    SUMMARY_LOG+=("✓  Showing all tray icons")
    echo
}

hide_tray_icons() {
    clear
    echo
    echo
    echo -e "${BOLD}  Hide Tray Icons (Use Expander)${RESET}"
    echo
    echo -e "  ${DIM}Hides tray icons under an expander (Omarchy default).${RESET}"
    echo -e "  ${DIM}Click the expander icon to reveal tray icons when needed.${RESET}"
    echo
    echo

    if [[ ! -f "$WAYBAR_CONF" ]]; then
        echo -e "  ${DIM}✗${RESET}  waybar config not found at $WAYBAR_CONF"
        echo
        SUMMARY_LOG+=("✗  Hide tray icons -- failed (config not found)")
        return 1
    fi

    # Check if already using expander (with comma = in modules-right, not the group definition with colon)
    if grep -q '"group/tray-expander",' "$WAYBAR_CONF"; then
        echo -e "  ${DIM}Already using tray expander. Nothing to do.${RESET}"
        echo
        SUMMARY_LOG+=("--  Hide tray icons -- already set")
        return 0
    fi

    # Check if "tray", exists in modules-right (indicates it was changed from expander)
    if ! grep -q '"tray",' "$WAYBAR_CONF"; then
        echo -e "  ${DIM}tray not found in modules-right. Nothing to do.${RESET}"
        echo
        SUMMARY_LOG+=("--  Hide tray icons -- tray not found")
        return 0
    fi

    printf "  ${BOLD}Continue?${RESET} ${DIM}(yes/no)${RESET} "
    read -r < /dev/tty

    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo
        echo "  Cancelled."
        echo
        SUMMARY_LOG+=("--  Hide tray icons -- cancelled")
        return 0
    fi

    echo

    # Create backup
    local backup_file="${WAYBAR_CONF}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$WAYBAR_CONF" "$backup_file"
    echo -e "  ${DIM}Backup: $backup_file${RESET}"

    # Replace tray with group/tray-expander (only in modules-right context)
    sed -i 's/"tray",/"group\/tray-expander",/' "$WAYBAR_CONF"

    # Restart waybar to apply
    if command -v omarchy-restart-waybar &>/dev/null; then
        omarchy-restart-waybar &>/dev/null || true
    fi

    echo -e "  ${CHECKED}✓${RESET}  Tray icons now hidden under expander"
    SUMMARY_LOG+=("✓  Hiding tray icons (using expander)")
    echo
}

enable_rounded_corners() {
    clear
    echo
    echo
    echo -e "${BOLD}  Enable Rounded Window Corners${RESET}"
    echo
    echo -e "  ${DIM}Adds rounded corners to all windows (rounding = 8).${RESET}"
    echo
    echo

    if [[ ! -f "$LOOKNFEEL_CONF" ]]; then
        echo -e "  ${DIM}✗${RESET}  looknfeel.conf not found at $LOOKNFEEL_CONF"
        echo
        SUMMARY_LOG+=("✗  Enable rounded corners -- failed (config not found)")
        return 1
    fi

    # Check if already enabled (uncommented rounding line)
    if grep -q "^[[:space:]]*rounding = " "$LOOKNFEEL_CONF"; then
        echo -e "  ${DIM}Rounded corners already enabled. Nothing to do.${RESET}"
        echo
        SUMMARY_LOG+=("--  Enable rounded corners -- already enabled")
        return 0
    fi

    # Check if commented rounding line exists
    if ! grep -q "^[[:space:]]*#[[:space:]]*rounding = " "$LOOKNFEEL_CONF"; then
        echo -e "  ${DIM}rounding setting not found in config. Nothing to do.${RESET}"
        echo
        SUMMARY_LOG+=("--  Enable rounded corners -- setting not found")
        return 0
    fi

    printf "  ${BOLD}Continue?${RESET} ${DIM}(yes/no)${RESET} "
    read -r < /dev/tty

    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo
        echo "  Cancelled."
        echo
        SUMMARY_LOG+=("--  Enable rounded corners -- cancelled")
        return 0
    fi

    echo

    # Create backup
    local backup_file="${LOOKNFEEL_CONF}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$LOOKNFEEL_CONF" "$backup_file"
    echo -e "  ${DIM}Backup: $backup_file${RESET}"

    # Uncomment the rounding line
    sed -i 's/^[[:space:]]*#[[:space:]]*\(rounding = .*\)/    \1/' "$LOOKNFEEL_CONF"

    echo -e "  ${CHECKED}✓${RESET}  Rounded window corners enabled"
    SUMMARY_LOG+=("✓  Enabled rounded window corners")
    echo
    echo -e "  ${DIM}Hyprland will auto-reload the config.${RESET}"
    echo
}

disable_rounded_corners() {
    clear
    echo
    echo
    echo -e "${BOLD}  Disable Rounded Window Corners${RESET}"
    echo
    echo -e "  ${DIM}Returns to sharp/square window corners (Omarchy default).${RESET}"
    echo
    echo

    if [[ ! -f "$LOOKNFEEL_CONF" ]]; then
        echo -e "  ${DIM}✗${RESET}  looknfeel.conf not found at $LOOKNFEEL_CONF"
        echo
        SUMMARY_LOG+=("✗  Disable rounded corners -- failed (config not found)")
        return 1
    fi

    # Check if rounding is enabled (uncommented)
    if ! grep -q "^[[:space:]]*rounding = " "$LOOKNFEEL_CONF"; then
        echo -e "  ${DIM}Rounded corners already disabled. Nothing to do.${RESET}"
        echo
        SUMMARY_LOG+=("--  Disable rounded corners -- already disabled")
        return 0
    fi

    printf "  ${BOLD}Continue?${RESET} ${DIM}(yes/no)${RESET} "
    read -r < /dev/tty

    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo
        echo "  Cancelled."
        echo
        SUMMARY_LOG+=("--  Disable rounded corners -- cancelled")
        return 0
    fi

    echo

    # Create backup
    local backup_file="${LOOKNFEEL_CONF}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$LOOKNFEEL_CONF" "$backup_file"
    echo -e "  ${DIM}Backup: $backup_file${RESET}"

    # Comment out the rounding line
    sed -i 's/^[[:space:]]*\(rounding = .*\)/    # \1/' "$LOOKNFEEL_CONF"

    echo -e "  ${CHECKED}✓${RESET}  Rounded window corners disabled"
    SUMMARY_LOG+=("✓  Disabled rounded window corners")
    echo
    echo -e "  ${DIM}Hyprland will auto-reload the config.${RESET}"
    echo
}

remove_window_gaps() {
    clear
    echo
    echo
    echo -e "${BOLD}  Remove Window Gaps${RESET}"
    echo
    echo -e "  ${DIM}Removes all gaps between windows and borders.${RESET}"
    echo -e "  ${DIM}Maximizes screen space - great for laptops.${RESET}"
    echo
    echo

    if [[ ! -f "$LOOKNFEEL_CONF" ]]; then
        echo -e "  ${DIM}✗${RESET}  looknfeel.conf not found at $LOOKNFEEL_CONF"
        echo
        SUMMARY_LOG+=("✗  Remove window gaps -- failed (config not found)")
        return 1
    fi

    # Check if already enabled (uncommented gaps_in line)
    if grep -q "^[[:space:]]*gaps_in = 0" "$LOOKNFEEL_CONF"; then
        echo -e "  ${DIM}Window gaps already removed. Nothing to do.${RESET}"
        echo
        SUMMARY_LOG+=("--  Remove window gaps -- already removed")
        return 0
    fi

    # Check if commented gaps lines exist
    if ! grep -q "^[[:space:]]*#[[:space:]]*gaps_in = 0" "$LOOKNFEEL_CONF"; then
        echo -e "  ${DIM}gaps settings not found in config. Nothing to do.${RESET}"
        echo
        SUMMARY_LOG+=("--  Remove window gaps -- settings not found")
        return 0
    fi

    printf "  ${BOLD}Continue?${RESET} ${DIM}(yes/no)${RESET} "
    read -r < /dev/tty

    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo
        echo "  Cancelled."
        echo
        SUMMARY_LOG+=("--  Remove window gaps -- cancelled")
        return 0
    fi

    echo

    # Create backup
    local backup_file="${LOOKNFEEL_CONF}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$LOOKNFEEL_CONF" "$backup_file"
    echo -e "  ${DIM}Backup: $backup_file${RESET}"

    # Uncomment the gaps and border lines
    sed -i 's/^[[:space:]]*#[[:space:]]*\(gaps_in = 0\)/    \1/' "$LOOKNFEEL_CONF"
    sed -i 's/^[[:space:]]*#[[:space:]]*\(gaps_out = 0\)/    \1/' "$LOOKNFEEL_CONF"
    sed -i 's/^[[:space:]]*#[[:space:]]*\(border_size = 0\)/    \1/' "$LOOKNFEEL_CONF"

    echo -e "  ${CHECKED}✓${RESET}  Window gaps removed"
    SUMMARY_LOG+=("✓  Removed window gaps")
    echo
    echo -e "  ${DIM}Hyprland will auto-reload the config.${RESET}"
    echo
}

restore_window_gaps() {
    clear
    echo
    echo
    echo -e "${BOLD}  Restore Window Gaps${RESET}"
    echo
    echo -e "  ${DIM}Restores gaps between windows and borders (Omarchy default).${RESET}"
    echo
    echo

    if [[ ! -f "$LOOKNFEEL_CONF" ]]; then
        echo -e "  ${DIM}✗${RESET}  looknfeel.conf not found at $LOOKNFEEL_CONF"
        echo
        SUMMARY_LOG+=("✗  Restore window gaps -- failed (config not found)")
        return 1
    fi

    # Check if gaps are removed (uncommented)
    if ! grep -q "^[[:space:]]*gaps_in = 0" "$LOOKNFEEL_CONF"; then
        echo -e "  ${DIM}Window gaps already restored. Nothing to do.${RESET}"
        echo
        SUMMARY_LOG+=("--  Restore window gaps -- already restored")
        return 0
    fi

    printf "  ${BOLD}Continue?${RESET} ${DIM}(yes/no)${RESET} "
    read -r < /dev/tty

    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo
        echo "  Cancelled."
        echo
        SUMMARY_LOG+=("--  Restore window gaps -- cancelled")
        return 0
    fi

    echo

    # Create backup
    local backup_file="${LOOKNFEEL_CONF}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$LOOKNFEEL_CONF" "$backup_file"
    echo -e "  ${DIM}Backup: $backup_file${RESET}"

    # Comment out the gaps and border lines
    sed -i 's/^[[:space:]]*\(gaps_in = 0\)/    # \1/' "$LOOKNFEEL_CONF"
    sed -i 's/^[[:space:]]*\(gaps_out = 0\)/    # \1/' "$LOOKNFEEL_CONF"
    sed -i 's/^[[:space:]]*\(border_size = 0\)/    # \1/' "$LOOKNFEEL_CONF"

    echo -e "  ${CHECKED}✓${RESET}  Window gaps restored"
    SUMMARY_LOG+=("✓  Restored window gaps")
    echo
    echo -e "  ${DIM}Hyprland will auto-reload the config.${RESET}"
    echo
}

enable_12h_clock() {
    clear
    echo
    echo
    echo -e "${BOLD}  Enable 12-Hour Clock${RESET}"
    echo
    echo -e "  ${DIM}Changes the waybar clock to 12-hour format with AM/PM.${RESET}"
    echo -e "  ${DIM}Example: \"Sunday 10:55 AM\"${RESET}"
    echo
    echo

    if [[ ! -f "$WAYBAR_CONF" ]]; then
        echo -e "  ${DIM}✗${RESET}  waybar config not found at $WAYBAR_CONF"
        echo
        SUMMARY_LOG+=("✗  Enable 12h clock -- failed (config not found)")
        return 1
    fi

    # Check if already using 12-hour format
    if grep -q '%I:%M %p' "$WAYBAR_CONF"; then
        echo -e "  ${DIM}Already using 12-hour clock. Nothing to do.${RESET}"
        echo
        SUMMARY_LOG+=("--  Enable 12h clock -- already set")
        return 0
    fi

    # Check if 24-hour format exists
    if ! grep -q '%H:%M' "$WAYBAR_CONF"; then
        echo -e "  ${DIM}24-hour clock format not found. Nothing to do.${RESET}"
        echo
        SUMMARY_LOG+=("--  Enable 12h clock -- 24h format not found")
        return 0
    fi

    printf "  ${BOLD}Continue?${RESET} ${DIM}(yes/no)${RESET} "
    read -r < /dev/tty

    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo
        echo "  Cancelled."
        echo
        SUMMARY_LOG+=("--  Enable 12h clock -- cancelled")
        return 0
    fi

    echo

    # Create backup
    local backup_file="${WAYBAR_CONF}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$WAYBAR_CONF" "$backup_file"
    echo -e "  ${DIM}Backup: $backup_file${RESET}"

    # Replace 24-hour format with 12-hour format
    sed -i 's/%H:%M/%I:%M %p/g' "$WAYBAR_CONF"

    # Restart waybar to apply
    if command -v omarchy-restart-waybar &>/dev/null; then
        omarchy-restart-waybar &>/dev/null || true
    fi

    echo -e "  ${CHECKED}✓${RESET}  12-hour clock enabled"
    SUMMARY_LOG+=("✓  Enabled 12-hour clock")
    echo
}

disable_12h_clock() {
    clear
    echo
    echo
    echo -e "${BOLD}  Disable 12-Hour Clock${RESET}"
    echo
    echo -e "  ${DIM}Changes the waybar clock back to 24-hour format.${RESET}"
    echo -e "  ${DIM}Example: \"Sunday 22:55\"${RESET}"
    echo
    echo

    if [[ ! -f "$WAYBAR_CONF" ]]; then
        echo -e "  ${DIM}✗${RESET}  waybar config not found at $WAYBAR_CONF"
        echo
        SUMMARY_LOG+=("✗  Disable 12h clock -- failed (config not found)")
        return 1
    fi

    # Check if using 12-hour format
    if ! grep -q '%I:%M %p' "$WAYBAR_CONF"; then
        echo -e "  ${DIM}Already using 24-hour clock. Nothing to do.${RESET}"
        echo
        SUMMARY_LOG+=("--  Disable 12h clock -- already set")
        return 0
    fi

    printf "  ${BOLD}Continue?${RESET} ${DIM}(yes/no)${RESET} "
    read -r < /dev/tty

    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo
        echo "  Cancelled."
        echo
        SUMMARY_LOG+=("--  Disable 12h clock -- cancelled")
        return 0
    fi

    echo

    # Create backup
    local backup_file="${WAYBAR_CONF}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$WAYBAR_CONF" "$backup_file"
    echo -e "  ${DIM}Backup: $backup_file${RESET}"

    # Replace 12-hour format with 24-hour format
    sed -i 's/%I:%M %p/%H:%M/g' "$WAYBAR_CONF"

    # Restart waybar to apply
    if command -v omarchy-restart-waybar &>/dev/null; then
        omarchy-restart-waybar &>/dev/null || true
    fi

    echo -e "  ${CHECKED}✓${RESET}  24-hour clock restored"
    SUMMARY_LOG+=("✓  Restored 24-hour clock")
    echo
}

enable_media_directories() {
    clear
    echo
    echo
    echo -e "${BOLD}  Enable Screenshot/Recording Directories${RESET}"
    echo
    echo -e "  ${DIM}Saves screenshots and recordings to dedicated folders:${RESET}"
    echo -e "  ${DIM}  • Screenshots → ~/Pictures/Screenshots${RESET}"
    echo -e "  ${DIM}  • Recordings → ~/Videos/Screencasts${RESET}"
    echo
    echo -e "  ${DIM}Note: Requires Omarchy restart to take effect.${RESET}"
    echo
    echo

    if [[ ! -f "$UWSM_DEFAULT" ]]; then
        echo -e "  ${DIM}✗${RESET}  uwsm default config not found at $UWSM_DEFAULT"
        echo
        SUMMARY_LOG+=("✗  Enable media directories -- failed (config not found)")
        return 1
    fi

    # Check if already enabled (uncommented lines)
    if grep -q '^export OMARCHY_SCREENSHOT_DIR=' "$UWSM_DEFAULT"; then
        echo -e "  ${DIM}Media directories already enabled. Nothing to do.${RESET}"
        echo
        SUMMARY_LOG+=("--  Enable media directories -- already enabled")
        return 0
    fi

    # Check if commented lines exist
    if ! grep -q '^#.*export OMARCHY_SCREENSHOT_DIR=' "$UWSM_DEFAULT"; then
        echo -e "  ${DIM}Screenshot directory setting not found. Nothing to do.${RESET}"
        echo
        SUMMARY_LOG+=("--  Enable media directories -- settings not found")
        return 0
    fi

    printf "  ${BOLD}Continue?${RESET} ${DIM}(yes/no)${RESET} "
    read -r < /dev/tty

    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo
        echo "  Cancelled."
        echo
        SUMMARY_LOG+=("--  Enable media directories -- cancelled")
        return 0
    fi

    echo

    # Create backup
    local backup_file="${UWSM_DEFAULT}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$UWSM_DEFAULT" "$backup_file"
    echo -e "  ${DIM}Backup: $backup_file${RESET}"

    # Create the directories
    mkdir -p "$HOME/Pictures/Screenshots"
    mkdir -p "$HOME/Videos/Screencasts"
    echo -e "  ${DIM}Created ~/Pictures/Screenshots${RESET}"
    echo -e "  ${DIM}Created ~/Videos/Screencasts${RESET}"

    # Uncomment the export lines
    sed -i 's/^# *\(export OMARCHY_SCREENSHOT_DIR=.*\)/\1/' "$UWSM_DEFAULT"
    sed -i 's/^# *\(export OMARCHY_SCREENRECORD_DIR=.*\)/\1/' "$UWSM_DEFAULT"

    echo -e "  ${CHECKED}✓${RESET}  Media directories enabled"
    SUMMARY_LOG+=("✓  Enabled screenshot/recording directories")
    echo
    echo -e "  ${DIM}Restart Omarchy for changes to take effect.${RESET}"
    echo
}

disable_media_directories() {
    clear
    echo
    echo
    echo -e "${BOLD}  Disable Screenshot/Recording Directories${RESET}"
    echo
    echo -e "  ${DIM}Returns to default behavior (saves to ~/Pictures and ~/Videos).${RESET}"
    echo
    echo -e "  ${DIM}Note: Requires Omarchy restart to take effect.${RESET}"
    echo
    echo

    if [[ ! -f "$UWSM_DEFAULT" ]]; then
        echo -e "  ${DIM}✗${RESET}  uwsm default config not found at $UWSM_DEFAULT"
        echo
        SUMMARY_LOG+=("✗  Disable media directories -- failed (config not found)")
        return 1
    fi

    # Check if enabled (uncommented lines)
    if ! grep -q '^export OMARCHY_SCREENSHOT_DIR=' "$UWSM_DEFAULT"; then
        echo -e "  ${DIM}Media directories already disabled. Nothing to do.${RESET}"
        echo
        SUMMARY_LOG+=("--  Disable media directories -- already disabled")
        return 0
    fi

    printf "  ${BOLD}Continue?${RESET} ${DIM}(yes/no)${RESET} "
    read -r < /dev/tty

    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo
        echo "  Cancelled."
        echo
        SUMMARY_LOG+=("--  Disable media directories -- cancelled")
        return 0
    fi

    echo

    # Create backup
    local backup_file="${UWSM_DEFAULT}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$UWSM_DEFAULT" "$backup_file"
    echo -e "  ${DIM}Backup: $backup_file${RESET}"

    # Comment out the export lines
    sed -i 's/^\(export OMARCHY_SCREENSHOT_DIR=.*\)/# \1/' "$UWSM_DEFAULT"
    sed -i 's/^\(export OMARCHY_SCREENRECORD_DIR=.*\)/# \1/' "$UWSM_DEFAULT"

    echo -e "  ${CHECKED}✓${RESET}  Media directories disabled"
    SUMMARY_LOG+=("✓  Disabled screenshot/recording directories")
    echo
    echo -e "  ${DIM}Restart Omarchy for changes to take effect.${RESET}"
    echo
}

# =============================================================================
# TWO-PANEL TUI DATA STRUCTURES
# =============================================================================

# Categories for left panel (lines starting with "---" are section headers)
declare -a CATEGORIES=(
    "--- Uninstall ---"
    "  Apps"
    "  Web Apps"
    "--- Tweaks ---"
    "  Keybindings"
    "  Display"
    "  System"
    "  Appearance"
    "  Keyboard"
    "  Utilities"
)

# Check if a category index is a section header
is_section_header() {
    [[ "${CATEGORIES[$1]}" == ---* ]]
}

# Build installed packages list
declare -a INSTALLED_PACKAGES=()
for pkg in "${DEFAULT_APPS[@]}"; do
    if is_package_installed "$pkg"; then
        INSTALLED_PACKAGES+=("$pkg")
    fi
done

# Build installed webapps list
declare -a INSTALLED_WEBAPPS=()
for webapp in "${DEFAULT_WEBAPPS[@]}"; do
    if is_webapp_installed "$webapp"; then
        INSTALLED_WEBAPPS+=("$webapp")
    fi
done

# Toggle pairs: each entry is "item_id|display_name|option1|option2|type"
# type: "toggle" for enable/disable pairs, "radio" for mutually exclusive options
# Format: "id|name|opt1|opt2|type|description"
declare -a KEYBINDINGS_ITEMS=(
    "close_window|Close window|SUPER+Q|SUPER+W|radio|Choose which key combo closes the active window"
    "shutdown|Shutdown|Bind|Unbind|toggle|Bind SUPER+ALT+S to shutdown the system"
    "restart|Restart|Bind|Unbind|toggle|Bind SUPER+ALT+R to restart the system"
    "theme_menu|Theme menu|Bind|Unbind|toggle|Bind ALT+T to open the theme selector"
)

declare -a DISPLAY_ITEMS=(
    "monitor_scale|Monitor scale|4K|1080p/1440p|radio|Set monitor scaling for your resolution"
)

declare -a SYSTEM_ITEMS=(
    "suspend|Suspend|Enable|Disable|toggle|Allow system to suspend/sleep when idle"
    "hibernation|Hibernation|Enable|Disable|toggle|Allow system to hibernate to disk"
    "fingerprint|Fingerprint|Enable|Disable|toggle|Enable fingerprint authentication for login"
    "fido2|FIDO2|Enable|Disable|toggle|Enable FIDO2 security key authentication"
)

declare -a APPEARANCE_ITEMS=(
    "rounded_corners|Rounded corners|Enable|Disable|toggle|Enable or disable rounded window corners"
    "window_gaps|Window gaps|Remove|Restore|toggle|Remove or restore gaps between tiled windows"
    "tray_icons|Tray icons|Show all|Hide|toggle|Show all system tray icons or hide extras"
    "clock_format|Clock format|12h|24h|radio|Set waybar clock to 12-hour or 24-hour format"
    "media_dirs|Media dirs|Enable|Disable|toggle|Organize screenshots and recordings into subdirs"
)

declare -a KEYBOARD_ITEMS=(
    "caps_lock|Caps Lock|Normal|Compose|radio|Use Caps Lock normally or as Compose key"
    "alt_super|Alt/Super|Swap|Normal|radio|Swap Alt and Super keys (useful for Mac keyboards)"
)

declare -a UTILITIES_ITEMS=(
    "backup_config|Backup config|[Select]||action|Create a backup of your Omarchy configuration"
)

# Descriptions for packages (shown when highlighted)
declare -A PKG_DESCRIPTIONS=(
    ["1password-beta"]="Password manager (beta version)"
    ["1password-cli"]="1Password command-line tool"
    ["docker"]="Container runtime for running isolated apps"
    ["docker-buildx"]="Docker CLI plugin for extended builds"
    ["docker-compose"]="Multi-container Docker orchestration"
    ["gnome-calculator"]="GNOME desktop calculator app"
    ["kdenlive"]="Professional video editing software"
    ["libreoffice-fresh"]="Full office suite (docs, sheets, slides)"
    ["localsend"]="Share files to nearby devices over WiFi"
    ["obs-studio"]="Screen recording and streaming software"
    ["obsidian"]="Markdown-based note-taking app"
    ["omarchy-chromium"]="Chromium web browser"
    ["pinta"]="Simple image editing program"
    ["signal-desktop"]="Encrypted messaging app"
    ["spotify"]="Music streaming service"
    ["typora"]="Markdown editor"
    ["xournalpp"]="Handwriting and PDF annotation app"
)

# Descriptions for webapps
declare -A WEBAPP_DESCRIPTIONS=(
    ["basecamp"]="Project management and team communication"
    ["chatgpt"]="OpenAI's AI chat assistant"
    ["discord"]="Voice, video and text communication"
    ["figma"]="Collaborative design tool"
    ["fizzy"]="Sparkling water tracking app"
    ["github"]="Code hosting and collaboration platform"
    ["google-contacts"]="Google contacts manager"
    ["google-maps"]="Google maps and navigation"
    ["google-messages"]="Google SMS/RCS messaging"
    ["google-photos"]="Google photo storage and sharing"
    ["hey"]="Email service by Basecamp"
    ["whatsapp"]="Encrypted messaging app"
    ["x"]="Social media platform (formerly Twitter)"
    ["youtube"]="Video streaming platform"
    ["zoom"]="Video conferencing software"
)

# Selection state for toggle items: 0=none, 1=option1, 2=option2
declare -A TOGGLE_SELECTIONS=()

# Selection state for packages/webapps (by name)
declare -A PKG_SELECTIONS=()
declare -A WEBAPP_SELECTIONS=()

# Navigation state
CURRENT_PANEL=0          # 0=left (categories), 1=right (items)
CATEGORY_CURSOR=1        # Current category in left panel (start at first non-header)
ITEM_CURSOR=0            # Current item in right panel
ITEM_SCROLL_OFFSET=0     # Scroll offset for right panel

# =============================================================================
# HELPER FUNCTIONS FOR TWO-PANEL UI
# =============================================================================

# Get items array for a category
get_category_items() {
    local cat_idx=$1
    # Section headers (0, 3) have no items
    case $cat_idx in
        1) echo "PACKAGES" ;;
        2) echo "WEBAPPS" ;;
        4) echo "KEYBINDINGS" ;;
        5) echo "DISPLAY" ;;
        6) echo "SYSTEM" ;;
        7) echo "APPEARANCE" ;;
        8) echo "KEYBOARD" ;;
        9) echo "UTILITIES" ;;
    esac
}

# Get item count for current category
get_current_item_count() {
    # Section headers (0, 3) return 0
    case $CATEGORY_CURSOR in
        0|3) echo 0 ;;
        1) echo ${#INSTALLED_PACKAGES[@]} ;;
        2) echo ${#INSTALLED_WEBAPPS[@]} ;;
        4) echo ${#KEYBINDINGS_ITEMS[@]} ;;
        5) echo ${#DISPLAY_ITEMS[@]} ;;
        6) echo ${#SYSTEM_ITEMS[@]} ;;
        7) echo ${#APPEARANCE_ITEMS[@]} ;;
        8) echo ${#KEYBOARD_ITEMS[@]} ;;
        9) echo ${#UTILITIES_ITEMS[@]} ;;
    esac
}

# Parse toggle item: returns id, name, opt1, opt2, type via global vars
parse_toggle_item() {
    local item="$1"
    IFS='|' read -r TOGGLE_ID TOGGLE_NAME TOGGLE_OPT1 TOGGLE_OPT2 TOGGLE_TYPE TOGGLE_DESC <<< "$item"
}

# Get description for currently highlighted item
get_current_description() {
    local item_count=$(get_current_item_count)
    if [ $item_count -eq 0 ] || [ $ITEM_CURSOR -ge $item_count ]; then
        echo ""
        return
    fi

    case $CATEGORY_CURSOR in
        1)  # Packages
            local pkg="${INSTALLED_PACKAGES[$ITEM_CURSOR]}"
            echo "${PKG_DESCRIPTIONS[$pkg]:-}"
            ;;
        2)  # Webapps
            local webapp="${INSTALLED_WEBAPPS[$ITEM_CURSOR]}"
            echo "${WEBAPP_DESCRIPTIONS[$webapp]:-}"
            ;;
        4|5|6|7|8)  # Toggle items
            local arr
            case $CATEGORY_CURSOR in
                4) arr="KEYBINDINGS_ITEMS" ;; 5) arr="DISPLAY_ITEMS" ;;
                6) arr="SYSTEM_ITEMS" ;; 7) arr="APPEARANCE_ITEMS" ;; 8) arr="KEYBOARD_ITEMS" ;;
            esac
            local -n ref="$arr"
            parse_toggle_item "${ref[$ITEM_CURSOR]}"
            echo "$TOGGLE_DESC"
            ;;
        9)  # Utilities
            parse_toggle_item "${UTILITIES_ITEMS[$ITEM_CURSOR]}"
            echo "$TOGGLE_DESC"
            ;;
        *)
            echo ""
            ;;
    esac
}

# Helper function to center text (truncates to fit terminal width)
center_text() {
    local text="$1"
    local width="${2:-$(tput cols)}"
    local text_length=${#text}
    if [ $text_length -gt $width ]; then
        text="${text:0:$width}"
        text_length=$width
    fi
    local padding=$(( (width - text_length) / 2 ))
    if [ $padding -lt 0 ]; then
        padding=0
    fi
    printf "%*s%s" $padding "" "$text"
}

# Draw a horizontal line with box characters
draw_hline() {
    local width=$1
    local left="$2"
    local right="$3"
    local mid="${4:-}"
    local mid_pos="${5:-0}"

    printf "%s" "$left"
    for ((i=1; i<width-1; i++)); do
        if [ $mid_pos -gt 0 ] && [ $i -eq $mid_pos ]; then
            printf "%s" "$mid"
        else
            printf "─"
        fi
    done
    printf "%s" "$right"
}

# Function to draw the two-panel interface (fixed 80x24 layout)
# Layout: │<-25 chars->│<-52 chars->│ = 80 total
draw_interface() {
    # Fixed dimensions - must match static borders exactly
    local LEFT_W=25
    local RIGHT_W=52
    local ROWS=11

    # Clamp cursors
    local cat_count=${#CATEGORIES[@]}
    (( CATEGORY_CURSOR >= cat_count )) && CATEGORY_CURSOR=$((cat_count - 1))
    (( CATEGORY_CURSOR < 0 )) && CATEGORY_CURSOR=0

    local item_count=$(get_current_item_count)
    (( ITEM_CURSOR >= item_count )) && ITEM_CURSOR=$((item_count - 1))
    (( ITEM_CURSOR < 0 )) && ITEM_CURSOR=0

    # Scroll
    (( ITEM_CURSOR < ITEM_SCROLL_OFFSET )) && ITEM_SCROLL_OFFSET=$ITEM_CURSOR
    (( ITEM_CURSOR >= ITEM_SCROLL_OFFSET + ROWS )) && ITEM_SCROLL_OFFSET=$((ITEM_CURSOR - ROWS + 1))
    (( ITEM_SCROLL_OFFSET < 0 )) && ITEM_SCROLL_OFFSET=0

    clear

    # Header (each line is exactly 80 chars)
    printf '%s\n' "┌──────────────────────────────────────────────────────────────────────────────┐"
    printf "│${BOLD}                            A   L A   C A R C H Y                             ${RESET}│\n"
    printf "│${DIM}                    Omarchy Linux Debloater And Optimizer                     ${RESET}│\n"
    printf "│${DIM}                               by Daniel Coffey                               ${RESET}│\n"
    printf '%s\n' "│                                                                              │"
    printf '%s\n' "├─────────────────────────┬────────────────────────────────────────────────────┤"

    # Get current description for display
    local cur_desc=$(get_current_description)

    # Content rows
    for ((row=0; row<ROWS; row++)); do
        local L="" R=""
        local Lhl=0 Rhl=0

        # Left panel
        local Lsection=0
        if (( row < cat_count )); then
            local cat_text="${CATEGORIES[$row]}"
            if [[ "$cat_text" == ---* ]]; then
                # Section header - will be dimmed at output time
                L=" ${cat_text}"
                Lsection=1
            elif (( row == CATEGORY_CURSOR )); then
                L=" > ${cat_text}"
                (( CURRENT_PANEL == 0 )) && Lhl=1
            else
                L="   ${cat_text}"
            fi
        fi

        # Right panel
        local idx=$((ITEM_SCROLL_OFFSET + row))
        if (( idx < item_count )); then
            (( CURRENT_PANEL == 1 && idx == ITEM_CURSOR )) && Rhl=1
            case $CATEGORY_CURSOR in
                1) local p="${INSTALLED_PACKAGES[$idx]}"
                   [[ "${PKG_SELECTIONS[$p]:-0}" == "1" ]] && R=" [x] $p" || R=" [ ] $p" ;;
                2) local w="${INSTALLED_WEBAPPS[$idx]}"
                   [[ "${WEBAPP_SELECTIONS[$w]:-0}" == "1" ]] && R=" [x] $w" || R=" [ ] $w" ;;
                4|5|6|7|8)
                    local arr
                    case $CATEGORY_CURSOR in
                        4) arr="KEYBINDINGS_ITEMS" ;; 5) arr="DISPLAY_ITEMS" ;;
                        6) arr="SYSTEM_ITEMS" ;; 7) arr="APPEARANCE_ITEMS" ;; 8) arr="KEYBOARD_ITEMS" ;;
                    esac
                    local -n ref="$arr"
                    parse_toggle_item "${ref[$idx]}"
                    R=$(format_toggle_item "$TOGGLE_NAME" "$TOGGLE_OPT1" "$TOGGLE_OPT2" "${TOGGLE_SELECTIONS[$TOGGLE_ID]:-0}") ;;
                9) parse_toggle_item "${UTILITIES_ITEMS[$idx]}"
                   [[ "${TOGGLE_SELECTIONS[$TOGGLE_ID]:-0}" == "1" ]] && R=" [x] $TOGGLE_NAME" || R=" [ ] $TOGGLE_NAME" ;;
            esac
        fi

        # Format cells to exact width
        local Lfmt=$(printf "%-${LEFT_W}.${LEFT_W}s" "$L")
        local Rfmt=$(printf "%-${RIGHT_W}.${RIGHT_W}s" "$R")

        # Output row
        if (( Lhl )); then
            printf "│${SELECTED_BG}%s${RESET}│" "$Lfmt"
        elif (( Lsection )); then
            printf "│${DIM}%s${RESET}│" "$Lfmt"
        else
            printf "│%s│" "$Lfmt"
        fi
        if (( Rhl )); then
            printf "${SELECTED_BG}%s${RESET}│\n" "$Rfmt"
        else
            printf "%s│\n" "$Rfmt"
        fi
    done

    # Description row (always visible, spans full width)
    printf '%s\n' "├─────────────────────────┴────────────────────────────────────────────────────┤"
    if [[ -n "$cur_desc" ]]; then
        # Center the description in 78 chars, dimmed
        local desc_padded=$(printf " %-76s " "${cur_desc:0:76}")
        printf "│${DIM}%s${RESET}│\n" "$desc_padded"
    else
        printf '%s\n' "│                                                                              │"
    fi

    # Footer (each line exactly 80 chars, ASCII only)
    printf '%s\n' "├──────────────────────────────────────────────────────────────────────────────┤"
    printf '%s\n' "│             Arrows:Navigate  Space:Select  Enter:Confirm  Q:Quit             │"
    printf '%s\n' "└──────────────────────────────────────────────────────────────────────────────┘"
}

# Format a toggle item for display (ASCII only, fixed width)
format_toggle_item() {
    local name="$1"
    local opt1="$2"
    local opt2="$3"
    local sel="$4"  # 0=none, 1=opt1, 2=opt2

    if [ -z "$opt2" ]; then
        # Action item (like backup)
        if [ "$sel" -eq 1 ]; then
            printf " [x] %s" "$name"
        else
            printf " [ ] %s" "$name"
        fi
    else
        # Toggle item with two options
        local m1=" " m2=" "
        [ "$sel" -eq 1 ] && m1="*"
        [ "$sel" -eq 2 ] && m2="*"
        printf " %-15s [%s%s] [%s%s]" "$name" "$m1" "$opt1" "$m2" "$opt2"
    fi
}

# Function to handle key input for two-panel navigation
handle_input() {
    local key
    while true; do
        IFS= read -rsn1 -t 1 key < /dev/tty
        local rs=$?
        if [ $rs -le 1 ]; then
            break
        fi
    done

    local item_count=$(get_current_item_count)

    case "$key" in
        $'\x1b')  # ESC sequence
            read -rsn2 -t 0.1 key
            case "$key" in
                '[A')  # Up arrow
                    if [ $CURRENT_PANEL -eq 0 ]; then
                        # Left panel - navigate categories, skip section headers
                        local new_cursor=$((CATEGORY_CURSOR - 1))
                        while [ $new_cursor -ge 0 ] && is_section_header $new_cursor; do
                            ((new_cursor--))
                        done
                        if [ $new_cursor -ge 0 ]; then
                            CATEGORY_CURSOR=$new_cursor
                            ITEM_CURSOR=0
                            ITEM_SCROLL_OFFSET=0
                        fi
                    else
                        # Right panel - navigate items
                        if [ $ITEM_CURSOR -gt 0 ]; then
                            ((ITEM_CURSOR--))
                        fi
                    fi
                    ;;
                '[B')  # Down arrow
                    if [ $CURRENT_PANEL -eq 0 ]; then
                        # Left panel - navigate categories, skip section headers
                        local new_cursor=$((CATEGORY_CURSOR + 1))
                        while [ $new_cursor -lt ${#CATEGORIES[@]} ] && is_section_header $new_cursor; do
                            ((new_cursor++))
                        done
                        if [ $new_cursor -lt ${#CATEGORIES[@]} ]; then
                            CATEGORY_CURSOR=$new_cursor
                            ITEM_CURSOR=0
                            ITEM_SCROLL_OFFSET=0
                        fi
                    else
                        # Right panel - navigate items
                        if [ $ITEM_CURSOR -lt $((item_count - 1)) ]; then
                            ((ITEM_CURSOR++))
                        fi
                    fi
                    ;;
                '[C')  # Right arrow - switch to right panel
                    if [ $CURRENT_PANEL -eq 0 ] && [ $item_count -gt 0 ]; then
                        CURRENT_PANEL=1
                    fi
                    ;;
                '[D')  # Left arrow - switch to left panel
                    if [ $CURRENT_PANEL -eq 1 ]; then
                        CURRENT_PANEL=0
                    fi
                    ;;
            esac
            ;;
        ' ')  # Space - toggle selection
            if [ $CURRENT_PANEL -eq 1 ] && [ $item_count -gt 0 ]; then
                toggle_current_item
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

# Toggle the currently selected item
toggle_current_item() {
    local item_count=$(get_current_item_count)
    if [ $ITEM_CURSOR -ge $item_count ]; then
        return
    fi

    case $CATEGORY_CURSOR in
        1)  # Packages
            local pkg="${INSTALLED_PACKAGES[$ITEM_CURSOR]}"
            local cur="${PKG_SELECTIONS[$pkg]:-0}"
            if [ "$cur" -eq 0 ]; then
                PKG_SELECTIONS[$pkg]=1
            else
                PKG_SELECTIONS[$pkg]=0
            fi
            ;;
        2)  # Webapps
            local webapp="${INSTALLED_WEBAPPS[$ITEM_CURSOR]}"
            local cur="${WEBAPP_SELECTIONS[$webapp]:-0}"
            if [ "$cur" -eq 0 ]; then
                WEBAPP_SELECTIONS[$webapp]=1
            else
                WEBAPP_SELECTIONS[$webapp]=0
            fi
            ;;
        4|5|6|7|8)  # Toggle items (Keybindings, Display, System, Appearance, Keyboard)
            local items_var=""
            case $CATEGORY_CURSOR in
                4) items_var="KEYBINDINGS_ITEMS" ;;
                5) items_var="DISPLAY_ITEMS" ;;
                6) items_var="SYSTEM_ITEMS" ;;
                7) items_var="APPEARANCE_ITEMS" ;;
                8) items_var="KEYBOARD_ITEMS" ;;
            esac
            local -n items_arr="$items_var"
            local item="${items_arr[$ITEM_CURSOR]}"
            parse_toggle_item "$item"

            local cur="${TOGGLE_SELECTIONS[$TOGGLE_ID]:-0}"
            # Cycle: 0 -> 1 -> 2 -> 0
            if [ "$cur" -eq 0 ]; then
                TOGGLE_SELECTIONS[$TOGGLE_ID]=1
            elif [ "$cur" -eq 1 ]; then
                TOGGLE_SELECTIONS[$TOGGLE_ID]=2
            else
                TOGGLE_SELECTIONS[$TOGGLE_ID]=0
            fi
            ;;
        9)  # Utilities (simple toggle)
            local item="${UTILITIES_ITEMS[$ITEM_CURSOR]}"
            parse_toggle_item "$item"
            local cur="${TOGGLE_SELECTIONS[$TOGGLE_ID]:-0}"
            if [ "$cur" -eq 0 ]; then
                TOGGLE_SELECTIONS[$TOGGLE_ID]=1
            else
                TOGGLE_SELECTIONS[$TOGGLE_ID]=0
            fi
            ;;
    esac
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

# =============================================================================
# CONVERT SELECTIONS TO ACTION FLAGS
# =============================================================================

# Build lists of selected packages and webapps
declare -a SELECTED_PACKAGES_FINAL=()
declare -a SELECTED_WEBAPPS_FINAL=()

for pkg in "${INSTALLED_PACKAGES[@]}"; do
    if [ "${PKG_SELECTIONS[$pkg]:-0}" -eq 1 ]; then
        SELECTED_PACKAGES_FINAL+=("$pkg")
    fi
done

for webapp in "${INSTALLED_WEBAPPS[@]}"; do
    if [ "${WEBAPP_SELECTIONS[$webapp]:-0}" -eq 1 ]; then
        SELECTED_WEBAPPS_FINAL+=("$webapp")
    fi
done

# Convert toggle selections to action flags
# close_window: 1=SUPER+Q (rebind), 2=SUPER+W (restore default)
RESET_KEYBINDS=false
RESTORE_KEYBINDS=false
case "${TOGGLE_SELECTIONS[close_window]:-0}" in
    1) RESET_KEYBINDS=true ;;
    2) RESTORE_KEYBINDS=true ;;
esac

# shutdown: 1=Bind, 2=Unbind
BIND_SHUTDOWN=false
UNBIND_SHUTDOWN=false
case "${TOGGLE_SELECTIONS[shutdown]:-0}" in
    1) BIND_SHUTDOWN=true ;;
    2) UNBIND_SHUTDOWN=true ;;
esac

# restart: 1=Bind, 2=Unbind
BIND_RESTART=false
UNBIND_RESTART=false
case "${TOGGLE_SELECTIONS[restart]:-0}" in
    1) BIND_RESTART=true ;;
    2) UNBIND_RESTART=true ;;
esac

# theme_menu: 1=Bind, 2=Unbind
BIND_THEME_MENU=false
UNBIND_THEME_MENU=false
case "${TOGGLE_SELECTIONS[theme_menu]:-0}" in
    1) BIND_THEME_MENU=true ;;
    2) UNBIND_THEME_MENU=true ;;
esac

# monitor_scale: 1=4K, 2=1080p/1440p
MONITOR_4K=false
MONITOR_1080_1440=false
case "${TOGGLE_SELECTIONS[monitor_scale]:-0}" in
    1) MONITOR_4K=true ;;
    2) MONITOR_1080_1440=true ;;
esac

# suspend: 1=Enable, 2=Disable
ENABLE_SUSPEND=false
DISABLE_SUSPEND=false
case "${TOGGLE_SELECTIONS[suspend]:-0}" in
    1) ENABLE_SUSPEND=true ;;
    2) DISABLE_SUSPEND=true ;;
esac

# hibernation: 1=Enable, 2=Disable
ENABLE_HIBERNATION=false
DISABLE_HIBERNATION=false
case "${TOGGLE_SELECTIONS[hibernation]:-0}" in
    1) ENABLE_HIBERNATION=true ;;
    2) DISABLE_HIBERNATION=true ;;
esac

# fingerprint: 1=Enable, 2=Disable
ENABLE_FINGERPRINT=false
DISABLE_FINGERPRINT=false
case "${TOGGLE_SELECTIONS[fingerprint]:-0}" in
    1) ENABLE_FINGERPRINT=true ;;
    2) DISABLE_FINGERPRINT=true ;;
esac

# fido2: 1=Enable, 2=Disable
ENABLE_FIDO2=false
DISABLE_FIDO2=false
case "${TOGGLE_SELECTIONS[fido2]:-0}" in
    1) ENABLE_FIDO2=true ;;
    2) DISABLE_FIDO2=true ;;
esac

# rounded_corners: 1=Enable, 2=Disable
ENABLE_ROUNDED_CORNERS=false
DISABLE_ROUNDED_CORNERS=false
case "${TOGGLE_SELECTIONS[rounded_corners]:-0}" in
    1) ENABLE_ROUNDED_CORNERS=true ;;
    2) DISABLE_ROUNDED_CORNERS=true ;;
esac

# window_gaps: 1=Remove, 2=Restore
REMOVE_WINDOW_GAPS=false
RESTORE_WINDOW_GAPS=false
case "${TOGGLE_SELECTIONS[window_gaps]:-0}" in
    1) REMOVE_WINDOW_GAPS=true ;;
    2) RESTORE_WINDOW_GAPS=true ;;
esac

# tray_icons: 1=Show all, 2=Hide
SHOW_ALL_TRAY_ICONS=false
HIDE_TRAY_ICONS=false
case "${TOGGLE_SELECTIONS[tray_icons]:-0}" in
    1) SHOW_ALL_TRAY_ICONS=true ;;
    2) HIDE_TRAY_ICONS=true ;;
esac

# clock_format: 1=12h, 2=24h
ENABLE_12H_CLOCK=false
DISABLE_12H_CLOCK=false
case "${TOGGLE_SELECTIONS[clock_format]:-0}" in
    1) ENABLE_12H_CLOCK=true ;;
    2) DISABLE_12H_CLOCK=true ;;
esac

# media_dirs: 1=Enable, 2=Disable
ENABLE_MEDIA_DIRECTORIES=false
DISABLE_MEDIA_DIRECTORIES=false
case "${TOGGLE_SELECTIONS[media_dirs]:-0}" in
    1) ENABLE_MEDIA_DIRECTORIES=true ;;
    2) DISABLE_MEDIA_DIRECTORIES=true ;;
esac

# caps_lock: 1=Normal (restore), 2=Compose
RESTORE_CAPSLOCK=false
USE_CAPSLOCK_COMPOSE=false
case "${TOGGLE_SELECTIONS[caps_lock]:-0}" in
    1) RESTORE_CAPSLOCK=true ;;
    2) USE_CAPSLOCK_COMPOSE=true ;;
esac

# alt_super: 1=Swap, 2=Normal (restore)
SWAP_ALT_SUPER=false
RESTORE_ALT_SUPER=false
case "${TOGGLE_SELECTIONS[alt_super]:-0}" in
    1) SWAP_ALT_SUPER=true ;;
    2) RESTORE_ALT_SUPER=true ;;
esac

# backup_config: 1=Select
BACKUP_CONFIGS=false
if [ "${TOGGLE_SELECTIONS[backup_config]:-0}" -eq 1 ]; then
    BACKUP_CONFIGS=true
fi

# Check if anything was selected
has_selection=false
if [ ${#SELECTED_PACKAGES_FINAL[@]} -gt 0 ] || [ ${#SELECTED_WEBAPPS_FINAL[@]} -gt 0 ]; then
    has_selection=true
fi
for key in "${!TOGGLE_SELECTIONS[@]}"; do
    if [ "${TOGGLE_SELECTIONS[$key]}" -ne 0 ]; then
        has_selection=true
        break
    fi
done

if [ "$has_selection" = false ]; then
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

# Handle keybind restore (runs its own confirmation flow)
if [ "$RESTORE_KEYBINDS" = true ]; then
    restore_close_window
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

if [ "$ENABLE_FIDO2" = true ]; then
    enable_fido2
fi

if [ "$DISABLE_FIDO2" = true ]; then
    disable_fido2
fi

if [ "$SHOW_ALL_TRAY_ICONS" = true ]; then
    show_all_tray_icons
fi

if [ "$HIDE_TRAY_ICONS" = true ]; then
    hide_tray_icons
fi

if [ "$ENABLE_ROUNDED_CORNERS" = true ]; then
    enable_rounded_corners
fi

if [ "$DISABLE_ROUNDED_CORNERS" = true ]; then
    disable_rounded_corners
fi

if [ "$REMOVE_WINDOW_GAPS" = true ]; then
    remove_window_gaps
fi

if [ "$RESTORE_WINDOW_GAPS" = true ]; then
    restore_window_gaps
fi

if [ "$ENABLE_12H_CLOCK" = true ]; then
    enable_12h_clock
fi

if [ "$DISABLE_12H_CLOCK" = true ]; then
    disable_12h_clock
fi

if [ "$ENABLE_MEDIA_DIRECTORIES" = true ]; then
    enable_media_directories
fi

if [ "$DISABLE_MEDIA_DIRECTORIES" = true ]; then
    disable_media_directories
fi

# If only action items were selected, show summary and exit
if [ ${#SELECTED_PACKAGES_FINAL[@]} -eq 0 ] && [ ${#SELECTED_WEBAPPS_FINAL[@]} -eq 0 ]; then
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

if [ ${#SELECTED_PACKAGES_FINAL[@]} -gt 0 ]; then
    echo -e "${DIM}  Packages (${#SELECTED_PACKAGES_FINAL[@]}):${RESET}"
    for pkg in "${SELECTED_PACKAGES_FINAL[@]}"; do
        echo "    ${DIM}•${RESET}  $pkg"
    done
    echo
fi

if [ ${#SELECTED_WEBAPPS_FINAL[@]} -gt 0 ]; then
    echo -e "${DIM}  Web Apps (${#SELECTED_WEBAPPS_FINAL[@]}):${RESET}"
    for webapp in "${SELECTED_WEBAPPS_FINAL[@]}"; do
        echo "    ${DIM}•${RESET}  $webapp"
    done
    echo
fi

echo
if [ ${#SELECTED_PACKAGES_FINAL[@]} -gt 0 ]; then
    echo -e "${DIM}  Packages will be removed with their dependencies.${RESET}"
fi
if [ ${#SELECTED_WEBAPPS_FINAL[@]} -gt 0 ]; then
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
if [ ${#SELECTED_PACKAGES_FINAL[@]} -gt 0 ]; then
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
    local_total=${#SELECTED_PACKAGES_FINAL[@]}

    for pkg in "${SELECTED_PACKAGES_FINAL[@]}"; do
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
if [ ${#SELECTED_WEBAPPS_FINAL[@]} -gt 0 ]; then
    echo "  Removing web apps..."
    echo

    local_current=0
    local_total=${#SELECTED_WEBAPPS_FINAL[@]}

    for webapp in "${SELECTED_WEBAPPS_FINAL[@]}"; do
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
    if [ ${#SELECTED_PACKAGES_FINAL[@]} -gt 0 ]; then
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
