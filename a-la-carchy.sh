#!/bin/bash

# A La Carchy - Omarchy Linux Debloater
# Pick and choose what you want to remove, à la carte style!

# Clean, minimal color scheme
RESET='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'
SELECTED_BG='\033[7m'
CHECKED='\033[38;5;10m'

# Package mapping: "Display Name|package-name"
declare -a PACKAGES=(
    "1Password|1password-beta"
    "1Password CLI|1password-cli"
    "Aether|aether"
    "Alacritty|alacritty"
    "Calculator|gnome-calculator"
    "Chromium|chromium"
    "Docker (Core Engine)|docker"
    "Docker Buildx (Extended Build)|docker-buildx"
    "Docker Compose (Orchestration)|docker-compose"
    "Docker UFW (Firewall Integration)|ufw-docker"
    "Document Viewer|evince"
    "Ghostty|ghostty"
    "Image Viewer|imv"
    "Kdenlive|kdenlive"
    "LazyDocker (Docker TUI)|lazydocker"
    "LibreOffice|libreoffice-fresh"
    "LibreOffice Base|libreoffice-fresh-base"
    "LibreOffice Calc|libreoffice-fresh-calc"
    "LibreOffice Draw|libreoffice-fresh-draw"
    "LibreOffice Impress|libreoffice-fresh-impress"
    "LibreOffice Math|libreoffice-fresh-math"
    "LibreOffice Writer|libreoffice-fresh-writer"
    "LocalSend|localsend-bin"
    "Media Player|mpv"
    "Neovim|neovim"
    "OBS Studio|obs-studio"
    "Obsidian|obsidian"
    "Pinta|pinta"
    "Signal|signal-desktop"
    "Spotify|spotify"
    "Typora|typora"
    "Xournal++|xournalpp"
)

# Webapp mapping: "Display Name|desktop-file-name"
# These are installed via omarchy-webapp-install
declare -a WEBAPPS=(
    "HEY|HEY.desktop"
    "Basecamp|Basecamp.desktop"
    "WhatsApp|WhatsApp.desktop"
    "Google Photos|Google Photos.desktop"
    "Google Contacts|Google Contacts.desktop"
    "Google Messages|Google Messages.desktop"
    "ChatGPT|ChatGPT.desktop"
    "YouTube|YouTube.desktop"
    "GitHub|GitHub.desktop"
    "X|X.desktop"
    "Figma|Figma.desktop"
    "Discord|Discord.desktop"
    "Zoom|Zoom.desktop"
)

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    echo "Error: Do not run this script as root!"
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
    AUR_HELPER="sudo pacman"
fi

# Build list of installed packages and webapps
declare -a INSTALLED_PACKAGES=()
declare -a INSTALLED_NAMES=()
declare -a INSTALLED_TYPES=()  # "package" or "webapp"

# Check for installed packages
for pkg_entry in "${PACKAGES[@]}"; do
    IFS='|' read -r display_name package_name <<< "$pkg_entry"
    if pacman -Qi "$package_name" &> /dev/null 2>&1; then
        INSTALLED_PACKAGES+=("$package_name")
        INSTALLED_NAMES+=("$display_name")
        INSTALLED_TYPES+=("package")
    fi
done

# Check for installed webapps
WEBAPP_DIR="$HOME/.local/share/applications"
if [ -d "$WEBAPP_DIR" ]; then
    for webapp_entry in "${WEBAPPS[@]}"; do
        IFS='|' read -r display_name desktop_file <<< "$webapp_entry"
        if [ -f "$WEBAPP_DIR/$desktop_file" ]; then
            INSTALLED_PACKAGES+=("$desktop_file")
            INSTALLED_NAMES+=("$display_name (Web App)")
            INSTALLED_TYPES+=("webapp")
        fi
    done
fi

# Check if any packages are installed
if [ ${#INSTALLED_PACKAGES[@]} -eq 0 ]; then
    clear
    echo
    echo "No preinstalled packages found."
    echo
    exit 0
fi

# Selection state
declare -a SELECTED=()
for ((i=0; i<${#INSTALLED_PACKAGES[@]}; i++)); do
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
    if [ $visible_end -gt ${#INSTALLED_PACKAGES[@]} ]; then
        visible_end=${#INSTALLED_PACKAGES[@]}
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
    for ((i=0; i<${#INSTALLED_PACKAGES[@]}; i++)); do
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
                    if [ $CURSOR -lt $((${#INSTALLED_PACKAGES[@]} - 1)) ]; then
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

# Build lists of selected packages and webapps
declare -a SELECTED_PACKAGES=()
declare -a SELECTED_WEBAPPS=()
for ((i=0; i<${#INSTALLED_PACKAGES[@]}; i++)); do
    if [ ${SELECTED[$i]} -eq 1 ]; then
        if [ "${INSTALLED_TYPES[$i]}" = "package" ]; then
            SELECTED_PACKAGES+=("${INSTALLED_PACKAGES[$i]}")
        else
            SELECTED_WEBAPPS+=("${INSTALLED_PACKAGES[$i]}")
        fi
    fi
done

# Check if anything was selected
if [ ${#SELECTED_PACKAGES[@]} -eq 0 ] && [ ${#SELECTED_WEBAPPS[@]} -eq 0 ]; then
    clear
    echo
    echo "Nothing selected."
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
    echo -e "${DIM}  Packages:${RESET}"
    for pkg in "${SELECTED_PACKAGES[@]}"; do
        echo "    ${DIM}•${RESET}  $pkg"
    done
    echo
fi

if [ ${#SELECTED_WEBAPPS[@]} -gt 0 ]; then
    echo -e "${DIM}  Web Apps:${RESET}"
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
    echo -e "${DIM}  Web apps will be removed from ~/.local/share/applications.${RESET}"
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
REMOVAL_SUCCESS=true

# Remove packages
if [ ${#SELECTED_PACKAGES[@]} -gt 0 ]; then
    echo "  Removing packages..."
    echo

    if [ "$AUR_HELPER" = "sudo pacman" ]; then
        sudo pacman -Rns "${SELECTED_PACKAGES[@]}"
    else
        $AUR_HELPER -Rns "${SELECTED_PACKAGES[@]}"
    fi

    if [ $? -ne 0 ]; then
        REMOVAL_SUCCESS=false
    fi
    echo
fi

# Remove webapps
if [ ${#SELECTED_WEBAPPS[@]} -gt 0 ]; then
    echo "  Removing web apps..."
    echo

    for webapp in "${SELECTED_WEBAPPS[@]}"; do
        webapp_path="$WEBAPP_DIR/$webapp"
        if [ -f "$webapp_path" ]; then
            rm "$webapp_path"
            if [ $? -eq 0 ]; then
                echo "    ${DIM}•${RESET}  Removed $webapp"
            else
                echo "    ${DIM}✗${RESET}  Failed to remove $webapp"
                REMOVAL_SUCCESS=false
            fi
        fi
    done
    echo
fi

# Check if removal was successful
if [ "$REMOVAL_SUCCESS" = true ]; then
    echo
    echo -e "${CHECKED}  ✓  Complete${RESET}"
    echo
    if [ ${#SELECTED_PACKAGES[@]} -gt 0 ]; then
        echo "  Packages removed successfully"
    fi
    if [ ${#SELECTED_WEBAPPS[@]} -gt 0 ]; then
        echo "  Web apps removed successfully"
    fi
    echo
    echo
    if [ ${#SELECTED_PACKAGES[@]} -gt 0 ]; then
        echo -e "${DIM}  Optionally, clean your package cache:${RESET}"
        echo "  $AUR_HELPER -Sc"
    fi
    echo
    echo
else
    echo
    echo "  ✗  Failed"
    echo
    echo "  Removal encountered an error"
    echo
    echo
    exit 1
fi
