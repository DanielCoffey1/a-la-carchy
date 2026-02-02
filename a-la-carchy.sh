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
    "kdenlive"
    "libreoffice"
    "localsend"
    "obs-studio"
    "obsidian"
    "omarchy-chromium"
    "signal-desktop"
    "spotify"
    "xournalpp"
    "docker"
    "docker-buildx"
    "docker-compose"
)

# Default webapps offered for removal
# List from: https://github.com/basecamp/omarchy/blob/master/install/packaging/webapps.sh
DEFAULT_WEBAPPS=(
    "HEY"
    "Basecamp"
    "WhatsApp"
    "Google Photos"
    "Google Contacts"
    "Google Messages"
    "ChatGPT"
    "YouTube"
    "GitHub"
    "X"
    "Figma"
    "Discord"
    "Zoom"
)

# Hyprland tiling config path
TILING_CONF="$HOME/.local/share/omarchy/default/hypr/bindings/tiling-v2.conf"

# Hyprland monitors config path
MONITORS_CONF="$HOME/.config/hypr/monitors.conf"

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
        return 1
    fi

    # Check if already changed
    if grep -q "SUPER, Q, Close window, killactive" "$TILING_CONF"; then
        echo -e "  ${DIM}Already set to SUPER+Q. Nothing to do.${RESET}"
        echo
        return 0
    fi

    printf "  ${BOLD}Continue?${RESET} ${DIM}(yes/no)${RESET} "
    read -r < /dev/tty

    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo
        echo "  Cancelled."
        echo
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
        return 0
    fi

    echo

    # Create archive (follow symlinks with -h)
    if tar -czhf "$archive" -C "$HOME" "${existing_dirs[@]}" 2>/dev/null; then
        echo -e "    ${CHECKED}✓${RESET}  Archive created: $archive"
    else
        echo -e "    ${DIM}✗${RESET}  Failed to create archive."
        echo
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
        return 1
    fi

    printf "  ${BOLD}Continue?${RESET} ${DIM}(yes/no)${RESET} "
    read -r < /dev/tty

    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo
        echo "  Cancelled."
        echo
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
        return 1
    fi

    printf "  ${BOLD}Continue?${RESET} ${DIM}(yes/no)${RESET} "
    read -r < /dev/tty

    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo
        echo "  Cancelled."
        echo
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
    echo
    echo -e "  ${DIM}Hyprland will auto-reload the config.${RESET}"
    echo
    echo
}

# Build list of installed packages and webapps
declare -a INSTALLED_ITEMS=()
declare -a INSTALLED_NAMES=()
declare -a INSTALLED_TYPES=()  # "package" or "webapp"

# Check for installed packages
for pkg in "${DEFAULT_APPS[@]}"; do
    if is_package_installed "$pkg"; then
        INSTALLED_ITEMS+=("$pkg")
        INSTALLED_NAMES+=("$pkg")
        INSTALLED_TYPES+=("package")
    fi
done

# Check for installed webapps
for webapp in "${DEFAULT_WEBAPPS[@]}"; do
    if is_webapp_installed "$webapp"; then
        INSTALLED_ITEMS+=("$webapp")
        INSTALLED_NAMES+=("$webapp (Web App)")
        INSTALLED_TYPES+=("webapp")
    fi
done

# Add the keybinding reset option at the end
INSTALLED_ITEMS+=("__reset_keybinds__")
INSTALLED_NAMES+=("-- Rebind close window to SUPER+Q --")
INSTALLED_TYPES+=("action")

INSTALLED_ITEMS+=("__backup_configs__")
INSTALLED_NAMES+=("-- Backup config (creates restore script) --")
INSTALLED_TYPES+=("action")

INSTALLED_ITEMS+=("__monitor_4k__")
INSTALLED_NAMES+=("-- Set monitor scaling: 4K --")
INSTALLED_TYPES+=("action")

INSTALLED_ITEMS+=("__monitor_1080_1440__")
INSTALLED_NAMES+=("-- Set monitor scaling: 1080p / 1440p --")
INSTALLED_TYPES+=("action")

# Check if only action options exist (no packages/webapps found)
if [ ${#INSTALLED_ITEMS[@]} -le 4 ]; then
    # Still show the UI so the user can access the keybind reset
    :
fi

# Selection state
declare -a SELECTED=()
for ((i=0; i<${#INSTALLED_ITEMS[@]}; i++)); do
    SELECTED[$i]=0
done

CURSOR=0
SCROLL_OFFSET=0

# Helper function to center text
center_text() {
    local text="$1"
    local term_width=$(tput cols)
    local text_length=${#text}
    local padding=$(( (term_width - text_length) / 2 ))
    printf "%*s%s\n" $padding "" "$text"
}

# Function to draw the interface
draw_interface() {
    local term_height=$(tput lines)
    local term_width=$(tput cols)

    # Calculate max visible items
    local MAX_VISIBLE=$((term_height - 12))
    if [ $MAX_VISIBLE -lt 5 ]; then
        MAX_VISIBLE=5
    fi

    # Calculate visible range
    local visible_start=$SCROLL_OFFSET
    local visible_end=$((SCROLL_OFFSET + MAX_VISIBLE))
    if [ $visible_end -gt ${#INSTALLED_ITEMS[@]} ]; then
        visible_end=${#INSTALLED_ITEMS[@]}
    fi

    # Clear and redraw everything (simpler, no glitches)
    clear

    # Title - centered
    echo
    local title1=" ▄▀█   █   ▄▀█   █▀▀ ▄▀█ █▀█ █▀▀ █ █ █▄█"
    local title2=" █▀█   █▄▄ █▀█   █▄▄ █▀█ █▀▄ █▄▄ █▀█  █"
    echo -en "${BOLD}"
    center_text "$title1"
    center_text "$title2"
    echo -en "${RESET}"
    echo
    echo -en "${DIM}"
    center_text "Omarchy Linux Debloater"
    echo -en "${RESET}"
    echo
    echo

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
    echo

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
    local left_margin=$(( (term_width - item_width) / 2 ))

    for ((i=visible_start; i<visible_end; i++)); do
        local checkbox="[ ]"
        local check_color=""
        if [ ${SELECTED[$i]} -eq 1 ]; then
            checkbox="[•]"
            check_color="${CHECKED}"
        fi

        if [ $i -eq $CURSOR ]; then
            # Highlighted line - centered with full width highlight
            local item_text="${checkbox}  ${INSTALLED_NAMES[$i]}"
            local padding_left=$(printf '%*s' $left_margin '')
            local padding_right=$(printf '%*s' $((term_width - left_margin - item_width)) '')
            printf "${padding_left}${SELECTED_BG}%-${item_width}s${RESET}${padding_right}\n" "$item_text"
        else
            # Normal line - centered
            printf "%*s${DIM}${check_color}${checkbox}${RESET}  ${INSTALLED_NAMES[$i]}\n" $left_margin ""
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
    IFS= read -rsn1 key < /dev/tty

    local term_height=$(tput lines)
    local MAX_VISIBLE=$((term_height - 12))
    if [ $MAX_VISIBLE -lt 5 ]; then
        MAX_VISIBLE=5
    fi

    case "$key" in
        $'\x1b')  # ESC sequence
            read -rsn2 -t 0.1 key
            case "$key" in
                '[A')  # Up arrow
                    if [ $CURSOR -gt 0 ]; then
                        ((CURSOR--))
                        if [ $CURSOR -lt $SCROLL_OFFSET ]; then
                            ((SCROLL_OFFSET--))
                        fi
                    fi
                    ;;
                '[B')  # Down arrow
                    if [ $CURSOR -lt $((${#INSTALLED_ITEMS[@]} - 1)) ]; then
                        ((CURSOR++))
                        if [ $CURSOR -ge $((SCROLL_OFFSET + MAX_VISIBLE)) ]; then
                            ((SCROLL_OFFSET++))
                        fi
                    fi
                    ;;
            esac
            ;;
        ' ')  # Space - toggle selection
            if [ ${SELECTED[$CURSOR]} -eq 0 ]; then
                SELECTED[$CURSOR]=1
            else
                SELECTED[$CURSOR]=0
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
                fi
                ;;
        esac
    fi
done

# Check if anything was selected
if [ ${#SELECTED_PACKAGES[@]} -eq 0 ] && [ ${#SELECTED_WEBAPPS[@]} -eq 0 ] && [ "$RESET_KEYBINDS" = false ] && [ "$BACKUP_CONFIGS" = false ] && [ "$MONITOR_4K" = false ] && [ "$MONITOR_1080_1440" = false ]; then
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

# If only action items were selected, we're done
if [ ${#SELECTED_PACKAGES[@]} -eq 0 ] && [ ${#SELECTED_WEBAPPS[@]} -eq 0 ]; then
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
        else
            echo -e "    ${DIM}✗${RESET}  Failed: $pkg (may have dependencies)"
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
        else
            echo -e "    ${DIM}✗${RESET}  Failed: $webapp"
            ((TOTAL_FAILED++))
        fi
    done
    echo
fi

# Summary
TOTAL_SUCCESS=$((TOTAL_ATTEMPTED - TOTAL_FAILED))

echo
if [ $TOTAL_FAILED -eq 0 ]; then
    echo -e "${CHECKED}  ✓  Complete${RESET}"
    echo
    echo "  All $TOTAL_ATTEMPTED item(s) removed successfully."
    echo
    echo
    if [ ${#SELECTED_PACKAGES[@]} -gt 0 ]; then
        echo -e "${DIM}  Optionally, clean your package cache:${RESET}"
        echo "  sudo pacman -Sc"
    fi
elif [ $TOTAL_SUCCESS -gt 0 ]; then
    echo -e "  ⚠  Partial Success"
    echo
    echo "  $TOTAL_SUCCESS of $TOTAL_ATTEMPTED item(s) removed."
    echo "  $TOTAL_FAILED item(s) could not be removed (may have dependencies)."
else
    echo "  ✗  Failed"
    echo
    echo "  Could not remove any items. Check dependencies and permissions."
    echo
    exit 1
fi
echo
echo
