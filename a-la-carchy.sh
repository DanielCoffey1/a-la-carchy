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

# Waybar config paths
WAYBAR_CONF="$HOME/.config/waybar/config.jsonc"
WAYBAR_CONF_STYLE="$HOME/.config/waybar/style.css"

# Hyprland looknfeel config path
LOOKNFEEL_CONF="$HOME/.config/hypr/looknfeel.conf"

# UWSM defaults config path
UWSM_DEFAULT="$HOME/.config/uwsm/default"

# Managed-block markers for laptop auto-off
LAPTOP_AUTO_MARKER_START="# >>> managed by a-la-carchy laptop-display"
LAPTOP_AUTO_MARKER_END="# <<< managed by a-la-carchy laptop-display"

# Laptop auto-off script path
LAPTOP_AUTO_SCRIPT="$HOME/.config/hypr/scripts/laptop-display-auto.sh"

# Managed-block markers for power profile
POWER_PROFILE_MARKER_START="# >>> managed by a-la-carchy power-profile"
POWER_PROFILE_MARKER_END="# <<< managed by a-la-carchy power-profile"

# Power profile startup script path
POWER_PROFILE_SCRIPT="$HOME/.config/hypr/scripts/power-profile-default.sh"

# Battery charge limit udev rule path
BATTERY_LIMIT_UDEV_RULE="/etc/udev/rules.d/99-battery-charge-limit.rules"

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    echo "Error: Do not run this script as root!"
    echo "The script will ask for sudo password when needed."
    exit 1
fi

# Extract managed blocks from monitors.conf so they survive full rewrites
# Stores result in MONITORS_MANAGED_BLOCKS variable
save_managed_blocks() {
    MONITORS_MANAGED_BLOCKS=""
    [[ -f "$MONITORS_CONF" ]] || return
    local markers=(
        "$POWER_PROFILE_MARKER_START|$POWER_PROFILE_MARKER_END"
        "$LAPTOP_AUTO_MARKER_START|$LAPTOP_AUTO_MARKER_END"
    )
    for pair in "${markers[@]}"; do
        local start="${pair%%|*}"
        local end="${pair##*|}"
        local block
        block=$(awk -v s="$start" -v e="$end" '$0==s{f=1} f{print} $0==e{f=0}' "$MONITORS_CONF")
        if [[ -n "$block" ]]; then
            MONITORS_MANAGED_BLOCKS+=$'\n'"$block"
        fi
    done
}

# Re-append saved managed blocks to monitors.conf after a rewrite
restore_managed_blocks() {
    if [[ -n "${MONITORS_MANAGED_BLOCKS:-}" ]]; then
        echo "$MONITORS_MANAGED_BLOCKS" >> "$MONITORS_CONF"
    fi
}

# Function to check if package is installed
is_package_installed() {
    pacman -Qi "$1" &>/dev/null
}

# Function to check if webapp is installed
is_webapp_installed() {
    [[ -f "$HOME/.local/share/applications/$1.desktop" ]]
}

# Function to load all keybindings from config files for the Keybind Editor
# Applies unbind/rebind overrides from bindings.conf so entries show current state
load_all_bindings() {
    EDIT_BINDINGS_ITEMS=()

    # Phase 1: Load default config files (not bindings.conf)
    local default_files=(
        "$HOME/.local/share/omarchy/default/hypr/bindings/clipboard.conf"
        "$HOME/.local/share/omarchy/default/hypr/bindings/tiling-v2.conf"
        "$HOME/.local/share/omarchy/default/hypr/bindings/utilities.conf"
        "$HOME/.local/share/omarchy/default/hypr/bindings/media.conf"
    )
    local file_labels=("Clipboard" "Tiling" "Utilities" "Media")

    for i in "${!default_files[@]}"; do
        local file="${default_files[$i]}"
        local label="${file_labels[$i]}"

        [[ -f "$file" ]] || continue

        EDIT_BINDINGS_ITEMS+=("HEADER|$label")

        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            [[ "$line" =~ ^bindd[[:space:]]*= ]] || continue

            local content="${line#bindd = }"
            content="${content#bindd=}"

            IFS=',' read -ra parts <<< "$content"
            [[ ${#parts[@]} -lt 4 ]] && continue

            local mods="${parts[0]## }"
            mods="${mods%% }"
            local bkey="${parts[1]## }"
            bkey="${bkey%% }"
            local desc="${parts[2]## }"
            desc="${desc%% }"
            local dispatcher="${parts[3]## }"
            dispatcher="${dispatcher%% }"
            local args=""
            if [[ ${#parts[@]} -gt 4 ]]; then
                args="${parts[*]:4}"
                args="${args## }"
                args="${args%% }"
            fi

            EDIT_BINDINGS_ITEMS+=("bindd|$mods|$bkey|$desc|$dispatcher|$args|$file")
        done < "$file"
    done

    # Phase 2: Process bindings.conf overrides
    # For each unbind+bindd pair, update the matching default entry in-place
    # Non-override bindd entries are collected as user bindings
    if [[ -f "$BINDINGS_CONF" ]]; then
        # Build lookup: "MODS|KEY" -> EDIT_BINDINGS_ITEMS index
        local -A binding_lookup=()
        for idx in "${!EDIT_BINDINGS_ITEMS[@]}"; do
            local entry="${EDIT_BINDINGS_ITEMS[$idx]}"
            [[ "$entry" == HEADER* ]] && continue
            IFS='|' read -r _t lk_mods lk_key _rest <<< "$entry"
            binding_lookup["$lk_mods|$lk_key"]=$idx
        done

        # Process line-by-line to pair unbinds with rebinds
        local -A pending_unbinds=()  # "MODS|KEY" -> 1
        local -a user_entries=()

        while IFS= read -r line; do
            [[ -z "$line" ]] && continue

            # Process unbind lines
            if [[ "$line" =~ ^unbind[[:space:]]*=[[:space:]]*(.*) ]]; then
                local ucontent="${BASH_REMATCH[1]}"
                IFS=',' read -ra uparts <<< "$ucontent"
                [[ ${#uparts[@]} -lt 2 ]] && continue
                local u_mods="${uparts[0]## }"
                u_mods="${u_mods%% }"
                local u_key="${uparts[1]## }"
                u_key="${u_key%% }"
                local u_lookup="$u_mods|$u_key"
                if [[ -n "${binding_lookup[$u_lookup]:-}" ]]; then
                    pending_unbinds["$u_lookup"]=1
                fi
                continue
            fi

            # Process bindd lines
            [[ "$line" =~ ^bindd[[:space:]]*= ]] || continue

            local content="${line#bindd = }"
            content="${content#bindd=}"
            IFS=',' read -ra parts <<< "$content"
            [[ ${#parts[@]} -lt 4 ]] && continue

            local b_mods="${parts[0]## }"
            b_mods="${b_mods%% }"
            local b_key="${parts[1]## }"
            b_key="${b_key%% }"
            local b_desc="${parts[2]## }"
            b_desc="${b_desc%% }"
            local b_disp="${parts[3]## }"
            b_disp="${b_disp%% }"
            local b_args=""
            if [[ ${#parts[@]} -gt 4 ]]; then
                b_args="${parts[*]:4}"
                b_args="${b_args## }"
                b_args="${b_args%% }"
            fi

            # Check if this bindd matches a pending unbind (override)
            local was_override=false
            for u_lookup in "${!pending_unbinds[@]}"; do
                local orig_idx="${binding_lookup[$u_lookup]}"
                local orig_entry="${EDIT_BINDINGS_ITEMS[$orig_idx]}"
                IFS='|' read -r _t _m _k orig_desc _rest <<< "$orig_entry"
                if [[ "$orig_desc" == "$b_desc" ]]; then
                    # Update the default entry with overridden mods/key
                    IFS='|' read -r _t _m _k _d orig_disp orig_args orig_file <<< "$orig_entry"
                    EDIT_BINDINGS_ITEMS[$orig_idx]="bindd|$b_mods|$b_key|$b_desc|$b_disp|$b_args|$orig_file"
                    # Update lookup for chained overrides
                    unset "binding_lookup[$u_lookup]"
                    binding_lookup["$b_mods|$b_key"]=$orig_idx
                    unset "pending_unbinds[$u_lookup]"
                    was_override=true
                    break
                fi
            done

            if [[ "$was_override" == false ]]; then
                user_entries+=("bindd|$b_mods|$b_key|$b_desc|$b_disp|$b_args|$BINDINGS_CONF")
            fi
        done < "$BINDINGS_CONF"

        # Add non-override user bindings
        if [[ ${#user_entries[@]} -gt 0 ]]; then
            EDIT_BINDINGS_ITEMS+=("HEADER|User Bindings")
            for entry in "${user_entries[@]}"; do
                EDIT_BINDINGS_ITEMS+=("$entry")
            done
        fi
    fi
}

# Parse a Hyprland settings item string into global variables
parse_hypr_item() {
    IFS='|' read -r HYPR_ID HYPR_LABEL HYPR_TYPE HYPR_SECTION HYPR_KEY HYPR_DEFAULT HYPR_FILE HYPR_DESC <<< "$1"
}

# Load current values from managed blocks in config files
load_hypr_settings() {
    HYPR_CURRENT=()
    local marker_start="# === a-la-carchy hyprland settings ==="
    local marker_end="# === end a-la-carchy hyprland settings ==="

    local config_files=("$LOOKNFEEL_CONF" "$INPUT_CONF")
    for conf in "${config_files[@]}"; do
        [[ -f "$conf" ]] || continue

        local in_block=false
        local section_stack=()
        while IFS= read -r line; do
            if [[ "$line" == "$marker_start" ]]; then
                in_block=true
                section_stack=()
                continue
            fi
            if [[ "$line" == "$marker_end" ]]; then
                in_block=false
                continue
            fi
            $in_block || continue

            # Skip empty lines and comments
            local trimmed="${line#"${line%%[![:space:]]*}"}"
            [[ -z "$trimmed" ]] && continue
            [[ "$trimmed" == \#* ]] && continue

            # Opening brace: push section
            if [[ "$trimmed" =~ ^([a-zA-Z_][a-zA-Z0-9_.-]*)[[:space:]]*\{$ ]]; then
                section_stack+=("${BASH_REMATCH[1]}")
                continue
            fi

            # Closing brace: pop section
            if [[ "$trimmed" == "}" ]]; then
                if [[ ${#section_stack[@]} -gt 0 ]]; then
                    unset 'section_stack[${#section_stack[@]}-1]'
                fi
                continue
            fi

            # Key = value assignment
            if [[ "$trimmed" =~ ^([a-zA-Z_][a-zA-Z0-9_.-]*)[[:space:]]*=[[:space:]]*(.+)$ ]]; then
                local k="${BASH_REMATCH[1]}"
                local v="${BASH_REMATCH[2]}"
                # Trim trailing whitespace from value
                v="${v%"${v##*[![:space:]]}"}"

                # Build full section path
                local section_path=""
                for s in "${section_stack[@]}"; do
                    [[ -n "$section_path" ]] && section_path+="."
                    section_path+="$s"
                done

                local full_key="${section_path}.${k}"
                HYPR_CURRENT["$full_key"]="$v"
            fi
        done < "$conf"
    done
}

# Check if a keybind editor item is a section header
is_binding_header() {
    [[ "${EDIT_BINDINGS_ITEMS[$1]}" == HEADER* ]]
}

# Guided keybinding edit dialog (3 steps: modifiers, key, confirm)
edit_binding() {
    local idx=$1
    local entry="${EDIT_BINDINGS_ITEMS[$idx]}"

    # Skip headers
    [[ "$entry" == HEADER* ]] && return

    # Parse the binding entry
    IFS='|' read -r _type cur_mods cur_key cur_desc cur_dispatcher cur_args cur_file <<< "$entry"

    # Check if there's a pending edit - use those values
    if [[ -n "${BINDING_EDITS[$idx]:-}" ]]; then
        IFS='|' read -r cur_mods cur_key <<< "${BINDING_EDITS[$idx]}"
    fi

    # Step 1: Modifier selection
    local mod_super=0 mod_shift=0 mod_ctrl=0 mod_alt=0
    [[ "$cur_mods" == *SUPER* ]] && mod_super=1
    [[ "$cur_mods" == *SHIFT* ]] && mod_shift=1
    [[ "$cur_mods" == *CTRL* ]] && mod_ctrl=1
    [[ "$cur_mods" == *ALT* ]] && mod_alt=1

    local mod_cursor=0
    local mod_names=("SUPER" "SHIFT" "CTRL" "ALT")
    local -a mod_vals=($mod_super $mod_shift $mod_ctrl $mod_alt)

    while true; do
        clear
        echo
        echo -e "  ${BOLD}Edit Keybinding: $cur_desc${RESET}"
        echo -e "  ${DIM}Current: $cur_mods, $cur_key${RESET}"
        echo
        echo -e "  Select modifiers (Space to toggle, arrows to move):"
        echo
        printf "   "
        for i in 0 1 2 3; do
            local mark=" "
            [[ ${mod_vals[$i]} -eq 1 ]] && mark="x"
            if [[ $i -eq $mod_cursor ]]; then
                printf " ${SELECTED_BG}[%s] %s${RESET}" "$mark" "${mod_names[$i]}"
            else
                printf " [%s] %s" "$mark" "${mod_names[$i]}"
            fi
        done
        echo
        echo
        echo -e "  ${DIM}Enter: next   Escape: cancel${RESET}"

        IFS= read -rsn1 key < /dev/tty
        case "$key" in
            $'\x1b')
                read -rsn2 -t 0.1 key
                case "$key" in
                    '[C') (( mod_cursor < 3 )) && ((mod_cursor++)) ;;
                    '[D') (( mod_cursor > 0 )) && ((mod_cursor--)) ;;
                esac
                [[ -z "$key" ]] && return  # Bare escape = cancel
                ;;
            ' ')
                if [[ ${mod_vals[$mod_cursor]} -eq 0 ]]; then
                    mod_vals[$mod_cursor]=1
                else
                    mod_vals[$mod_cursor]=0
                fi
                ;;
            '')  # Enter
                break
                ;;
        esac
    done

    # Build modifier string
    local new_mods=""
    [[ ${mod_vals[0]} -eq 1 ]] && new_mods="SUPER"
    [[ ${mod_vals[1]} -eq 1 ]] && { [[ -n "$new_mods" ]] && new_mods+=" "; new_mods+="SHIFT"; }
    [[ ${mod_vals[2]} -eq 1 ]] && { [[ -n "$new_mods" ]] && new_mods+=" "; new_mods+="CTRL"; }
    [[ ${mod_vals[3]} -eq 1 ]] && { [[ -n "$new_mods" ]] && new_mods+=" "; new_mods+="ALT"; }

    # Step 2: Key input
    local new_key=""
    local key_error=""
    while true; do
        clear
        echo
        echo -e "  ${BOLD}Edit Keybinding: $cur_desc${RESET}"
        echo -e "  ${DIM}Modifiers: $new_mods${RESET}"
        echo
        echo -e "  Type key name (e.g. Q, RETURN, F1):"
        echo
        if [[ -n "$key_error" ]]; then
            echo -e "  ${DIM}x $key_error${RESET}"
            echo
        fi
        echo -e "  ${DIM}Common keys: A-Z  0-9  RETURN  SPACE  TAB  ESCAPE${RESET}"
        echo -e "  ${DIM}F1-F12  PRINT  DELETE  BACKSPACE  UP DOWN LEFT RIGHT${RESET}"
        echo
        printf "  > "

        stty echo 2>/dev/null
        tput cnorm
        read -r new_key < /dev/tty
        tput civis
        stty -echo 2>/dev/null

        # Trim whitespace and convert to uppercase
        new_key="${new_key## }"
        new_key="${new_key%% }"
        new_key="${new_key^^}"

        if [[ -z "$new_key" ]]; then
            key_error="Key cannot be empty"
            continue
        fi

        # Validate against known keys
        local valid=false
        for vk in "${VALID_KEYS[@]}"; do
            if [[ "$new_key" == "$vk" ]]; then
                valid=true
                break
            fi
        done

        if [[ "$valid" == false ]]; then
            key_error="Unknown key: $new_key"
            continue
        fi

        break
    done

    # Check for conflicts with other bindings
    local conflict_desc=""
    for ci in "${!EDIT_BINDINGS_ITEMS[@]}"; do
        [[ $ci -eq $idx ]] && continue
        local c_entry="${EDIT_BINDINGS_ITEMS[$ci]}"
        [[ "$c_entry" == HEADER* ]] && continue

        # Use pending edit if one exists, otherwise use stored mods/key
        local c_mods c_key c_desc
        if [[ -n "${BINDING_EDITS[$ci]:-}" ]]; then
            IFS='|' read -r c_mods c_key <<< "${BINDING_EDITS[$ci]}"
            IFS='|' read -r _t _m _k c_desc _rest <<< "$c_entry"
        else
            IFS='|' read -r _t c_mods c_key c_desc _rest <<< "$c_entry"
        fi

        if [[ "$c_mods" == "$new_mods" ]] && [[ "$c_key" == "$new_key" ]]; then
            conflict_desc="$c_desc"
            break
        fi
    done

    # Step 3: Preview and confirm
    clear
    echo
    echo -e "  ${BOLD}Edit Keybinding: $cur_desc${RESET}"
    echo
    echo -e "  New binding: ${BOLD}$new_mods, $new_key${RESET}  ->  $cur_desc"
    echo
    if [[ -n "$conflict_desc" ]]; then
        echo -e "  ${BOLD}Warning:${RESET} ${DIM}$new_mods+$new_key is already bound to:${RESET}"
        echo -e "  ${DIM}  $conflict_desc${RESET}"
        echo
    fi
    echo -e "  ${DIM}Enter: confirm   Escape: cancel${RESET}"

    IFS= read -rsn1 key < /dev/tty
    case "$key" in
        '')  # Enter - confirm
            BINDING_EDITS[$idx]="$new_mods|$new_key"
            ;;
    esac
}

# Guided Hyprland setting edit dialog
# Dispatches based on type_info: bool, int, float, enum, color
edit_hypr_setting() {
    local item="$1"
    parse_hypr_item "$item"

    local id="$HYPR_ID"
    local label="$HYPR_LABEL"
    local type_info="$HYPR_TYPE"
    local section="$HYPR_SECTION"
    local config_key="$HYPR_KEY"
    local default="$HYPR_DEFAULT"

    # Get current display value: pending > saved > default
    local cur_val="$default"
    local full_key="${section}.${config_key}"
    [[ -n "${HYPR_CURRENT[$full_key]:-}" ]] && cur_val="${HYPR_CURRENT[$full_key]}"
    [[ -n "${HYPR_EDITS[$id]:-}" ]] && cur_val="${HYPR_EDITS[$id]}"

    # Bool: immediate toggle, no dialog
    if [[ "$type_info" == "bool" ]]; then
        if [[ "$cur_val" == "true" ]]; then
            HYPR_EDITS[$id]="false"
        else
            HYPR_EDITS[$id]="true"
        fi
        return
    fi

    # Int/Float: text input with range validation
    if [[ "$type_info" =~ ^(int|float):(.+):(.+)$ ]]; then
        local val_type="${BASH_REMATCH[1]}"
        local range_min="${BASH_REMATCH[2]}"
        local range_max="${BASH_REMATCH[3]}"
        local input_error=""

        while true; do
            clear
            echo
            echo -e "  ${BOLD}Edit: $label${RESET}"
            echo -e "  ${DIM}Current value: $cur_val${RESET}"
            echo -e "  ${DIM}Range: $range_min - $range_max${RESET}"
            echo
            if [[ -n "$input_error" ]]; then
                echo -e "  ${DIM}x $input_error${RESET}"
                echo
            fi
            printf "  Enter new value: "

            stty echo 2>/dev/null
            tput cnorm
            read -r new_val < /dev/tty
            tput civis
            stty -echo 2>/dev/null

            new_val="${new_val## }"
            new_val="${new_val%% }"

            if [[ -z "$new_val" ]]; then
                return  # Cancel on empty input
            fi

            if [[ "$val_type" == "int" ]]; then
                if ! [[ "$new_val" =~ ^-?[0-9]+$ ]]; then
                    input_error="Must be an integer"
                    continue
                fi
                if (( new_val < range_min || new_val > range_max )); then
                    input_error="Out of range ($range_min - $range_max)"
                    continue
                fi
            else
                # float validation
                if ! [[ "$new_val" =~ ^-?[0-9]*\.?[0-9]+$ ]]; then
                    input_error="Must be a number"
                    continue
                fi
                # Use awk for float comparison
                if ! awk "BEGIN { exit !(($new_val) >= ($range_min) && ($new_val) <= ($range_max)) }"; then
                    input_error="Out of range ($range_min - $range_max)"
                    continue
                fi
            fi

            HYPR_EDITS[$id]="$new_val"
            return
        done
    fi

    # Enum: arrow-key selection dialog
    if [[ "$type_info" =~ ^enum: ]]; then
        local opts_str="${type_info#enum:}"
        IFS=':' read -ra opts <<< "$opts_str"
        local opt_cursor=0

        # Find current value in options
        for i in "${!opts[@]}"; do
            if [[ "${opts[$i]}" == "$cur_val" ]]; then
                opt_cursor=$i
                break
            fi
        done

        while true; do
            clear
            echo
            echo -e "  ${BOLD}Edit: $label${RESET}"
            echo -e "  ${DIM}Current: $cur_val${RESET}"
            echo
            echo -e "  ${DIM}Select option (Up/Down, Enter to confirm):${RESET}"
            echo

            for i in "${!opts[@]}"; do
                if [[ $i -eq $opt_cursor ]]; then
                    echo -e "    ${SELECTED_BG}> ${opts[$i]}${RESET}"
                else
                    echo -e "      ${opts[$i]}"
                fi
            done

            echo
            echo -e "  ${DIM}Escape: cancel${RESET}"

            IFS= read -rsn1 key < /dev/tty
            case "$key" in
                $'\x1b')
                    read -rsn2 -t 0.1 key
                    case "$key" in
                        '[A') (( opt_cursor > 0 )) && ((opt_cursor--)) ;;
                        '[B') (( opt_cursor < ${#opts[@]} - 1 )) && ((opt_cursor++)) ;;
                    esac
                    [[ -z "$key" ]] && return  # Bare escape = cancel
                    ;;
                '')  # Enter - confirm
                    HYPR_EDITS[$id]="${opts[$opt_cursor]}"
                    return
                    ;;
            esac
        done
    fi

    # Color: text input dialog
    if [[ "$type_info" == "color" ]]; then
        local input_error=""

        while true; do
            clear
            echo
            echo -e "  ${BOLD}Edit: $label${RESET}"
            echo -e "  ${DIM}Current: $cur_val${RESET}"
            echo
            if [[ -n "$input_error" ]]; then
                echo -e "  ${DIM}x $input_error${RESET}"
                echo
            fi
            printf "  Enter color value: "

            stty echo 2>/dev/null
            tput cnorm
            read -r new_val < /dev/tty
            tput civis
            stty -echo 2>/dev/null

            new_val="${new_val## }"
            new_val="${new_val%% }"

            if [[ -z "$new_val" ]]; then
                return  # Cancel on empty input
            fi

            # Basic validation: must contain rgba( or rgb( or be a hex color
            if [[ "$new_val" =~ rgba?\( ]] || [[ "$new_val" =~ ^0x[0-9a-fA-F]+$ ]]; then
                HYPR_EDITS[$id]="$new_val"
                return
            else
                input_error="Supports: rgba(RRGGBBAA), rgb(RRGGBB), gradients"
                continue
            fi
        done
    fi
}

# Apply all pending Hyprland setting edits to config files
apply_hypr_edits() {
    if [[ ${#HYPR_EDITS[@]} -eq 0 ]]; then
        return
    fi

    clear
    echo
    echo
    echo -e "${BOLD}  Apply Hyprland Settings${RESET}"
    echo
    echo -e "  ${DIM}Changes to apply:${RESET}"
    echo

    # Show summary of changes
    local all_items=("${HYPR_GENERAL_ITEMS[@]}" "${HYPR_DECORATION_ITEMS[@]}" "${HYPR_INPUT_ITEMS[@]}" "${HYPR_GESTURES_ITEMS[@]}")
    for entry in "${all_items[@]}"; do
        parse_hypr_item "$entry"
        [[ -z "${HYPR_EDITS[$HYPR_ID]:-}" ]] && continue
        local new_val="${HYPR_EDITS[$HYPR_ID]}"
        local old_val="$HYPR_DEFAULT"
        local fk="${HYPR_SECTION}.${HYPR_KEY}"
        [[ -n "${HYPR_CURRENT[$fk]:-}" ]] && old_val="${HYPR_CURRENT[$fk]}"
        echo -e "    ${DIM}•${RESET}  $HYPR_LABEL: $old_val -> $new_val"
    done
    echo
    echo

    printf "  ${BOLD}Continue?${RESET} ${DIM}(yes/no)${RESET} "
    read -r < /dev/tty

    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo
        echo "  Cancelled."
        echo
        SUMMARY_LOG+=("--  Hyprland settings -- cancelled")
        return 0
    fi

    echo

    local marker_start="# === a-la-carchy hyprland settings ==="
    local marker_end="# === end a-la-carchy hyprland settings ==="

    # Group edits by config file, then by section_path
    for target_file in "looknfeel" "input"; do
        local conf
        [[ "$target_file" == "looknfeel" ]] && conf="$LOOKNFEEL_CONF"
        [[ "$target_file" == "input" ]] && conf="$INPUT_CONF"

        # Collect edits for this file
        local -A file_edits=()
        local has_edits=false
        for entry in "${all_items[@]}"; do
            parse_hypr_item "$entry"
            [[ "$HYPR_FILE" != "$target_file" ]] && continue
            [[ -z "${HYPR_EDITS[$HYPR_ID]:-}" ]] && continue
            file_edits["${HYPR_SECTION}.${HYPR_KEY}"]="${HYPR_EDITS[$HYPR_ID]}"
            has_edits=true
        done
        $has_edits || continue

        [[ ! -f "$conf" ]] && continue

        # Backup
        local backup_file="${conf}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$conf" "$backup_file"
        echo -e "  ${DIM}Backup: $backup_file${RESET}"

        # Build managed block content with nested sections
        local -A sections_content=()
        for full_key in "${!file_edits[@]}"; do
            local section="${full_key%.*}"
            local key="${full_key##*.}"
            local val="${file_edits[$full_key]}"
            sections_content["$section"]+="    ${key} = ${val}"$'\n'
        done

        # Build the block with proper nesting
        local block=""
        block+="$marker_start"$'\n'

        # Sort sections and build nested structure
        local -A top_sections=()
        for section in "${!sections_content[@]}"; do
            local top="${section%%.*}"
            top_sections["$top"]=1
        done

        for top in "${!top_sections[@]}"; do
            # Collect direct keys for this top section
            local direct_content="${sections_content[$top]:-}"
            # Collect sub-sections
            local -A sub_sections=()
            for section in "${!sections_content[@]}"; do
                if [[ "$section" == "$top."* ]]; then
                    local sub="${section#*.}"
                    sub_sections["$sub"]="${sections_content[$section]}"
                fi
            done

            block+="${top} {"$'\n'
            if [[ -n "$direct_content" ]]; then
                block+="$direct_content"
            fi
            for sub in "${!sub_sections[@]}"; do
                block+="    ${sub} {"$'\n'
                # Indent sub-section content further
                local sub_content="${sub_sections[$sub]}"
                while IFS= read -r sline; do
                    [[ -z "$sline" ]] && continue
                    block+="    ${sline}"$'\n'
                done <<< "$sub_content"
                block+="    }"$'\n'
            done
            block+="}"$'\n'
        done

        block+="$marker_end"

        # Remove existing managed block if present, then append new one
        if grep -q "$marker_start" "$conf"; then
            # Use awk to remove the block
            awk -v start="$marker_start" -v end="$marker_end" '
                $0 == start { skip=1; next }
                $0 == end { skip=0; next }
                !skip { print }
            ' "$conf" > "${conf}.tmp"
            mv "${conf}.tmp" "$conf"
        fi

        # Append the new managed block
        echo "" >> "$conf"
        echo "$block" >> "$conf"

        # Log each setting
        for full_key in "${!file_edits[@]}"; do
            local key="${full_key##*.}"
            local val="${file_edits[$full_key]}"
            echo -e "    ${CHECKED}✓${RESET}  ${full_key} = ${val}"
            SUMMARY_LOG+=("✓  Hyprland: ${full_key} = ${val}")
        done
    done

    echo
    echo -e "  ${DIM}Hyprland will auto-reload the config.${RESET}"
    echo
}

# Apply all pending keybinding edits to bindings.conf
apply_binding_edits() {
    if [[ ${#BINDING_EDITS[@]} -eq 0 ]]; then
        return
    fi

    clear
    echo
    echo
    echo -e "${BOLD}  Apply Keybinding Edits${RESET}"
    echo
    echo -e "  ${DIM}Changes to apply:${RESET}"
    echo

    for idx in "${!BINDING_EDITS[@]}"; do
        local entry="${EDIT_BINDINGS_ITEMS[$idx]}"
        IFS='|' read -r _type orig_mods orig_key desc dispatcher args source <<< "$entry"
        IFS='|' read -r new_mods new_key <<< "${BINDING_EDITS[$idx]}"
        echo -e "    ${DIM}•${RESET}  $desc: $orig_mods+$orig_key -> $new_mods+$new_key"
    done
    echo
    echo

    printf "  ${BOLD}Continue?${RESET} ${DIM}(yes/no)${RESET} "
    read -r < /dev/tty

    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo
        echo "  Cancelled."
        echo
        SUMMARY_LOG+=("--  Keybinding edits -- cancelled")
        return 0
    fi

    echo

    if [[ ! -f "$BINDINGS_CONF" ]]; then
        echo -e "  ${DIM}✗${RESET}  bindings.conf not found at $BINDINGS_CONF"
        SUMMARY_LOG+=("✗  Keybinding edits -- failed (config not found)")
        return 1
    fi

    # Create backup
    local backup_file="${BINDINGS_CONF}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$BINDINGS_CONF" "$backup_file"
    echo -e "  ${DIM}Backup: $backup_file${RESET}"
    echo

    for idx in "${!BINDING_EDITS[@]}"; do
        local entry="${EDIT_BINDINGS_ITEMS[$idx]}"
        IFS='|' read -r _type orig_mods orig_key desc dispatcher args source <<< "$entry"
        IFS='|' read -r new_mods new_key <<< "${BINDING_EDITS[$idx]}"

        # Append unbind + rebind to bindings.conf
        echo "" >> "$BINDINGS_CONF"
        echo "unbind = $orig_mods, $orig_key" >> "$BINDINGS_CONF"
        if [[ -n "$args" ]]; then
            echo "bindd = $new_mods, $new_key, $desc, $dispatcher,$args" >> "$BINDINGS_CONF"
        else
            echo "bindd = $new_mods, $new_key, $desc, $dispatcher," >> "$BINDINGS_CONF"
        fi

        echo -e "    ${CHECKED}✓${RESET}  $desc: $orig_mods+$orig_key -> $new_mods+$new_key"
        SUMMARY_LOG+=("✓  Rebound $desc: $new_mods+$new_key")
    done
    echo
    echo -e "  ${DIM}Reload Hyprland or log out/in to apply.${RESET}"
    echo
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
        echo -e "    ${DIM}•${RESET}  ~/$d"
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

# Find all backup archives
mapfile -t BACKUPS < <(ls -1t ~/omarchy-backup-*.tar.gz 2>/dev/null)

if [[ ${#BACKUPS[@]} -eq 0 ]]; then
    echo "No backup archives found in ~/"
    exit 1
fi

echo "Available backups:"
echo
for i in "${!BACKUPS[@]}"; do
    # Extract timestamp from filename for display
    fname=$(basename "${BACKUPS[$i]}")
    ts="${fname#omarchy-backup-}"
    ts="${ts%.tar.gz}"
    date_part="${ts:0:4}-${ts:4:2}-${ts:6:2}"
    time_part="${ts:9:2}:${ts:11:2}:${ts:13:2}"
    size=$(du -h "${BACKUPS[$i]}" | cut -f1)
    echo "  $((i + 1))) $date_part $time_part  ($size)"
done

echo
printf "Select a backup to restore (1-%d): " "${#BACKUPS[@]}"
read -r choice

if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#BACKUPS[@]} )); then
    echo "Invalid selection."
    exit 1
fi

ARCHIVE="${BACKUPS[$((choice - 1))]}"

echo
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

    if grep -q "^monitor=[A-Za-z]" "$MONITORS_CONF" 2>/dev/null; then
        echo -e "  ${DIM}Note: Per-monitor layout detected. This will replace it with generic scaling.${RESET}"
        echo
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

    # Preserve managed blocks before overwriting
    save_managed_blocks

    # Write new config
    cat > "$MONITORS_CONF" << 'EOF'
# See https://wiki.hyprland.org/Configuring/Monitors/
# List current monitors and resolutions possible: hyprctl monitors
# Format: monitor = [port], resolution, position, scale

# Optimized for 27" or 32" 4K monitors
env = GDK_SCALE,1.75
monitor=,preferred,auto,1.666667
EOF

    # Restore managed blocks (power-profile, laptop-auto-off, etc.)
    restore_managed_blocks

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

    if grep -q "^monitor=[A-Za-z]" "$MONITORS_CONF" 2>/dev/null; then
        echo -e "  ${DIM}Note: Per-monitor layout detected. This will replace it with generic scaling.${RESET}"
        echo
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

    # Preserve managed blocks before overwriting
    save_managed_blocks

    # Write new config
    cat > "$MONITORS_CONF" << 'EOF'
# See https://wiki.hyprland.org/Configuring/Monitors/
# List current monitors and resolutions possible: hyprctl monitors
# Format: monitor = [port], resolution, position, scale

# Straight 1x setup for 1080p or 1440p displays
env = GDK_SCALE,1
monitor=,preferred,auto,1
EOF

    # Restore managed blocks (power-profile, laptop-auto-off, etc.)
    restore_managed_blocks

    echo -e "    ${CHECKED}✓${RESET}  Monitor scaling set to 1080p/1440p"
    SUMMARY_LOG+=("✓  Monitor scaling set to 1080p/1440p")
    echo
    echo -e "  ${DIM}Hyprland will auto-reload the config.${RESET}"
    echo
    echo
}

# Detect connected monitors via hyprctl
detect_monitors() {
    DETECTED_MONITORS=()
    MONITOR_COUNT=0
    LAPTOP_MONITOR=""

    if ! command -v hyprctl &>/dev/null; then
        return 1
    fi

    local output
    output=$(hyprctl monitors 2>/dev/null) || return 1

    local name="" make="" model="" width="" height="" pos_x="" pos_y="" scale="" desc="" transform=""
    while IFS= read -r line; do
        if [[ "$line" =~ ^Monitor\ ([^ ]+) ]]; then
            # Save previous monitor if any
            if [[ -n "$name" ]]; then
                DETECTED_MONITORS+=("${name}|${make}|${model}|${width}|${height}|${pos_x}|${pos_y}|${scale}|${desc}|${transform}")
                ((MONITOR_COUNT++))
                if [[ "$name" == eDP-* ]]; then
                    LAPTOP_MONITOR="$name"
                fi
            fi
            name="${BASH_REMATCH[1]}"
            make="" model="" width="" height="" pos_x="" pos_y="" scale="" desc="" transform="0"
        elif [[ "$line" =~ ([0-9]+)x([0-9]+)@.*\ at\ (-?[0-9]+)x(-?[0-9]+) ]]; then
            width="${BASH_REMATCH[1]}"
            height="${BASH_REMATCH[2]}"
            pos_x="${BASH_REMATCH[3]}"
            pos_y="${BASH_REMATCH[4]}"
        elif [[ "$line" =~ scale:\ ([0-9.]+) ]]; then
            scale="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ transform:\ ([0-9]+) ]]; then
            transform="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ description:\ (.+) ]]; then
            desc="${BASH_REMATCH[1]}"
            # Parse make/model from description (format: "Make Model (name)")
            local desc_clean="${BASH_REMATCH[1]}"
            desc_clean="${desc_clean% (*}"
            make="${desc_clean%% *}"
            model="${desc_clean#* }"
            [[ "$make" == "$model" ]] && model=""
        fi
    done <<< "$output"

    # Save last monitor
    if [[ -n "$name" ]]; then
        DETECTED_MONITORS+=("${name}|${make}|${model}|${width}|${height}|${pos_x}|${pos_y}|${scale}|${desc}|${transform}")
        ((MONITOR_COUNT++))
        if [[ "$name" == eDP-* ]]; then
            LAPTOP_MONITOR="$name"
        fi
    fi

    return 0
}

# Show monitor detection dialog
show_monitor_detection_dialog() {
    clear
    echo
    echo
    echo -e "${BOLD}  Detect Monitors${RESET}"
    echo

    if ! detect_monitors; then
        echo -e "  ${DIM}✗${RESET}  hyprctl not available. Is Hyprland running?"
        echo
        echo -e "  ${DIM}Press any key to return...${RESET}"
        read -rsn1 < /dev/tty
        return
    fi

    if [ $MONITOR_COUNT -eq 0 ]; then
        echo -e "  ${DIM}No monitors detected.${RESET}"
        echo
        echo -e "  ${DIM}Press any key to return...${RESET}"
        read -rsn1 < /dev/tty
        return
    fi

    echo -e "  ${DIM}Found $MONITOR_COUNT monitor(s):${RESET}"
    echo

    local i=0
    local -a transform_labels=("Normal" "90°" "180°" "270°" "Flipped" "Flipped 90°" "Flipped 180°" "Flipped 270°")
    for entry in "${DETECTED_MONITORS[@]}"; do
        ((i++))
        IFS='|' read -r m_name m_make m_model m_w m_h m_x m_y m_scale m_desc m_transform <<< "$entry"
        local label=""
        [[ "$m_name" == eDP-* ]] && label=" (laptop)"
        local rot_label="${transform_labels[${m_transform:-0}]}"
        echo -e "    ${BOLD}$i.${RESET}  $m_name$label"
        echo -e "       ${DIM}Resolution: ${m_w}x${m_h}  Scale: ${m_scale}  Position: ${m_x},${m_y}  Rotation: ${rot_label}${RESET}"
        if [[ -n "$m_desc" ]]; then
            echo -e "       ${DIM}$m_desc${RESET}"
        fi
        echo
    done

    if [ $MONITOR_COUNT -ge 2 ]; then
        echo -e "  ${DIM}Press ${RESET}${BOLD}I${RESET}${DIM} to identify monitors (flash name on each screen)${RESET}"
    fi
    echo -e "  ${DIM}Press any other key to return...${RESET}"

    read -rsn1 key < /dev/tty
    if [[ "$key" == "i" || "$key" == "I" ]] && [ $MONITOR_COUNT -ge 2 ]; then
        identify_monitors
    fi
}

# Flash identification on each monitor
identify_monitors() {
    echo
    echo -e "  ${DIM}Identifying monitors...${RESET}"
    local i=0
    for entry in "${DETECTED_MONITORS[@]}"; do
        ((i++))
        IFS='|' read -r m_name _rest <<< "$entry"
        hyprctl dispatch focusmonitor "$m_name" &>/dev/null
        hyprctl notify 1 2000 "rgb(33ccff)" "fontsize:28 Monitor $i: $m_name" &>/dev/null
        sleep 2
    done
    echo -e "  ${DIM}Done. Press any key to return...${RESET}"
    read -rsn1 < /dev/tty
}

# Show position editor dialog
show_position_editor_dialog() {
    # Auto-detect if not already done
    if [ $MONITOR_COUNT -eq 0 ]; then
        if ! detect_monitors; then
            clear
            echo
            echo
            echo -e "${BOLD}  Position Monitors${RESET}"
            echo
            echo -e "  ${DIM}✗${RESET}  hyprctl not available. Is Hyprland running?"
            echo
            echo -e "  ${DIM}Press any key to return...${RESET}"
            read -rsn1 < /dev/tty
            return
        fi
    fi

    if [ $MONITOR_COUNT -le 1 ]; then
        clear
        echo
        echo
        echo -e "${BOLD}  Position Monitors${RESET}"
        echo
        echo -e "  ${DIM}Only one monitor detected. Nothing to position.${RESET}"
        echo
        echo -e "  ${DIM}Press any key to return...${RESET}"
        read -rsn1 < /dev/tty
        return
    fi

    # Build arrays of monitor names, widths, heights, scales, transforms
    local -a mon_names=() mon_widths=() mon_heights=() mon_scales=() mon_transforms=()
    for entry in "${DETECTED_MONITORS[@]}"; do
        IFS='|' read -r m_name m_make m_model m_w m_h m_x m_y m_scale m_desc m_transform <<< "$entry"
        mon_names+=("$m_name")
        mon_widths+=("$m_w")
        mon_heights+=("$m_h")
        mon_scales+=("$m_scale")
        mon_transforms+=("${m_transform:-0}")
    done

    # Rotation labels and values
    local -a rot_labels=("Normal (landscape)" "90° (portrait right)" "180° (inverted)" "270° (portrait left)")
    local -a rot_values=(0 1 2 3)

    # Helper: select rotation for a monitor, returns via rot_result
    select_rotation() {
        local mon_idx=$1
        local step_label="$2"
        local rot_cursor=0
        # Default to current transform if it's a simple rotation (0-3)
        local cur_t="${mon_transforms[$mon_idx]}"
        (( cur_t >= 0 && cur_t <= 3 )) && rot_cursor=$cur_t

        while true; do
            clear
            echo
            echo
            echo -e "${BOLD}  Position Monitors - ${step_label}${RESET}"
            echo
            local rlabel=""
            [[ "${mon_names[$mon_idx]}" == eDP-* ]] && rlabel=" (laptop)"
            echo -e "  ${DIM}Rotation for: ${RESET}${BOLD}${mon_names[$mon_idx]}${rlabel}${RESET}  ${DIM}${mon_widths[$mon_idx]}x${mon_heights[$mon_idx]}${RESET}"
            echo
            echo -e "  ${DIM}Select orientation:${RESET}"
            echo

            for ((r=0; r<4; r++)); do
                if [ $r -eq $rot_cursor ]; then
                    echo -e "    ${SELECTED_BG} > ${rot_labels[$r]} ${RESET}"
                else
                    echo -e "       ${rot_labels[$r]}"
                fi
            done

            echo
            echo -e "  ${DIM}Up/Down: Select  Enter: Confirm  Esc: Cancel${RESET}"

            IFS= read -rsn1 key < /dev/tty
            case "$key" in
                $'\x1b')
                    read -rsn2 -t 0.1 key
                    case "$key" in
                        '[A') ((rot_cursor > 0)) && ((rot_cursor--)) ;;
                        '[B') ((rot_cursor < 3)) && ((rot_cursor++)) ;;
                    esac
                    [[ -z "$key" ]] && return 1  # Bare escape = cancel
                    ;;
                '')
                    rot_result=${rot_values[$rot_cursor]}
                    return 0
                    ;;
                'q'|'Q')
                    return 1
                    ;;
            esac
        done
    }

    # Step 1: Select primary monitor
    local primary_idx=0
    local cursor=0
    while true; do
        clear
        echo
        echo
        echo -e "${BOLD}  Position Monitors - Step 1/3${RESET}"
        echo
        echo -e "  ${DIM}Select your primary monitor (placed at origin 0,0):${RESET}"
        echo

        for ((i=0; i<MONITOR_COUNT; i++)); do
            local label=""
            [[ "${mon_names[$i]}" == eDP-* ]] && label=" (laptop)"
            if [ $i -eq $cursor ]; then
                echo -e "    ${SELECTED_BG} > ${mon_names[$i]}${label}  ${mon_widths[$i]}x${mon_heights[$i]} ${RESET}"
            else
                echo -e "       ${mon_names[$i]}${label}  ${DIM}${mon_widths[$i]}x${mon_heights[$i]}${RESET}"
            fi
        done

        echo
        echo -e "  ${DIM}Up/Down: Select  Enter: Confirm  Esc: Cancel${RESET}"

        IFS= read -rsn1 key < /dev/tty
        case "$key" in
            $'\x1b')
                read -rsn2 -t 0.1 key
                case "$key" in
                    '[A') ((cursor > 0)) && ((cursor--)) ;;
                    '[B') ((cursor < MONITOR_COUNT - 1)) && ((cursor++)) ;;
                esac
                [[ -z "$key" ]] && return  # Bare escape = cancel
                ;;
            '')  # Enter
                primary_idx=$cursor
                break
                ;;
            'q'|'Q')
                return
                ;;
        esac
    done

    # Step 1b: Select rotation for primary monitor
    local rot_result=0
    select_rotation $primary_idx "Step 1/3" || return
    mon_transforms[$primary_idx]=$rot_result

    # Track placed monitors: index -> "x,y"
    local -A placed_positions=()
    local -a placed_order=()
    placed_positions[$primary_idx]="0,0"
    placed_order+=("$primary_idx")

    # Step 2: Position each remaining monitor
    local -a remaining=()
    for ((i=0; i<MONITOR_COUNT; i++)); do
        [ $i -ne $primary_idx ] && remaining+=("$i")
    done

    for rem_idx in "${remaining[@]}"; do
        # Select reference monitor (which placed monitor to position relative to)
        local ref_cursor=0
        local ref_idx=${placed_order[0]}
        while true; do
            clear
            echo
            echo
            echo -e "${BOLD}  Position Monitors - Step 2/3${RESET}"
            echo
            local rem_label=""
            [[ "${mon_names[$rem_idx]}" == eDP-* ]] && rem_label=" (laptop)"
            echo -e "  ${DIM}Placing: ${RESET}${BOLD}${mon_names[$rem_idx]}${rem_label}${RESET}  ${DIM}${mon_widths[$rem_idx]}x${mon_heights[$rem_idx]}${RESET}"
            echo
            echo -e "  ${DIM}Position relative to which monitor?${RESET}"
            echo

            for ((p=0; p<${#placed_order[@]}; p++)); do
                local pi=${placed_order[$p]}
                local plabel=""
                [[ "${mon_names[$pi]}" == eDP-* ]] && plabel=" (laptop)"
                local ppos="${placed_positions[$pi]}"
                if [ $p -eq $ref_cursor ]; then
                    echo -e "    ${SELECTED_BG} > ${mon_names[$pi]}${plabel}  at ${ppos} ${RESET}"
                else
                    echo -e "       ${mon_names[$pi]}${plabel}  ${DIM}at ${ppos}${RESET}"
                fi
            done

            echo
            echo -e "  ${DIM}Up/Down: Select  Enter: Confirm  Esc: Cancel${RESET}"

            IFS= read -rsn1 key < /dev/tty
            case "$key" in
                $'\x1b')
                    read -rsn2 -t 0.1 key
                    case "$key" in
                        '[A') ((ref_cursor > 0)) && ((ref_cursor--)) ;;
                        '[B') ((ref_cursor < ${#placed_order[@]} - 1)) && ((ref_cursor++)) ;;
                    esac
                    [[ -z "$key" ]] && return  # Bare escape = cancel
                    ;;
                '')
                    ref_idx=${placed_order[$ref_cursor]}
                    break
                    ;;
                'q'|'Q')
                    return
                    ;;
            esac
        done

        # Select direction
        local -a directions=("Right of" "Left of" "Above" "Below")
        local dir_cursor=0
        while true; do
            clear
            echo
            echo
            echo -e "${BOLD}  Position Monitors - Step 2/3${RESET}"
            echo
            local rem_label=""
            [[ "${mon_names[$rem_idx]}" == eDP-* ]] && rem_label=" (laptop)"
            echo -e "  ${DIM}Placing: ${RESET}${BOLD}${mon_names[$rem_idx]}${rem_label}${RESET}"
            echo -e "  ${DIM}Relative to: ${RESET}${mon_names[$ref_idx]}"
            echo
            echo -e "  ${DIM}Which direction?${RESET}"
            echo

            for ((d=0; d<4; d++)); do
                if [ $d -eq $dir_cursor ]; then
                    echo -e "    ${SELECTED_BG} > ${directions[$d]} ${RESET}"
                else
                    echo -e "       ${directions[$d]}"
                fi
            done

            echo
            echo -e "  ${DIM}Up/Down: Select  Enter: Confirm  Esc: Cancel${RESET}"

            IFS= read -rsn1 key < /dev/tty
            case "$key" in
                $'\x1b')
                    read -rsn2 -t 0.1 key
                    case "$key" in
                        '[A') ((dir_cursor > 0)) && ((dir_cursor--)) ;;
                        '[B') ((dir_cursor < 3)) && ((dir_cursor++)) ;;
                    esac
                    [[ -z "$key" ]] && return  # Bare escape = cancel
                    ;;
                '')
                    break
                    ;;
                'q'|'Q')
                    return
                    ;;
            esac
        done

        # Select rotation for this monitor
        select_rotation $rem_idx "Step 2/3" || return
        mon_transforms[$rem_idx]=$rot_result

        # Calculate position using Hyprland's snapped scale and rounded dimensions
        # Hyprland snaps scale to nearest 1/120: round(scale*120)/120
        # then computes logical size as round(resolution / snapped_scale)
        # For 90°/270° rotation (transform 1,3), swap width and height
        local ref_pos="${placed_positions[$ref_idx]}"
        local ref_x="${ref_pos%,*}"
        local ref_y="${ref_pos#*,}"
        local ref_scale="${mon_scales[$ref_idx]}"
        local rem_scale="${mon_scales[$rem_idx]}"
        local ref_t="${mon_transforms[$ref_idx]}"
        local rem_t="${mon_transforms[$rem_idx]}"

        # Get raw logical dimensions (before rotation)
        local ref_lw ref_lh rem_lw rem_lh
        ref_lw=$(awk "BEGIN { s=int($ref_scale*120+0.5)/120; printf \"%d\", int(${mon_widths[$ref_idx]}/s+0.5) }")
        ref_lh=$(awk "BEGIN { s=int($ref_scale*120+0.5)/120; printf \"%d\", int(${mon_heights[$ref_idx]}/s+0.5) }")
        rem_lw=$(awk "BEGIN { s=int($rem_scale*120+0.5)/120; printf \"%d\", int(${mon_widths[$rem_idx]}/s+0.5) }")
        rem_lh=$(awk "BEGIN { s=int($rem_scale*120+0.5)/120; printf \"%d\", int(${mon_heights[$rem_idx]}/s+0.5) }")

        # Apply rotation: 90° and 270° swap width/height
        local ref_ew=$ref_lw ref_eh=$ref_lh rem_ew=$rem_lw rem_eh=$rem_lh
        if (( ref_t == 1 || ref_t == 3 )); then
            ref_ew=$ref_lh
            ref_eh=$ref_lw
        fi
        if (( rem_t == 1 || rem_t == 3 )); then
            rem_ew=$rem_lh
            rem_eh=$rem_lw
        fi

        local new_x=0 new_y=0
        case $dir_cursor in
            0) # Right of
                new_x=$((ref_x + ref_ew))
                new_y=$ref_y
                ;;
            1) # Left of
                new_x=$((ref_x - rem_ew))
                new_y=$ref_y
                ;;
            2) # Above
                new_x=$ref_x
                new_y=$((ref_y - rem_eh))
                ;;
            3) # Below
                new_x=$ref_x
                new_y=$((ref_y + ref_eh))
                ;;
        esac

        placed_positions[$rem_idx]="${new_x},${new_y}"
        placed_order+=("$rem_idx")
    done

    # Step 3: Preview
    local -a preview_rot_labels=("Normal" "90°" "180°" "270°")
    clear
    echo
    echo
    echo -e "${BOLD}  Position Monitors - Step 3/3 Preview${RESET}"
    echo
    echo -e "  ${DIM}Monitor layout:${RESET}"
    echo

    for ((i=0; i<MONITOR_COUNT; i++)); do
        local pos="${placed_positions[$i]}"
        local px="${pos%,*}"
        local py="${pos#*,}"
        local label=""
        [[ "${mon_names[$i]}" == eDP-* ]] && label=" (laptop)"
        local primary_tag=""
        [ $i -eq $primary_idx ] && primary_tag=" [primary]"
        local t="${mon_transforms[$i]}"
        local rot_info="${preview_rot_labels[$t]}"
        echo -e "    ${BOLD}${mon_names[$i]}${RESET}${label}${primary_tag}"
        echo -e "      ${DIM}Resolution: ${mon_widths[$i]}x${mon_heights[$i]}  Scale: ${mon_scales[$i]}  Rotation: ${rot_info}${RESET}"
        echo -e "      ${DIM}Position: ${px}x${py}${RESET}"
        echo
    done

    echo -e "  ${DIM}Note: Displays may briefly go black while Hyprland reconfigures.${RESET}"
    echo
    printf "  ${BOLD}Apply this layout?${RESET} ${DIM}(yes/no)${RESET} "
    read -r < /dev/tty

    if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        # Populate global state
        MONITOR_POSITIONS=()
        MONITOR_TRANSFORMS=()
        for ((i=0; i<MONITOR_COUNT; i++)); do
            MONITOR_POSITIONS["${mon_names[$i]}"]="${placed_positions[$i]}"
            MONITOR_TRANSFORMS["${mon_names[$i]}"]="${mon_transforms[$i]}"
        done
        MONITORS_POSITIONED=1
        echo
        echo -e "  ${DIM}Layout queued. Will be applied on confirm.${RESET}"
    else
        echo
        echo -e "  ${DIM}Cancelled.${RESET}"
    fi
    echo
    echo -e "  ${DIM}Press any key to return...${RESET}"
    read -rsn1 < /dev/tty
}

# Apply monitor positions to monitors.conf
apply_monitor_positions() {
    clear
    echo
    echo
    echo -e "${BOLD}  Apply Monitor Positions${RESET}"
    echo

    if [[ ! -f "$MONITORS_CONF" ]]; then
        echo -e "  ${DIM}✗${RESET}  monitors.conf not found at $MONITORS_CONF"
        echo
        SUMMARY_LOG+=("✗  Monitor positions -- failed (config not found)")
        return 1
    fi

    echo

    # Create backup
    local backup_file="${MONITORS_CONF}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$MONITORS_CONF" "$backup_file"
    echo -e "    ${DIM}Backup saved: $backup_file${RESET}"

    # Determine GDK_SCALE: use 1.75 if any monitor has scale > 1.5
    local gdk_scale=1
    for entry in "${DETECTED_MONITORS[@]}"; do
        IFS='|' read -r _n _mk _mo _w _h _x _y m_scale _d <<< "$entry"
        if awk "BEGIN { exit !($m_scale > 1.5) }"; then
            gdk_scale="1.75"
            break
        fi
    done

    # Apply positions and transforms live via hyprctl keyword
    for entry in "${DETECTED_MONITORS[@]}"; do
        IFS='|' read -r m_name _mk _mo _w _h _x _y m_scale _d _t <<< "$entry"
        local pos="${MONITOR_POSITIONS[$m_name]:-auto}"
        local transform="${MONITOR_TRANSFORMS[$m_name]:-0}"
        if [[ "$pos" != "auto" ]]; then
            local px="${pos%,*}"
            local py="${pos#*,}"
            hyprctl keyword monitor "${m_name},preferred,${px}x${py},${m_scale},transform,${transform}" &>/dev/null
        else
            hyprctl keyword monitor "${m_name},preferred,auto,${m_scale},transform,${transform}" &>/dev/null
        fi
    done
    echo -e "    ${CHECKED}✓${RESET}  Monitor layout applied live"

    # Preserve managed blocks before overwriting
    save_managed_blocks

    # Save to config file for persistence
    {
        echo "# See https://wiki.hyprland.org/Configuring/Monitors/"
        echo "# Configured by A La Carchy - multi-monitor layout"
        echo "# Format: monitor = name, resolution, position, scale"
        echo ""
        echo "env = GDK_SCALE,$gdk_scale"
        echo ""
        for entry in "${DETECTED_MONITORS[@]}"; do
            IFS='|' read -r m_name _mk _mo _w _h _x _y m_scale _d _t <<< "$entry"
            local pos="${MONITOR_POSITIONS[$m_name]:-auto}"
            local transform="${MONITOR_TRANSFORMS[$m_name]:-0}"
            if [[ "$pos" != "auto" ]]; then
                local px="${pos%,*}"
                local py="${pos#*,}"
                echo "monitor=${m_name},preferred,${px}x${py},${m_scale},transform,${transform}"
            else
                echo "monitor=${m_name},preferred,auto,${m_scale},transform,${transform}"
            fi
        done
        echo ""
        echo "# Fallback for hot-plugged displays"
        echo "monitor=,preferred,auto,1"
    } > "$MONITORS_CONF"

    # Restore managed blocks (power-profile, laptop-auto-off, etc.)
    restore_managed_blocks

    echo -e "    ${CHECKED}✓${RESET}  Config saved to monitors.conf"
    SUMMARY_LOG+=("✓  Monitor layout configured")
    echo
    echo
}

# Enable laptop auto-off (disable laptop screen when external connected)
setup_laptop_auto_off() {
    clear
    echo
    echo
    echo -e "${BOLD}  Laptop Display Auto-Off${RESET}"
    echo

    # Detect laptop monitor if not already found
    if [[ -z "$LAPTOP_MONITOR" ]]; then
        detect_monitors
    fi

    if [[ -z "$LAPTOP_MONITOR" ]]; then
        echo -e "  ${DIM}✗${RESET}  No laptop display (eDP-*) detected."
        echo
        SUMMARY_LOG+=("✗  Laptop auto-off -- no laptop display found")
        return 1
    fi

    echo -e "  ${DIM}Laptop display: $LAPTOP_MONITOR${RESET}"
    echo -e "  ${DIM}Will auto-disable when external display is connected.${RESET}"
    echo

    # Create scripts directory
    mkdir -p "$(dirname "$LAPTOP_AUTO_SCRIPT")"

    # Detect the backlight device for this laptop
    local backlight_dev=""
    for bl in /sys/class/backlight/*/; do
        [[ -d "$bl" ]] || continue
        local bl_name="${bl%/}"
        bl_name="${bl_name##*/}"
        backlight_dev="$bl_name"
        # Prefer intel_backlight over others
        [[ "$bl_name" == *intel* ]] && break
    done

    if [[ -z "$backlight_dev" ]]; then
        echo -e "  ${DIM}✗${RESET}  No backlight device found in /sys/class/backlight/"
        echo
        SUMMARY_LOG+=("✗  Laptop auto-off -- no backlight device found")
        return 1
    fi

    echo -e "  ${DIM}Backlight device: $backlight_dev${RESET}"

    # Get current brightness to use as default restore value
    local current_brightness
    current_brightness=$(brightnessctl -d "$backlight_dev" g 2>/dev/null)
    [[ -z "$current_brightness" || "$current_brightness" == "0" ]] && current_brightness=9600

    # Write watcher script
    cat > "$LAPTOP_AUTO_SCRIPT" << SCRIPTEOF
#!/bin/bash
# Managed by A La Carchy - auto-disable laptop screen on external display
LAPTOP="$LAPTOP_MONITOR"
BACKLIGHT="$backlight_dev"
DEFAULT_BRIGHTNESS=$current_brightness
SAVED_BRIGHTNESS=""

handle_change() {
    sleep 1  # debounce rapid events
    # Count non-laptop monitors (external displays only)
    local external_count
    external_count=\$(hyprctl monitors | grep "^Monitor " | grep -cv "^Monitor eDP")

    if (( external_count >= 1 )); then
        # External display connected - disable laptop and turn off backlight
        if [[ -z "\$SAVED_BRIGHTNESS" ]]; then
            SAVED_BRIGHTNESS=\$(brightnessctl -d "\$BACKLIGHT" g 2>/dev/null)
            [[ -z "\$SAVED_BRIGHTNESS" || "\$SAVED_BRIGHTNESS" == "0" ]] && SAVED_BRIGHTNESS=\$DEFAULT_BRIGHTNESS
        fi
        hyprctl keyword monitor "\$LAPTOP, disable" &>/dev/null
        brightnessctl -d "\$BACKLIGHT" s 0 &>/dev/null
    else
        # No external display - restore laptop
        brightnessctl -d "\$BACKLIGHT" s "\${SAVED_BRIGHTNESS:-\$DEFAULT_BRIGHTNESS}" &>/dev/null
        hyprctl keyword monitor "\$LAPTOP, preferred, auto, 1" &>/dev/null
    fi
}

# Handle initial state
handle_change

# Watch for monitor events via Hyprland IPC socket
SOCKET="\$XDG_RUNTIME_DIR/hypr/\$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
if command -v socat &>/dev/null; then
    socat -U - UNIX-CONNECT:"\$SOCKET" 2>/dev/null
elif command -v nc &>/dev/null; then
    nc -U "\$SOCKET" 2>/dev/null
else
    # Fallback: poll every 5 seconds
    while true; do
        sleep 5
        handle_change
    done &
    wait
    exit 0
fi | while read -r line; do
    case "\$line" in
        monitoradded*|monitorremoved*) handle_change ;;
    esac
done
SCRIPTEOF

    chmod +x "$LAPTOP_AUTO_SCRIPT"
    echo -e "    ${CHECKED}✓${RESET}  Watcher script created: $LAPTOP_AUTO_SCRIPT"

    # Add exec-once to monitors.conf using managed block
    if ! grep -q "$LAPTOP_AUTO_MARKER_START" "$MONITORS_CONF" 2>/dev/null; then
        {
            echo ""
            echo "$LAPTOP_AUTO_MARKER_START"
            echo "exec-once = $LAPTOP_AUTO_SCRIPT"
            echo "$LAPTOP_AUTO_MARKER_END"
        } >> "$MONITORS_CONF"
        echo -e "    ${CHECKED}✓${RESET}  Added exec-once to monitors.conf"
    else
        echo -e "    ${DIM}exec-once already present in monitors.conf${RESET}"
    fi

    # Start the script now (exec-once only runs at Hyprland startup)
    pkill -f "laptop-display-auto.sh" 2>/dev/null
    nohup "$LAPTOP_AUTO_SCRIPT" &>/dev/null &
    echo -e "    ${CHECKED}✓${RESET}  Watcher started"

    SUMMARY_LOG+=("✓  Laptop display auto-off enabled")
    echo
    echo
}

# Disable laptop auto-off
remove_laptop_auto_off() {
    clear
    echo
    echo
    echo -e "${BOLD}  Disable Laptop Display Auto-Off${RESET}"
    echo

    # Remove managed block from monitors.conf
    if [[ -f "$MONITORS_CONF" ]] && grep -q "$LAPTOP_AUTO_MARKER_START" "$MONITORS_CONF" 2>/dev/null; then
        sed -i "/$LAPTOP_AUTO_MARKER_START/,/$LAPTOP_AUTO_MARKER_END/d" "$MONITORS_CONF"
        # Remove trailing blank lines
        sed -i -e :a -e '/^\n*$/{$d;N;ba' -e '}' "$MONITORS_CONF"
        echo -e "    ${CHECKED}✓${RESET}  Removed exec-once from monitors.conf"
    fi

    # Remove script
    if [[ -f "$LAPTOP_AUTO_SCRIPT" ]]; then
        rm -f "$LAPTOP_AUTO_SCRIPT"
        echo -e "    ${CHECKED}✓${RESET}  Removed watcher script"
    fi

    # Kill any running instance
    pkill -f "laptop-display-auto.sh" 2>/dev/null

    # Restore backlight (find the backlight device)
    for bl in /sys/class/backlight/*/; do
        [[ -d "$bl" ]] || continue
        local bl_name="${bl%/}"
        bl_name="${bl_name##*/}"
        brightnessctl -d "$bl_name" s 9600 &>/dev/null
        [[ "$bl_name" == *intel* ]] && break
    done

    # Re-enable laptop monitor if we know its name
    if [[ -z "$LAPTOP_MONITOR" ]]; then
        detect_monitors
    fi
    if [[ -n "$LAPTOP_MONITOR" ]]; then
        hyprctl keyword monitor "$LAPTOP_MONITOR, preferred, auto, 1" &>/dev/null
        echo -e "    ${CHECKED}✓${RESET}  Re-enabled $LAPTOP_MONITOR"
    fi

    SUMMARY_LOG+=("✓  Laptop display auto-off disabled")
    echo
    echo
}

# Show power profile selection dialog
show_power_profile_dialog() {
    if ! command -v powerprofilesctl &>/dev/null; then
        clear
        echo
        echo
        echo -e "${BOLD}  Power Profile${RESET}"
        echo
        echo -e "  ${DIM}✗${RESET}  powerprofilesctl not found."
        echo -e "  ${DIM}Install power-profiles-daemon to use this feature.${RESET}"
        echo
        echo -e "  ${DIM}Press any key to return...${RESET}"
        read -rsn1 < /dev/tty
        return
    fi

    # Get current active profile
    local active_profile
    active_profile=$(powerprofilesctl get 2>/dev/null)

    # Check if a default is already configured
    local configured_default=""
    if [[ -f "$POWER_PROFILE_SCRIPT" ]]; then
        configured_default=$(grep -oP 'powerprofilesctl set \K\S+' "$POWER_PROFILE_SCRIPT" 2>/dev/null)
    fi

    local -a profiles=("power-saver" "balanced" "performance")
    local -a labels=("Power saver" "Balanced" "Performance")
    local opt_cursor=1  # Default to balanced

    # Set cursor to current active profile
    for i in "${!profiles[@]}"; do
        if [[ "${profiles[$i]}" == "$active_profile" ]]; then
            opt_cursor=$i
            break
        fi
    done

    while true; do
        clear
        echo
        echo -e "  ${BOLD}Power Profile${RESET}"
        echo -e "  ${DIM}Set default power profile restored on startup${RESET}"
        echo
        echo -e "  ${DIM}Select profile (Up/Down, Enter to confirm):${RESET}"
        echo

        for i in "${!profiles[@]}"; do
            local suffix=""
            [[ "${profiles[$i]}" == "$active_profile" ]] && suffix=" (active)"
            [[ "${profiles[$i]}" == "$configured_default" ]] && suffix="${suffix} (default)"
            if [[ $i -eq $opt_cursor ]]; then
                echo -e "    ${SELECTED_BG}> ${labels[$i]}${suffix}${RESET}"
            else
                echo -e "      ${labels[$i]}${suffix}"
            fi
        done

        echo
        echo -e "  ${DIM}Escape: cancel${RESET}"

        IFS= read -rsn1 key < /dev/tty
        case "$key" in
            $'\x1b')
                read -rsn2 -t 0.1 key
                case "$key" in
                    '[A') (( opt_cursor > 0 )) && ((opt_cursor--)) ;;
                    '[B') (( opt_cursor < ${#profiles[@]} - 1 )) && ((opt_cursor++)) ;;
                esac
                [[ -z "$key" ]] && return  # Bare escape = cancel
                ;;
            ''|q|Q)  # Enter or Q
                if [[ -z "$key" ]]; then
                    # Enter - confirm selection
                    SELECTED_POWER_PROFILE="${profiles[$opt_cursor]}"
                    clear
                    echo
                    echo -e "  ${BOLD}Power Profile${RESET}"
                    echo
                    echo -e "  ${CHECKED}✓${RESET}  ${labels[$opt_cursor]} queued for apply"
                    echo
                    echo -e "  ${DIM}Press any key to return...${RESET}"
                    read -rsn1 < /dev/tty
                    return
                else
                    return  # Q = cancel
                fi
                ;;
        esac
    done
}

# Apply the selected power profile and configure startup persistence
apply_power_profile() {
    clear
    echo
    echo
    echo -e "${BOLD}  Set Power Profile: $SELECTED_POWER_PROFILE${RESET}"
    echo

    # Set profile immediately
    if powerprofilesctl set "$SELECTED_POWER_PROFILE" 2>/dev/null; then
        echo -e "    ${CHECKED}✓${RESET}  Profile set to $SELECTED_POWER_PROFILE"
    else
        echo -e "    ${DIM}✗${RESET}  Failed to set profile"
        SUMMARY_LOG+=("✗  Power profile -- failed to set")
        return 1
    fi

    # Create scripts directory
    mkdir -p "$(dirname "$POWER_PROFILE_SCRIPT")"

    # Write startup script
    cat > "$POWER_PROFILE_SCRIPT" << SCRIPTEOF
#!/bin/bash
# Managed by A La Carchy - default power profile on startup
powerprofilesctl set $SELECTED_POWER_PROFILE
SCRIPTEOF

    chmod +x "$POWER_PROFILE_SCRIPT"
    echo -e "    ${CHECKED}✓${RESET}  Startup script created: $POWER_PROFILE_SCRIPT"

    # Add/replace managed block in monitors.conf
    if grep -q "$POWER_PROFILE_MARKER_START" "$MONITORS_CONF" 2>/dev/null; then
        sed -i "/$POWER_PROFILE_MARKER_START/,/$POWER_PROFILE_MARKER_END/d" "$MONITORS_CONF"
        # Remove trailing blank lines
        sed -i -e :a -e '/^\n*$/{$d;N;ba' -e '}' "$MONITORS_CONF"
    fi

    {
        echo ""
        echo "$POWER_PROFILE_MARKER_START"
        echo "exec-once = $POWER_PROFILE_SCRIPT"
        echo "$POWER_PROFILE_MARKER_END"
    } >> "$MONITORS_CONF"
    echo -e "    ${CHECKED}✓${RESET}  Added exec-once to monitors.conf"

    SUMMARY_LOG+=("✓  Power profile set to $SELECTED_POWER_PROFILE")
    echo
    echo
}

show_battery_limit_dialog() {
    # Auto-detect battery device with charge limit support
    local bat_threshold=""
    for path in /sys/class/power_supply/BAT*/charge_control_end_threshold; do
        [[ -f "$path" ]] && { bat_threshold="$path"; break; }
    done

    if [[ -z "$bat_threshold" ]]; then
        clear
        echo
        echo
        echo -e "${BOLD}  Battery Charge Limit${RESET}"
        echo
        echo -e "  ${DIM}✗${RESET}  No battery with charge limit support detected."
        echo -e "  ${DIM}Your hardware may not expose charge_control_end_threshold.${RESET}"
        echo
        echo -e "  ${DIM}Press any key to return...${RESET}"
        read -rsn1 < /dev/tty
        return
    fi

    # Read current threshold from sysfs
    local current_threshold
    current_threshold=$(cat "$bat_threshold" 2>/dev/null)

    # Check if udev rule already exists (configured default)
    local configured_default=""
    if [[ -f "$BATTERY_LIMIT_UDEV_RULE" ]]; then
        configured_default=$(grep -oP 'charge_control_end_threshold="\K[0-9]+' "$BATTERY_LIMIT_UDEV_RULE" 2>/dev/null)
    fi

    local -a values=("60" "80" "90" "100")
    local -a labels=(
        "60%  — Maximum longevity"
        "80%  — Recommended"
        "90%  — Slight protection"
        "100% — No limit (full charge)"
    )
    local opt_cursor=1  # Default to 80%

    # Set cursor to current threshold
    for i in "${!values[@]}"; do
        if [[ "${values[$i]}" == "$current_threshold" ]]; then
            opt_cursor=$i
            break
        fi
    done

    while true; do
        clear
        echo
        echo -e "  ${BOLD}Battery Charge Limit${RESET}"
        echo -e "  ${DIM}Set maximum charge level to extend battery lifespan${RESET}"
        echo
        echo -e "  ${DIM}Select limit (Up/Down, Enter to confirm):${RESET}"
        echo

        for i in "${!values[@]}"; do
            local suffix=""
            [[ "${values[$i]}" == "$current_threshold" ]] && suffix=" (current)"
            [[ "${values[$i]}" == "$configured_default" ]] && suffix="${suffix} (default)"
            if [[ $i -eq $opt_cursor ]]; then
                echo -e "    ${SELECTED_BG}> ${labels[$i]}${suffix}${RESET}"
            else
                echo -e "      ${labels[$i]}${suffix}"
            fi
        done

        echo
        echo -e "  ${DIM}Escape: cancel${RESET}"

        IFS= read -rsn1 key < /dev/tty
        case "$key" in
            $'\x1b')
                read -rsn2 -t 0.1 key
                case "$key" in
                    '[A') (( opt_cursor > 0 )) && ((opt_cursor--)) ;;
                    '[B') (( opt_cursor < ${#values[@]} - 1 )) && ((opt_cursor++)) ;;
                esac
                [[ -z "$key" ]] && return  # Bare escape = cancel
                ;;
            ''|q|Q)  # Enter or Q
                if [[ -z "$key" ]]; then
                    # Enter - confirm selection
                    SELECTED_BATTERY_LIMIT="${values[$opt_cursor]}"
                    clear
                    echo
                    echo -e "  ${BOLD}Battery Charge Limit${RESET}"
                    echo
                    echo -e "  ${CHECKED}✓${RESET}  ${labels[$opt_cursor]} queued for apply"
                    echo
                    echo -e "  ${DIM}Press any key to return...${RESET}"
                    read -rsn1 < /dev/tty
                    return
                else
                    return  # Q = cancel
                fi
                ;;
        esac
    done
}

# Apply the selected battery charge limit and configure udev persistence
apply_battery_limit() {
    clear
    echo
    echo
    echo -e "${BOLD}  Set Battery Charge Limit: ${SELECTED_BATTERY_LIMIT}%${RESET}"
    echo

    # Request sudo credentials
    if ! sudo -n true 2>/dev/null; then
        echo -e "  ${DIM}Sudo access required to set charge limit...${RESET}"
        sudo true || {
            echo -e "    ${DIM}✗${RESET}  Failed to get sudo access"
            SUMMARY_LOG+=("✗  Battery charge limit -- failed (no sudo)")
            return 1
        }
    fi

    # Find battery threshold path
    local bat_threshold=""
    for path in /sys/class/power_supply/BAT*/charge_control_end_threshold; do
        [[ -f "$path" ]] && { bat_threshold="$path"; break; }
    done

    # Apply immediately
    if echo "$SELECTED_BATTERY_LIMIT" | sudo tee "$bat_threshold" > /dev/null 2>&1; then
        echo -e "    ${CHECKED}✓${RESET}  Charge limit set to ${SELECTED_BATTERY_LIMIT}%"
    else
        echo -e "    ${DIM}✗${RESET}  Failed to set charge limit"
        SUMMARY_LOG+=("✗  Battery charge limit -- failed to set")
        return 1
    fi

    # Handle udev rule for persistence
    if [[ "$SELECTED_BATTERY_LIMIT" == "100" ]]; then
        # No limit - remove udev rule if it exists
        if [[ -f "$BATTERY_LIMIT_UDEV_RULE" ]]; then
            sudo rm -f "$BATTERY_LIMIT_UDEV_RULE"
            echo -e "    ${CHECKED}✓${RESET}  Removed udev rule (no limit)"
        fi
    else
        # Write udev rule for persistence
        printf '# Managed by A La Carchy - battery charge limit\nSUBSYSTEM=="power_supply", KERNEL=="BAT*", ATTR{charge_control_end_threshold}="%s"\n' \
            "$SELECTED_BATTERY_LIMIT" | sudo tee "$BATTERY_LIMIT_UDEV_RULE" > /dev/null
        echo -e "    ${CHECKED}✓${RESET}  Udev rule written: $BATTERY_LIMIT_UDEV_RULE"
    fi

    # Reload udev rules
    sudo udevadm control --reload-rules 2>/dev/null
    echo -e "    ${CHECKED}✓${RESET}  Udev rules reloaded"

    # Update waybar battery tooltip and format-plugged to show charge limit
    if [[ -f "$WAYBAR_CONF" ]]; then
        # Read format-full icon to reuse for format-plugged when limit is active
        local bat_full_icon
        bat_full_icon=$(sed -n 's/.*"format-full": "\([^"]*\)".*/\1/p' "$WAYBAR_CONF" | head -1)

        # Save original format-plugged value before first modification
        # (stored as a comment in the battery section for later restore)
        if ! grep -q 'a-la-carchy-original-plugged' "$WAYBAR_CONF"; then
            local orig_plugged
            orig_plugged=$(sed -n 's/.*"format-plugged": "\([^"]*\)".*/\1/p' "$WAYBAR_CONF" | head -1)
            sed -i "s|\"format-plugged\":|\\/\\/ a-la-carchy-original-plugged: \"${orig_plugged}\"\n    \"format-plugged\":|" "$WAYBAR_CONF"
        fi

        # Strip any existing limit annotations from tooltips
        sed -i 's/ (limit: [0-9]*%)//g' "$WAYBAR_CONF"
        # Remove tooltip-format-full if added by us (value is "Full" after stripping limit)
        sed -i '/"tooltip-format-full": "Full"/d' "$WAYBAR_CONF"
        # Remove tooltip-format-plugged (always managed by us)
        sed -i '/"tooltip-format-plugged":/d' "$WAYBAR_CONF"

        if [[ "$SELECTED_BATTERY_LIMIT" != "100" ]]; then
            # Append limit to discharging/charging tooltips
            sed -i "s/\(\"tooltip-format-discharging\": \"[^\"]*\)\"/\1 (limit: ${SELECTED_BATTERY_LIMIT}%)\"/" "$WAYBAR_CONF"
            sed -i "s/\(\"tooltip-format-charging\": \"[^\"]*\)\"/\1 (limit: ${SELECTED_BATTERY_LIMIT}%)\"/" "$WAYBAR_CONF"

            # Add or update tooltip-format-full
            if grep -q '"tooltip-format-full"' "$WAYBAR_CONF"; then
                sed -i "s/\(\"tooltip-format-full\": \"[^\"]*\)\"/\1 (limit: ${SELECTED_BATTERY_LIMIT}%)\"/" "$WAYBAR_CONF"
            else
                sed -i "/\"tooltip-format-charging\"/a\\    \"tooltip-format-full\": \"Full (limit: ${SELECTED_BATTERY_LIMIT}%)\"," "$WAYBAR_CONF"
            fi

            # Set format-plugged to battery full icon (instead of plug icon)
            sed -i "s|\"format-plugged\": \"[^\"]*\"|\"format-plugged\": \"${bat_full_icon}\"|" "$WAYBAR_CONF"
            # Add tooltip for plugged state (at limit, AC connected)
            sed -i "/\"tooltip-format-full\"/a\\    \"tooltip-format-plugged\": \"{capacity}% plugged (limit: ${SELECTED_BATTERY_LIMIT}%)\"," "$WAYBAR_CONF"
        else
            # Restore original format-plugged value
            local orig_plugged
            orig_plugged=$(sed -n 's|.*// a-la-carchy-original-plugged: "\([^"]*\)".*|\1|p' "$WAYBAR_CONF" | head -1)
            sed -i "s|\"format-plugged\": \"[^\"]*\"|\"format-plugged\": \"${orig_plugged}\"|" "$WAYBAR_CONF"
            # Remove the saved original comment
            sed -i '/a-la-carchy-original-plugged/d' "$WAYBAR_CONF"
        fi

        # Restart waybar to apply tooltip changes
        if command -v omarchy-restart-waybar &>/dev/null; then
            omarchy-restart-waybar &>/dev/null || true
        fi
        echo -e "    ${CHECKED}✓${RESET}  Waybar battery tooltip updated"
    fi

    SUMMARY_LOG+=("✓  Battery charge limit set to ${SELECTED_BATTERY_LIMIT}%")
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
    echo -e "${BOLD}  Enable Rounded Corners${RESET}"
    echo
    echo -e "  ${DIM}Adds rounded corners to windows, menus, notifications,${RESET}"
    echo -e "  ${DIM}and other UI elements (rounding = 8).${RESET}"
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

    echo -e "  ${CHECKED}✓${RESET}  Hyprland windows — rounded"
    SUMMARY_LOG+=("✓  Enabled rounded corners")

    # Walker (launcher/menus)
    local walker_css="$HOME/.local/share/omarchy/default/walker/themes/omarchy-default/style.css"
    if [[ -f "$walker_css" ]]; then
        if ! grep -q 'border-radius' "$walker_css"; then
            sed -i '/\.box-wrapper {/,/}/ s/border: 2px solid @border;/border: 2px solid @border;\n  border-radius: 8px;/' "$walker_css"
            echo -e "  ${CHECKED}✓${RESET}  Walker menus — rounded"
        fi
    fi

    # SwayOSD (volume/brightness overlay)
    local swayosd_css="$HOME/.config/swayosd/style.css"
    if [[ -f "$swayosd_css" ]]; then
        sed -i '/^window {/,/}/ s/border-radius: 0;/border-radius: 8px;/' "$swayosd_css"
        sed -i '/^progressbar {/,/}/ s/border-radius: 0;/border-radius: 8px;/' "$swayosd_css"
        echo -e "  ${CHECKED}✓${RESET}  SwayOSD overlay — rounded"
    fi

    # Hyprlock (lock screen password input)
    local hyprlock_conf="$HOME/.config/hypr/hyprlock.conf"
    if [[ -f "$hyprlock_conf" ]]; then
        sed -i '/^input-field {/,/}/ s/rounding = 0/rounding = 8/' "$hyprlock_conf"
        echo -e "  ${CHECKED}✓${RESET}  Hyprlock password field — rounded"
    fi

    # Mako (notifications)
    local mako_ini="$HOME/.local/share/omarchy/default/mako/core.ini"
    if [[ -f "$mako_ini" ]]; then
        if ! grep -q 'border-radius' "$mako_ini"; then
            sed -i '/^border-size=/a border-radius=8' "$mako_ini"
            echo -e "  ${CHECKED}✓${RESET}  Mako notifications — rounded"
        fi
    fi

    # Waybar tooltips (need both tooltip and tooltip * to override global * border-radius: 0)
    if [[ -f "$WAYBAR_CONF_STYLE" ]]; then
        if ! grep -q 'tooltip.*border-radius' "$WAYBAR_CONF_STYLE"; then
            sed -i '/^tooltip {/,/}/ s/padding: 2px;/padding: 2px;\n  border-radius: 8px;/' "$WAYBAR_CONF_STYLE"
        fi
        if ! grep -q '^tooltip \*' "$WAYBAR_CONF_STYLE"; then
            sed -i '/^tooltip {/,/^}/ { /^}/a\
\
tooltip * {\
  border-radius: 8px;\
}
            }' "$WAYBAR_CONF_STYLE"
        fi
        echo -e "  ${CHECKED}✓${RESET}  Waybar tooltips — rounded"
    fi

    echo

    # Restart services that need it
    if command -v walker &>/dev/null && pgrep -x walker &>/dev/null; then
        pkill -x walker 2>/dev/null
    fi
    if command -v makoctl &>/dev/null; then
        makoctl reload 2>/dev/null
    fi
    if pgrep -x waybar &>/dev/null; then
        pkill -x waybar && sleep 0.3 && uwsm app -- waybar &>/dev/null &
    fi

    echo -e "  ${DIM}Hyprland will auto-reload. Services restarted.${RESET}"
    echo
}

disable_rounded_corners() {
    clear
    echo
    echo
    echo -e "${BOLD}  Disable Rounded Corners${RESET}"
    echo
    echo -e "  ${DIM}Returns to sharp/square corners on windows, menus,${RESET}"
    echo -e "  ${DIM}notifications, and other UI elements.${RESET}"
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

    echo -e "  ${CHECKED}✓${RESET}  Hyprland windows — square"
    SUMMARY_LOG+=("✓  Disabled rounded corners")

    # Walker (launcher/menus)
    local walker_css="$HOME/.local/share/omarchy/default/walker/themes/omarchy-default/style.css"
    if [[ -f "$walker_css" ]]; then
        if grep -q 'border-radius' "$walker_css"; then
            sed -i '/\.box-wrapper {/,/}/ { /border-radius/d; }' "$walker_css"
            echo -e "  ${CHECKED}✓${RESET}  Walker menus — square"
        fi
    fi

    # SwayOSD (volume/brightness overlay)
    local swayosd_css="$HOME/.config/swayosd/style.css"
    if [[ -f "$swayosd_css" ]]; then
        sed -i '/^window {/,/}/ s/border-radius: 8px;/border-radius: 0;/' "$swayosd_css"
        sed -i '/^progressbar {/,/}/ s/border-radius: 8px;/border-radius: 0;/' "$swayosd_css"
        echo -e "  ${CHECKED}✓${RESET}  SwayOSD overlay — square"
    fi

    # Hyprlock (lock screen password input)
    local hyprlock_conf="$HOME/.config/hypr/hyprlock.conf"
    if [[ -f "$hyprlock_conf" ]]; then
        sed -i '/^input-field {/,/}/ s/rounding = 8/rounding = 0/' "$hyprlock_conf"
        echo -e "  ${CHECKED}✓${RESET}  Hyprlock password field — square"
    fi

    # Mako (notifications)
    local mako_ini="$HOME/.local/share/omarchy/default/mako/core.ini"
    if [[ -f "$mako_ini" ]]; then
        if grep -q 'border-radius' "$mako_ini"; then
            sed -i '/^border-radius=/d' "$mako_ini"
            echo -e "  ${CHECKED}✓${RESET}  Mako notifications — square"
        fi
    fi

    # Waybar tooltips (remove both tooltip border-radius and tooltip * block)
    if [[ -f "$WAYBAR_CONF_STYLE" ]]; then
        sed -i '/^tooltip {/,/}/ { /border-radius/d; }' "$WAYBAR_CONF_STYLE"
        sed -i '/^tooltip \* {/,/^}/d' "$WAYBAR_CONF_STYLE"
        echo -e "  ${CHECKED}✓${RESET}  Waybar tooltips — square"
    fi

    echo

    # Restart services that need it
    if command -v walker &>/dev/null && pgrep -x walker &>/dev/null; then
        pkill -x walker 2>/dev/null
    fi
    if command -v makoctl &>/dev/null; then
        makoctl reload 2>/dev/null
    fi
    if pgrep -x waybar &>/dev/null; then
        pkill -x waybar && sleep 0.3 && uwsm app -- waybar &>/dev/null &
    fi

    echo -e "  ${DIM}Hyprland will auto-reload. Services restarted.${RESET}"
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

show_window_title() {
    clear
    echo
    echo
    echo -e "${BOLD}  Show Window Title${RESET}"
    echo
    echo -e "  ${DIM}Displays the active window name on the waybar next to workspaces.${RESET}"
    echo
    echo

    if [[ ! -f "$WAYBAR_CONF" ]]; then
        echo -e "  ${DIM}✗${RESET}  waybar config not found at $WAYBAR_CONF"
        echo
        SUMMARY_LOG+=("✗  Show window title -- failed (config not found)")
        return 1
    fi

    # Check if already enabled
    if grep -q 'hyprland/window' "$WAYBAR_CONF"; then
        echo -e "  ${DIM}Window title is already shown. Nothing to do.${RESET}"
        echo
        SUMMARY_LOG+=("--  Show window title -- already set")
        return 0
    fi

    printf "  ${BOLD}Continue?${RESET} ${DIM}(yes/no)${RESET} "
    read -r < /dev/tty

    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo
        echo "  Cancelled."
        echo
        SUMMARY_LOG+=("--  Show window title -- cancelled")
        return 0
    fi

    echo

    # Create backup
    local backup_file="${WAYBAR_CONF}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$WAYBAR_CONF" "$backup_file"
    echo -e "  ${DIM}Backup: $backup_file${RESET}"

    # Add hyprland/window to modules-left after workspaces
    sed -i 's/"hyprland\/workspaces"\]/"hyprland\/workspaces", "hyprland\/window"]/' "$WAYBAR_CONF"

    # Add hyprland/window config block before the closing brace
    sed -i '/^}$/i\  ,"hyprland/window": {\n    "format": "{}",\n    "max-length": 40,\n    "tooltip": false\n  }' "$WAYBAR_CONF"

    # Restart waybar to apply
    if command -v omarchy-restart-waybar &>/dev/null; then
        omarchy-restart-waybar &>/dev/null || true
    fi

    echo -e "  ${CHECKED}✓${RESET}  Window title shown"
    SUMMARY_LOG+=("✓  Showing window title")
    echo
}

hide_window_title() {
    clear
    echo
    echo
    echo -e "${BOLD}  Hide Window Title${RESET}"
    echo
    echo -e "  ${DIM}Removes the active window name from the waybar.${RESET}"
    echo
    echo

    if [[ ! -f "$WAYBAR_CONF" ]]; then
        echo -e "  ${DIM}✗${RESET}  waybar config not found at $WAYBAR_CONF"
        echo
        SUMMARY_LOG+=("✗  Hide window title -- failed (config not found)")
        return 1
    fi

    # Check if already hidden
    if ! grep -q 'hyprland/window' "$WAYBAR_CONF"; then
        echo -e "  ${DIM}Window title is already hidden. Nothing to do.${RESET}"
        echo
        SUMMARY_LOG+=("--  Hide window title -- already set")
        return 0
    fi

    printf "  ${BOLD}Continue?${RESET} ${DIM}(yes/no)${RESET} "
    read -r < /dev/tty

    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo
        echo "  Cancelled."
        echo
        SUMMARY_LOG+=("--  Hide window title -- cancelled")
        return 0
    fi

    echo

    # Create backup
    local backup_file="${WAYBAR_CONF}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$WAYBAR_CONF" "$backup_file"
    echo -e "  ${DIM}Backup: $backup_file${RESET}"

    # Remove hyprland/window from modules-left
    sed -i 's/, "hyprland\/window"//' "$WAYBAR_CONF"

    # Remove hyprland/window config block
    sed -i '/"hyprland\/window"/,/^  }/d' "$WAYBAR_CONF"

    # Clean up any trailing comma left before closing brace
    sed -i -z 's/,\n}/\n}/' "$WAYBAR_CONF"

    # Restart waybar to apply
    if command -v omarchy-restart-waybar &>/dev/null; then
        omarchy-restart-waybar &>/dev/null || true
    fi

    echo -e "  ${CHECKED}✓${RESET}  Window title hidden"
    SUMMARY_LOG+=("✓  Hidden window title")
    echo
}

show_clock_date() {
    clear
    echo
    echo
    echo -e "${BOLD}  Show Clock Date${RESET}"
    echo
    echo -e "  ${DIM}Adds the day name to the waybar clock.${RESET}"
    echo -e "  ${DIM}Example: \"Sunday 10:55 AM\" or \"Sunday 22:55\"${RESET}"
    echo
    echo

    if [[ ! -f "$WAYBAR_CONF" ]]; then
        echo -e "  ${DIM}✗${RESET}  waybar config not found at $WAYBAR_CONF"
        echo
        SUMMARY_LOG+=("✗  Show clock date -- failed (config not found)")
        return 1
    fi

    # Check if date is already shown (look for %A in the clock format line)
    if grep -q '"format":.*%A' "$WAYBAR_CONF"; then
        echo -e "  ${DIM}Clock date is already visible. Nothing to do.${RESET}"
        echo
        SUMMARY_LOG+=("--  Show clock date -- already set")
        return 0
    fi

    printf "  ${BOLD}Continue?${RESET} ${DIM}(yes/no)${RESET} "
    read -r < /dev/tty

    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo
        echo "  Cancelled."
        echo
        SUMMARY_LOG+=("--  Show clock date -- cancelled")
        return 0
    fi

    echo

    # Create backup
    local backup_file="${WAYBAR_CONF}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$WAYBAR_CONF" "$backup_file"
    echo -e "  ${DIM}Backup: $backup_file${RESET}"

    # Add %A before the time format (handles both 12h and 24h)
    sed -i 's/{:L%H:%M/{:L%A %H:%M/g; s/{:L%I:%M/{:L%A %I:%M/g' "$WAYBAR_CONF"

    # Restart waybar to apply
    if command -v omarchy-restart-waybar &>/dev/null; then
        omarchy-restart-waybar &>/dev/null || true
    fi

    echo -e "  ${CHECKED}✓${RESET}  Clock date shown"
    SUMMARY_LOG+=("✓  Showing clock date")
    echo
}

hide_clock_date() {
    clear
    echo
    echo
    echo -e "${BOLD}  Hide Clock Date${RESET}"
    echo
    echo -e "  ${DIM}Removes the day name from the waybar clock.${RESET}"
    echo -e "  ${DIM}Example: \"10:55 AM\" or \"22:55\"${RESET}"
    echo
    echo

    if [[ ! -f "$WAYBAR_CONF" ]]; then
        echo -e "  ${DIM}✗${RESET}  waybar config not found at $WAYBAR_CONF"
        echo
        SUMMARY_LOG+=("✗  Hide clock date -- failed (config not found)")
        return 1
    fi

    # Check if date is already hidden
    if ! grep -q '"format":.*%A' "$WAYBAR_CONF"; then
        echo -e "  ${DIM}Clock date is already hidden. Nothing to do.${RESET}"
        echo
        SUMMARY_LOG+=("--  Hide clock date -- already set")
        return 0
    fi

    printf "  ${BOLD}Continue?${RESET} ${DIM}(yes/no)${RESET} "
    read -r < /dev/tty

    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo
        echo "  Cancelled."
        echo
        SUMMARY_LOG+=("--  Hide clock date -- cancelled")
        return 0
    fi

    echo

    # Create backup
    local backup_file="${WAYBAR_CONF}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$WAYBAR_CONF" "$backup_file"
    echo -e "  ${DIM}Backup: $backup_file${RESET}"

    # Remove %A and trailing space from the clock format
    sed -i 's/%A //g' "$WAYBAR_CONF"

    # Restart waybar to apply
    if command -v omarchy-restart-waybar &>/dev/null; then
        omarchy-restart-waybar &>/dev/null || true
    fi

    echo -e "  ${CHECKED}✓${RESET}  Clock date hidden"
    SUMMARY_LOG+=("✓  Hidden clock date")
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

add_to_omarchy_menu() {
    echo -e "  ${BOLD}Adding A La Carchy to Omarchy menu...${RESET}"
    echo

    local ext_dir="$HOME/.config/omarchy/extensions"
    local ext_file="$ext_dir/menu.sh"
    local marker_start="# === a-la-carchy menu entry ==="
    local marker_end="# === end a-la-carchy menu entry ==="
    local menu_script="$HOME/.local/share/omarchy/bin/omarchy-menu"

    if [ ! -f "$menu_script" ]; then
        echo -e "  ${DIM}Omarchy menu script not found. Cannot add shortcut.${RESET}"
        echo
        SUMMARY_LOG+=("✗  Add menu shortcut -- omarchy-menu not found")
        return 1
    fi

    mkdir -p "$ext_dir"

    # Remove existing managed block if present
    if [ -f "$ext_file" ]; then
        awk -v start="$marker_start" -v end="$marker_end" '
            $0 == start { skip=1; next }
            $0 == end   { skip=0; next }
            !skip
        ' "$ext_file" > "${ext_file}.tmp" && mv "${ext_file}.tmp" "$ext_file"
    fi

    # Extract the original show_main_menu line from omarchy-menu and inject A La Carchy
    # The menu string looks like: "...\n  About\n  System"
    # We insert "  A La Carchy\n" before the System entry
    local original_menu_line
    original_menu_line=$(grep -m1 'go_to_menu "$(menu "Go"' "$menu_script")
    if [ -z "$original_menu_line" ]; then
        echo -e "  ${DIM}Could not parse menu entries from omarchy-menu.${RESET}"
        echo
        SUMMARY_LOG+=("✗  Add menu shortcut -- could not parse menu")
        return 1
    fi

    # Insert "  A La Carchy\n" before the last entry (System), preserving its icon
    local modified_menu_line
    modified_menu_line=$(echo "$original_menu_line" | sed 's|\\n\([^\\]*System\)|\\n  A La Carchy\\n\1|')

    # Extract case entries from the original go_to_menu function
    local case_entries
    case_entries=$(sed -n '/^go_to_menu()/,/^}/p' "$menu_script" | sed -n '/^  \*/p')

    # Build the extension file content
    {
        echo "$marker_start"
        echo "show_main_menu() {"
        echo "$modified_menu_line"
        echo "}"
        echo ""
        echo "_ala_carchy_go_to_menu() {"
        echo "  case \"\${1,,}\" in"
        echo "  *carchy*) terminal bash -c \"bash <(curl -fsSL https://raw.githubusercontent.com/DanielCoffey1/a-la-carchy/master/a-la-carchy.sh)\" ;;"
        echo "$case_entries"
        echo "  esac"
        echo "}"
        echo "go_to_menu() { _ala_carchy_go_to_menu \"\$@\"; }"
        echo "$marker_end"
    } >> "$ext_file"

    echo -e "  ${DIM}Created: $ext_file${RESET}"
    echo
    SUMMARY_LOG+=("✓  Add menu shortcut -- added A La Carchy to Omarchy menu")
}

remove_from_omarchy_menu() {
    echo -e "  ${BOLD}Removing A La Carchy from Omarchy menu...${RESET}"
    echo

    local ext_file="$HOME/.config/omarchy/extensions/menu.sh"
    local marker_start="# === a-la-carchy menu entry ==="
    local marker_end="# === end a-la-carchy menu entry ==="

    if [ ! -f "$ext_file" ]; then
        echo -e "  ${DIM}Menu shortcut not found. Nothing to do.${RESET}"
        echo
        SUMMARY_LOG+=("--  Remove menu shortcut -- not found")
        return 0
    fi

    awk -v start="$marker_start" -v end="$marker_end" '
        $0 == start { skip=1; next }
        $0 == end   { skip=0; next }
        !skip
    ' "$ext_file" > "${ext_file}.tmp" && mv "${ext_file}.tmp" "$ext_file"

    # Delete file if empty
    if [ ! -s "$ext_file" ]; then
        rm -f "$ext_file"
        echo -e "  ${DIM}Removed: $ext_file${RESET}"
    else
        echo -e "  ${DIM}Removed A La Carchy block from: $ext_file${RESET}"
    fi
    echo
    SUMMARY_LOG+=("✓  Remove menu shortcut -- removed A La Carchy from Omarchy menu")
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
    "  Keybind Editor"
    "  Display"
    "  System"
    "  Appearance"
    "  Keyboard"
    "  Utilities"
    "--- Hyprland ---"
    "  General"
    "  Decoration"
    "  Input"
    "  Gestures"
    "--- Install ---"
    "  Extra Themes"
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
    "detect_monitors|Detect monitors|[Open]||action|Detect connected displays and identify them"
    "position_monitors|Position monitors|[Open]||action|Arrange monitor positions relative to each other"
    "laptop_display|Laptop display|Auto off|Normal|toggle|Auto-disable laptop screen when external display connected"
)

declare -a SYSTEM_ITEMS=(
    "suspend|Suspend|Enable|Disable|toggle|Allow system to suspend/sleep when idle"
    "hibernation|Hibernation|Enable|Disable|toggle|Allow system to hibernate to disk"
    "fingerprint|Fingerprint|Enable|Disable|toggle|Enable fingerprint authentication for login"
    "fido2|FIDO2|Enable|Disable|toggle|Enable FIDO2 security key authentication"
    "power_profile|Power profile|[Open]||action|Set default power profile for startup"
    "battery_limit|Battery limit|[Open]||action|Set maximum battery charge level for longer lifespan"
)

declare -a APPEARANCE_ITEMS=(
    "rounded_corners|Rounded corners|Enable|Disable|toggle|Round or square corners on windows, menus, notifications, and UI"
    "window_gaps|Window gaps|Remove|Restore|toggle|Remove or restore gaps between tiled windows"
    "tray_icons|Tray icons|Show all|Hide|toggle|Show all system tray icons or hide extras"
    "clock_format|Clock format|12h|24h|radio|Set waybar clock to 12-hour or 24-hour format"
    "clock_date|Clock date|Show|Hide|toggle|Show or hide the day name on the waybar clock"
    "window_title|Window title|Show|Hide|toggle|Show active window name on waybar next to workspaces"
    "media_dirs|Media dirs|Enable|Disable|toggle|Organize screenshots and recordings into subdirs"
)

declare -a KEYBOARD_ITEMS=(
    "caps_lock|Caps Lock|Normal|Compose|radio|Use Caps Lock normally or as Compose key"
    "alt_super|Alt/Super|Swap|Normal|radio|Swap Alt and Super keys (useful for Mac keyboards)"
)

declare -a UTILITIES_ITEMS=(
    "backup_config|Backup config|[Select]||action|Create a backup of your Omarchy configuration"
    "menu_shortcut|Menu shortcut|Add|Remove|toggle|Add A La Carchy to the Omarchy menu"
)

# Extra themes: each entry is "Display Name|github_url"
declare -a EXTRA_THEMES=(
    "Aetheria|https://github.com/JJDizz1L/aetheria"
    "Amberbyte|https://github.com/tahfizhabib/omarchy-amberbyte-theme"
    "Arc Blueberry|https://github.com/vale-c/omarchy-arc-blueberry"
    "Archwave|https://github.com/davidguttman/archwave"
    "Ash|https://github.com/bjarneo/omarchy-ash-theme"
    "Artzen|https://github.com/tahfizhabib/omarchy-artzen-theme"
    "Aura|https://github.com/bjarneo/omarchy-aura-theme"
    "All Hallow's Eve|https://github.com/guilhermetk/omarchy-all-hallows-eve-theme"
    "Ayaka|https://github.com/abhijeet-swami/omarchy-ayaka-theme"
    "Azure Glow|https://github.com/Hydradevx/omarchy-azure-glow-theme"
    "Bauhaus|https://github.com/somerocketeer/omarchy-bauhaus-theme"
    "Black Arch|https://github.com/ankur311sudo/black_arch"
    "Black Gold|https://github.com/HANCORE-linux/omarchy-blackgold-theme"
    "Black Turq|https://github.com/HANCORE-linux/omarchy-blackturq-theme"
    "Bliss|https://github.com/mishonki3/omarchy-bliss-theme"
    "bluedotrb|https://github.com/dotsilva/omarchy-bluedotrb-theme"
    "Blue Ridge Dark|https://github.com/hipsterusername/omarchy-blueridge-dark-theme"
    "Catppuccin Mocha Dark|https://github.com/Luquatic/omarchy-catppuccin-dark"
    "Citrus Cynapse|https://github.com/Grey-007/citrus-cynapse"
    "Cobalt2|https://github.com/hoblin/omarchy-cobalt2-theme"
    "Darcula|https://github.com/noahljungberg/omarchy-darcula-theme"
    "Demon|https://github.com/HANCORE-linux/omarchy-demon-theme"
    "Dotrb|https://github.com/dotsilva/omarchy-dotrb-theme"
    "Drac|https://github.com/ShehabShaef/omarchy-drac-theme"
    "Dracula|https://github.com/catlee/omarchy-dracula-theme"
    "Eldritch|https://github.com/eldritch-theme/omarchy"
    "Evergarden|https://github.com/celsobenedetti/omarchy-evergarden"
    "Felix|https://github.com/TyRichards/omarchy-felix-theme"
    "Fireside|https://github.com/bjarneo/omarchy-fireside-theme"
    "Flexoki Dark|https://github.com/euandeas/omarchy-flexoki-dark-theme"
    "Forest Green|https://github.com/abhijeet-swami/omarchy-forest-green-theme"
    "Frost|https://github.com/bjarneo/omarchy-frost-theme"
    "Futurism|https://github.com/bjarneo/omarchy-futurism-theme"
    "Gold Rush|https://github.com/tahayvr/omarchy-gold-rush-theme"
    "The Greek|https://github.com/HANCORE-linux/omarchy-thegreek-theme"
    "Green Garden|https://github.com/kalk-ak/omarchy-green-garden-theme"
    "Green Hakkar|https://github.com/joaquinmeza/omarchy-hakker-green-theme"
    "Gruvu|https://github.com/ankur311sudo/gruvu"
    "Infernium|https://github.com/RiO7MAKK3R/omarchy-infernium-dark-theme"
    "Map Quest|https://github.com/ItsABigIgloo/omarchy-mapquest-theme"
    "Mars|https://github.com/steve-lohmeyer/omarchy-mars-theme"
    "Mechanoonna|https://github.com/HANCORE-linux/omarchy-mechanoonna-theme"
    "Miasma|https://github.com/OldJobobo/omarchy-miasma-theme"
    "Midnight|https://github.com/JaxonWright/omarchy-midnight-theme"
    "Milky Matcha|https://github.com/hipsterusername/omarchy-milkmatcha-light-theme"
    "Monochrome|https://github.com/Swarnim114/omarchy-monochrome-theme"
    "Monokai|https://github.com/bjarneo/omarchy-monokai-theme"
    "Nagai Poolside|https://github.com/somerocketeer/omarchy-nagai-poolside-theme"
    "Neo Sploosh|https://github.com/monoooki/omarchy-neo-sploosh-theme"
    "Neovoid|https://github.com/RiO7MAKK3R/omarchy-neovoid-theme"
    "NES|https://github.com/bjarneo/omarchy-nes-theme"
    "Omacarchy|https://github.com/RiO7MAKK3R/omarchy-omacarchy-theme"
    "One Dark Pro|https://github.com/sc0ttman/omarchy-one-dark-pro-theme"
    "Pandora|https://github.com/imbypass/omarchy-pandora-theme"
    "Pina|https://github.com/bjarneo/omarchy-pina-theme"
    "Pink Blood|https://github.com/ITSZXY/pink-blood-omarchy-theme"
    "Pulsar|https://github.com/bjarneo/omarchy-pulsar-theme"
    "Purple Moon|https://github.com/Grey-007/purple-moon"
    "Purplewave|https://github.com/dotsilva/omarchy-purplewave-theme"
    "Rainy Night|https://github.com/atif-1402/omarchy-rainynight-theme"
    "RetroPC|https://github.com/rondilley/omarchy-retropc-theme"
    "Rose Pine Dark|https://github.com/guilhermetk/omarchy-rose-pine-dark"
    "Rose of Dune|https://github.com/HANCORE-linux/omarchy-roseofdune-theme"
    "Sakura|https://github.com/bjarneo/omarchy-sakura-theme"
    "Sapphire|https://github.com/HANCORE-linux/omarchy-sapphire-theme"
    "Shades of Jade|https://github.com/HANCORE-linux/omarchy-shadesofjade-theme"
    "Space Monkey|https://github.com/TyRichards/omarchy-space-monkey-theme"
    "Snow|https://github.com/bjarneo/omarchy-snow-theme"
    "Snow Black|https://github.com/ankur311sudo/snow_black"
    "Solarized|https://github.com/Gazler/omarchy-solarized-theme"
    "Solarized Light|https://github.com/dfrico/omarchy-solarized-light-theme"
    "Solarized Osaka|https://github.com/motorsss/omarchy-solarizedosaka-theme"
    "Sunset|https://github.com/rondilley/omarchy-sunset-theme"
    "Sunset Drive|https://github.com/tahayvr/omarchy-sunset-drive-theme"
    "Super Game Bro|https://github.com/TyRichards/omarchy-super-game-bro-theme"
    "Synthwave '84|https://github.com/omacom-io/omarchy-synthwave84-theme"
    "Temerald|https://github.com/Ahmad-Mtr/omarchy-temerald-theme"
    "Tokyo Night OLED|https://github.com/Justin-De-Sio/omarchy-tokyoled-theme"
    "Torrentz Hydra|https://github.com/monoooki/omarchy-torrentz-hydra-theme"
    "Tycho|https://github.com/leonardobetti/omarchy-tycho"
    "Waveform Dark|https://github.com/hipsterusername/omarchy-waveform-dark-theme"
    "White Gold|https://github.com/HANCORE-linux/omarchy-whitegold-theme"
    "Van Gogh|https://github.com/Nirmal314/omarchy-van-gogh-theme"
    "Vesper|https://github.com/thmoee/omarchy-vesper-theme"
    "VHS 80|https://github.com/tahayvr/omarchy-vhs80-theme"
    "Void|https://github.com/vyrx-dev/omarchy-void-theme"
)

# Selection state for themes (by display name): 0=not selected, 1=selected
declare -A THEME_SELECTIONS=()

# Hyprland General settings (write to looknfeel.conf)
declare -a HYPR_GENERAL_ITEMS=(
    "gaps_in|Gap between windows|int:0:100|general|gaps_in|5|looknfeel|Gap size between tiled windows"
    "gaps_out|Gap from edges|int:0:100|general|gaps_out|10|looknfeel|Gap size from screen edges"
    "border_size|Border width|int:0:10|general|border_size|2|looknfeel|Window border thickness in pixels"
    "active_border|Active border color|color|general|col.active_border|rgba(33ccffee) rgba(00ff99ee) 45deg|looknfeel|Border color of focused window"
    "inactive_border|Inactive border color|color|general|col.inactive_border|rgba(595959aa)|looknfeel|Border color of unfocused windows"
    "resize_on_border|Drag-resize borders|bool|general|resize_on_border|false|looknfeel|Allow resizing windows by dragging borders"
    "no_border_floating|No border floating|bool|general|no_border_on_floating|false|looknfeel|Remove borders from floating windows"
    "allow_tearing|Allow screen tearing|bool|general|allow_tearing|false|looknfeel|Allow tearing for reduced input lag"
    "layout|Window layout|enum:dwindle:master|general|layout|dwindle|looknfeel|Tiling layout algorithm"
    "pseudotile|Pseudotiling|bool|dwindle|pseudotile|true|looknfeel|Windows keep requested size in tiling"
    "preserve_split|Keep split direction|bool|dwindle|preserve_split|true|looknfeel|Maintain split direction on resize"
    "force_split|Split direction|enum:0:1:2|dwindle|force_split|2|looknfeel|0=follow mouse 1=left/top 2=right/bottom"
    "smart_split|Smart split|bool|dwindle|smart_split|false|looknfeel|Split direction follows cursor position"
    "new_status|New window status|enum:master:slave|master|new_status|master|looknfeel|Where new windows appear in master layout"
    "focus_on_activate|Focus on activation|bool|misc|focus_on_activate|true|looknfeel|Focus windows when they request activation"
    "disable_logo|Disable startup logo|bool|misc|disable_hyprland_logo|true|looknfeel|Hide the Hyprland logo on startup"
    "vrr|Variable refresh rate|enum:0:1:2|misc|vrr|0|looknfeel|0=off 1=on 2=fullscreen only (FreeSync/G-Sync)"
    "new_window_fullscreen|New window vs fullscreen|enum:0:1:2|misc|new_window_takes_over_fullscreen|0|looknfeel|0=behind 1=unfullscreen 2=new fullscreen"
    "extend_border_grab|Border grab area|int:0:50|general|extend_border_grab_area|15|looknfeel|Extra pixels for grabbing window borders"
    "middle_click_paste|Middle click paste|bool|misc|middle_click_paste|true|looknfeel|Paste clipboard on middle mouse click"
    "enable_swallow|Window swallowing|bool|misc|enable_swallow|false|looknfeel|Terminal windows absorb spawned child windows"
    "workspace_back_forth|Workspace back-forth|bool|binds|workspace_back_and_forth|false|looknfeel|Same workspace key toggles to previous"
    "allow_ws_cycles|Workspace cycles|bool|binds|allow_workspace_cycles|false|looknfeel|Allow cycling through workspaces with binds"
    "force_zero_scaling|XWayland zero scale|bool|xwayland|force_zero_scaling|false|looknfeel|Fix blurry XWayland apps on scaled displays"
    "key_dpms|Keypress wakes display|bool|misc|key_press_enables_dpms|true|looknfeel|Keypress wakes display from DPMS off"
    "mouse_dpms|Mouse wakes display|bool|misc|mouse_move_enables_dpms|true|looknfeel|Mouse movement wakes display from DPMS off"
)

# Hyprland Decoration settings (write to looknfeel.conf)
declare -a HYPR_DECORATION_ITEMS=(
    "rounding|Corner radius|int:0:30|decoration|rounding|0|looknfeel|Window corner rounding in pixels. See also: Appearance"
    "shadow_enabled|Shadows|bool|decoration.shadow|enabled|true|looknfeel|Enable window drop shadows"
    "shadow_range|Shadow range|int:1:100|decoration.shadow|range|2|looknfeel|Shadow spread distance in pixels"
    "shadow_power|Shadow sharpness|int:1:4|decoration.shadow|render_power|3|looknfeel|Shadow falloff power (1=soft 4=sharp)"
    "shadow_color|Shadow color|color|decoration.shadow|color|rgba(1a1a1aee)|looknfeel|Shadow color in rgba format"
    "blur_enabled|Blur|bool|decoration.blur|enabled|true|looknfeel|Enable background blur on transparent windows"
    "blur_size|Blur radius|int:1:20|decoration.blur|size|2|looknfeel|Blur kernel size (higher=more blur)"
    "blur_passes|Blur iterations|int:1:10|decoration.blur|passes|2|looknfeel|Blur render passes (higher=smoother)"
    "blur_special|Blur special ws|bool|decoration.blur|special|true|looknfeel|Apply blur to special workspace background"
    "blur_brightness|Blur brightness|float:0.0:2.0|decoration.blur|brightness|0.60|looknfeel|Brightness of blurred background"
    "blur_contrast|Blur contrast|float:0.0:2.0|decoration.blur|contrast|0.75|looknfeel|Contrast of blurred background"
    "blur_noise|Blur noise|float:0.0:1.0|decoration.blur|noise|0.0117|looknfeel|Noise applied to blur"
    "blur_popups|Blur popups|bool|decoration.blur|popups|false|looknfeel|Apply blur to popup windows and tooltips"
    "anim_enabled|Animations|bool|animations|enabled|true|looknfeel|Enable window animations"
    "dim_inactive|Dim inactive|bool|decoration|dim_inactive|false|looknfeel|Dim unfocused windows"
    "dim_strength|Dim strength|float:0.0:1.0|decoration|dim_strength|0.5|looknfeel|How much to dim inactive windows"
    "dim_special|Dim special ws bg|float:0.0:1.0|decoration|dim_special|0.2|looknfeel|Dim amount for special workspace background"
    "cursor_hide|Hide cursor on type|bool|cursor|hide_on_key_press|true|looknfeel|Hide cursor when typing"
    "cursor_size|Cursor size|int:16:48|cursor|size|24|looknfeel|Cursor size in pixels"
    "active_opacity|Active opacity|float:0.0:1.0|decoration|active_opacity|1.0|looknfeel|Opacity of focused window (1.0=opaque)"
    "inactive_opacity|Inactive opacity|float:0.0:1.0|decoration|inactive_opacity|1.0|looknfeel|Opacity of unfocused windows (1.0=opaque)"
    "fullscreen_opacity|Fullscreen opacity|float:0.0:1.0|decoration|fullscreen_opacity|1.0|looknfeel|Opacity of fullscreen windows (1.0=opaque)"
)

# Hyprland Input settings (write to input.conf)
declare -a HYPR_INPUT_ITEMS=(
    "sensitivity|Mouse sensitivity|float:-1.0:1.0|input|sensitivity|0|input|Mouse sensitivity (-1.0 to 1.0)"
    "follow_mouse|Focus follows mouse|enum:0:1:2:3|input|follow_mouse|1|input|0=off 1=always 2=click-unfocus 3=lock-unfocus"
    "accel_profile|Accel profile|enum:flat:adaptive|input|accel_profile||input|Mouse acceleration profile"
    "force_no_accel|Disable acceleration|bool|input|force_no_accel|false|input|Force disable mouse acceleration entirely"
    "left_handed|Left handed mouse|bool|input|left_handed|false|input|Swap left and right mouse buttons"
    "repeat_rate|Key repeat speed|int:1:100|input|repeat_rate|40|input|Key repeat rate in characters per second"
    "repeat_delay|Key repeat delay|int:100:2000|input|repeat_delay|600|input|Delay before key repeat starts (ms)"
    "numlock_default|Numlock on start|bool|input|numlock_by_default|true|input|Enable numlock on startup"
    "natural_scroll|Natural scroll|bool|input.touchpad|natural_scroll|false|input|Reverse scroll direction (natural/Apple-style)"
    "scroll_factor|Scroll speed|float:0.1:5.0|input.touchpad|scroll_factor|0.4|input|Touchpad scroll speed multiplier"
    "disable_typing|Off while typing|bool|input.touchpad|disable_while_typing|true|input|Disable touchpad while typing"
    "tap_to_click|Tap to click|bool|input.touchpad|tap-to-click|true|input|Enable tap-to-click on touchpad"
    "drag_lock|Drag lock|bool|input.touchpad|drag_lock|false|input|Keep drag active after lifting finger"
    "middle_emulation|Middle btn emulation|bool|input.touchpad|middle_button_emulation|false|input|Emulate middle click with two-finger tap"
    "scroll_button|Scroll button|int:0:999|input|scroll_button|0|input|Button for on-button-down scrolling (0=disable)"
    "scroll_method|Scroll method|enum:2fg:edge:on_button_down:no_scroll|input|scroll_method|2fg|input|Touchpad scroll method"
)

# Hyprland Gestures settings (write to looknfeel.conf)
declare -a HYPR_GESTURES_ITEMS=(
    "ws_swipe|Workspace swipe|bool|gestures|workspace_swipe|false|looknfeel|Swipe between workspaces on touchpad"
    "ws_swipe_fingers|Swipe fingers|int:2:5|gestures|workspace_swipe_fingers|3|looknfeel|Number of fingers for workspace swipe"
    "ws_swipe_distance|Swipe distance|int:50:1000|gestures|workspace_swipe_distance|300|looknfeel|Distance in pixels to trigger swipe"
    "ws_swipe_invert|Invert swipe|bool|gestures|workspace_swipe_invert|true|looknfeel|Reverse workspace swipe direction"
    "ws_swipe_create|Swipe new workspace|bool|gestures|workspace_swipe_create_new|true|looknfeel|Create new workspace at end of swipe"
)

# Hyprland pending edits and current values
declare -A HYPR_EDITS=()
declare -A HYPR_CURRENT=()

# Load saved Hyprland settings from managed blocks
load_hypr_settings

# Extract installed directory name from a GitHub URL
# omarchy-theme-install strips "omarchy-" prefix and "-theme" suffix
get_theme_dir_name() {
    local url="$1"
    local repo_name="${url##*/}"
    # Remove trailing slash if present
    repo_name="${repo_name%/}"
    # Strip omarchy- prefix and -theme suffix to match omarchy-theme-install behavior
    repo_name="${repo_name#omarchy-}"
    repo_name="${repo_name%-theme}"
    echo "$repo_name"
}

# Check if a theme is already installed
is_theme_installed() {
    local url="$1"
    local dir_name
    dir_name=$(get_theme_dir_name "$url")
    [[ -d "$HOME/.config/omarchy/themes/$dir_name" ]]
}

# Build installed themes lookup set for fast rendering
declare -A INSTALLED_THEME_SET=()
if [[ -d "$HOME/.config/omarchy/themes" ]]; then
    for dir in "$HOME/.config/omarchy/themes"/*/; do
        [[ -d "$dir" ]] || continue
        local_name="${dir%/}"
        local_name="${local_name##*/}"
        INSTALLED_THEME_SET["$local_name"]=1
    done
fi

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

# Multi-monitor management state
declare -a DETECTED_MONITORS=()       # "name|make|model|width|height|x|y|scale|desc|transform"
declare -A MONITOR_POSITIONS=()       # name -> "x,y"
declare -A MONITOR_TRANSFORMS=()      # name -> transform (0-7)
declare -i MONITOR_COUNT=0
declare LAPTOP_MONITOR=""             # eDP-* name if found
declare -i MONITORS_POSITIONED=0      # 1 if position editor was completed
declare SELECTED_POWER_PROFILE=""     # "", "power-saver", "balanced", "performance"
declare SELECTED_BATTERY_LIMIT=""     # "", "60", "80", "90", "100"

# Keybind Editor data structures
declare -a EDIT_BINDINGS_ITEMS=()
declare -A BINDING_EDITS=()  # idx -> "new_mods|new_key"
declare -a VALID_KEYS=(
    A B C D E F G H I J K L M N O P Q R S T U V W X Y Z
    0 1 2 3 4 5 6 7 8 9
    F1 F2 F3 F4 F5 F6 F7 F8 F9 F10 F11 F12
    RETURN SPACE TAB ESCAPE BACKSPACE DELETE INSERT HOME END
    PAGEUP PAGEDOWN UP DOWN LEFT RIGHT
    PRINT SCROLL_LOCK PAUSE
    KP_0 KP_1 KP_2 KP_3 KP_4 KP_5 KP_6 KP_7 KP_8 KP_9
    KP_ADD KP_SUBTRACT KP_MULTIPLY KP_DIVIDE KP_ENTER KP_DECIMAL
    MINUS EQUAL BRACKETLEFT BRACKETRIGHT BACKSLASH SEMICOLON
    APOSTROPHE GRAVE COMMA PERIOD SLASH
    XF86AUDIOMUTE XF86AUDIOLOWERVOLUME XF86AUDIORAISEVOLUME
    XF86AUDIOPLAY XF86AUDIOPREV XF86AUDIONEXT
    XF86MONBRIGHTNESSUP XF86MONBRIGHTNESSDOWN
)

# Load keybindings for the editor
load_all_bindings

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
CAT_SCROLL_OFFSET=0      # Scroll offset for left panel

# =============================================================================
# HELPER FUNCTIONS FOR TWO-PANEL UI
# =============================================================================

# Get items array for a category
get_category_items() {
    local cat_idx=$1
    # Section headers (0, 3, 11, 15) have no items
    case $cat_idx in
        1) echo "PACKAGES" ;;
        2) echo "WEBAPPS" ;;
        4) echo "KEYBINDINGS" ;;
        5) echo "EDIT_BINDINGS" ;;
        6) echo "DISPLAY" ;;
        7) echo "SYSTEM" ;;
        8) echo "APPEARANCE" ;;
        9) echo "KEYBOARD" ;;
        10) echo "UTILITIES" ;;
        12) echo "HYPR_GENERAL" ;;
        13) echo "HYPR_DECORATION" ;;
        14) echo "HYPR_INPUT" ;;
        15) echo "HYPR_GESTURES" ;;
        17) echo "EXTRA_THEMES" ;;
    esac
}

# Get item count for current category
get_current_item_count() {
    # Section headers (0, 3, 11, 15) return 0
    case $CATEGORY_CURSOR in
        0|3|11|16) echo 0 ;;
        1) echo ${#INSTALLED_PACKAGES[@]} ;;
        2) echo ${#INSTALLED_WEBAPPS[@]} ;;
        4) echo ${#KEYBINDINGS_ITEMS[@]} ;;
        5) echo ${#EDIT_BINDINGS_ITEMS[@]} ;;
        6) echo ${#DISPLAY_ITEMS[@]} ;;
        7) echo ${#SYSTEM_ITEMS[@]} ;;
        8) echo ${#APPEARANCE_ITEMS[@]} ;;
        9) echo ${#KEYBOARD_ITEMS[@]} ;;
        10) echo ${#UTILITIES_ITEMS[@]} ;;
        12) echo ${#HYPR_GENERAL_ITEMS[@]} ;;
        13) echo ${#HYPR_DECORATION_ITEMS[@]} ;;
        14) echo ${#HYPR_INPUT_ITEMS[@]} ;;
        15) echo ${#HYPR_GESTURES_ITEMS[@]} ;;
        17) echo ${#EXTRA_THEMES[@]} ;;
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
        4|8|9)  # Toggle items
            local arr
            case $CATEGORY_CURSOR in
                4) arr="KEYBINDINGS_ITEMS" ;;
                8) arr="APPEARANCE_ITEMS" ;; 9) arr="KEYBOARD_ITEMS" ;;
            esac
            local -n ref="$arr"
            parse_toggle_item "${ref[$ITEM_CURSOR]}"
            echo "$TOGGLE_DESC"
            ;;
        7)  # System (mixed: toggle + action)
            parse_toggle_item "${SYSTEM_ITEMS[$ITEM_CURSOR]}"
            echo "$TOGGLE_DESC"
            ;;
        5)  # Keybind Editor
            local be_entry="${EDIT_BINDINGS_ITEMS[$ITEM_CURSOR]}"
            if [[ "$be_entry" == HEADER* ]]; then
                echo ""
            else
                IFS='|' read -r _t _m _k _d be_disp be_args be_file <<< "$be_entry"
                local base_file="${be_file##*/}"
                if [[ -n "$be_args" ]]; then
                    echo "[$base_file] $be_disp,$be_args"
                else
                    echo "[$base_file] $be_disp"
                fi
            fi
            ;;
        6)  # Display (mixed: toggle/radio + action)
            parse_toggle_item "${DISPLAY_ITEMS[$ITEM_CURSOR]}"
            echo "$TOGGLE_DESC"
            ;;
        10)  # Utilities
            parse_toggle_item "${UTILITIES_ITEMS[$ITEM_CURSOR]}"
            echo "$TOGGLE_DESC"
            ;;
        12|13|14|15)  # Hyprland settings
            local hypr_arr
            case $CATEGORY_CURSOR in
                12) hypr_arr="HYPR_GENERAL_ITEMS" ;;
                13) hypr_arr="HYPR_DECORATION_ITEMS" ;;
                14) hypr_arr="HYPR_INPUT_ITEMS" ;;
                15) hypr_arr="HYPR_GESTURES_ITEMS" ;;
            esac
            local -n hypr_ref="$hypr_arr"
            parse_hypr_item "${hypr_ref[$ITEM_CURSOR]}"
            echo "$HYPR_DESC"
            ;;
        17) # Extra Themes
            local entry="${EXTRA_THEMES[$ITEM_CURSOR]}"
            local theme_url="${entry#*|}"
            local repo_name="${theme_url##*/}"
            repo_name="${repo_name%/}"
            echo "Install from $repo_name"
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
    local ROWS=12

    # Clamp cursors
    local cat_count=${#CATEGORIES[@]}
    (( CATEGORY_CURSOR >= cat_count )) && CATEGORY_CURSOR=$((cat_count - 1))
    (( CATEGORY_CURSOR < 0 )) && CATEGORY_CURSOR=0

    local item_count=$(get_current_item_count)
    (( ITEM_CURSOR >= item_count )) && ITEM_CURSOR=$((item_count - 1))
    (( ITEM_CURSOR < 0 )) && ITEM_CURSOR=0

    # Scroll (right panel)
    (( ITEM_CURSOR < ITEM_SCROLL_OFFSET )) && ITEM_SCROLL_OFFSET=$ITEM_CURSOR
    (( ITEM_CURSOR >= ITEM_SCROLL_OFFSET + ROWS )) && ITEM_SCROLL_OFFSET=$((ITEM_CURSOR - ROWS + 1))
    (( ITEM_SCROLL_OFFSET < 0 )) && ITEM_SCROLL_OFFSET=0

    # Scroll (left panel)
    (( CATEGORY_CURSOR < CAT_SCROLL_OFFSET )) && CAT_SCROLL_OFFSET=$CATEGORY_CURSOR
    (( CATEGORY_CURSOR >= CAT_SCROLL_OFFSET + ROWS )) && CAT_SCROLL_OFFSET=$((CATEGORY_CURSOR - ROWS + 1))
    (( CAT_SCROLL_OFFSET < 0 )) && CAT_SCROLL_OFFSET=0

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

        # Left panel (with scroll offset)
        local Lsection=0
        local cat_idx=$((CAT_SCROLL_OFFSET + row))
        if (( cat_idx < cat_count )); then
            local cat_text="${CATEGORIES[$cat_idx]}"
            if [[ "$cat_text" == ---* ]]; then
                # Section header - will be dimmed at output time
                L=" ${cat_text}"
                Lsection=1
            elif (( cat_idx == CATEGORY_CURSOR )); then
                L=" > ${cat_text}"
                (( CURRENT_PANEL == 0 )) && Lhl=1
            else
                L="   ${cat_text}"
            fi
        fi

        # Right panel
        local Rsection=0
        local idx=$((ITEM_SCROLL_OFFSET + row))
        if (( idx < item_count )); then
            (( CURRENT_PANEL == 1 && idx == ITEM_CURSOR )) && Rhl=1
            case $CATEGORY_CURSOR in
                1) local p="${INSTALLED_PACKAGES[$idx]}"
                   [[ "${PKG_SELECTIONS[$p]:-0}" == "1" ]] && R=" [x] $p" || R=" [ ] $p" ;;
                2) local w="${INSTALLED_WEBAPPS[$idx]}"
                   [[ "${WEBAPP_SELECTIONS[$w]:-0}" == "1" ]] && R=" [x] $w" || R=" [ ] $w" ;;
                4|8|9)
                    local arr
                    case $CATEGORY_CURSOR in
                        4) arr="KEYBINDINGS_ITEMS" ;;
                        8) arr="APPEARANCE_ITEMS" ;; 9) arr="KEYBOARD_ITEMS" ;;
                    esac
                    local -n ref="$arr"
                    parse_toggle_item "${ref[$idx]}"
                    R=$(format_toggle_item "$TOGGLE_NAME" "$TOGGLE_OPT1" "$TOGGLE_OPT2" "${TOGGLE_SELECTIONS[$TOGGLE_ID]:-0}") ;;
                7)  # System (mixed: toggle + action)
                    parse_toggle_item "${SYSTEM_ITEMS[$idx]}"
                    if [ "$TOGGLE_TYPE" = "action" ]; then
                        local sys_suffix=""
                        if [[ "$TOGGLE_ID" == "power_profile" && -n "$SELECTED_POWER_PROFILE" ]]; then
                            sys_suffix="$SELECTED_POWER_PROFILE"
                        elif [[ "$TOGGLE_ID" == "battery_limit" && -n "$SELECTED_BATTERY_LIMIT" ]]; then
                            sys_suffix="${SELECTED_BATTERY_LIMIT}%"
                        fi
                        if [[ -n "$sys_suffix" ]]; then
                            R=$(printf " %-24s %s" "$TOGGLE_NAME" "$sys_suffix")
                        else
                            R=" $TOGGLE_NAME"
                        fi
                    else
                        R=$(format_toggle_item "$TOGGLE_NAME" "$TOGGLE_OPT1" "$TOGGLE_OPT2" "${TOGGLE_SELECTIONS[$TOGGLE_ID]:-0}")
                    fi ;;
                6)  # Display (mixed: toggle/radio + action)
                    parse_toggle_item "${DISPLAY_ITEMS[$idx]}"
                    if [ "$TOGGLE_TYPE" = "action" ]; then
                        local d_suffix=""
                        if [ "$TOGGLE_ID" = "detect_monitors" ] && [ $MONITOR_COUNT -gt 0 ]; then
                            d_suffix="$MONITOR_COUNT found"
                        elif [ "$TOGGLE_ID" = "position_monitors" ] && [ $MONITORS_POSITIONED -eq 1 ]; then
                            d_suffix="[set]"
                        fi
                        if [[ -n "$d_suffix" ]]; then
                            R=$(printf " %-24s %s" "$TOGGLE_NAME" "$d_suffix")
                        else
                            R=" $TOGGLE_NAME"
                        fi
                    else
                        R=$(format_toggle_item "$TOGGLE_NAME" "$TOGGLE_OPT1" "$TOGGLE_OPT2" "${TOGGLE_SELECTIONS[$TOGGLE_ID]:-0}")
                    fi ;;
                5)  # Keybind Editor
                    local be_entry="${EDIT_BINDINGS_ITEMS[$idx]}"
                    if [[ "$be_entry" == HEADER* ]]; then
                        local header_name="${be_entry#HEADER|}"
                        R=" -- $header_name --"
                        Rsection=1
                    else
                        IFS='|' read -r _t be_mods be_key be_desc _rest <<< "$be_entry"
                        local be_prefix=" "
                        local display_mods="$be_mods"
                        local display_key="$be_key"
                        if [[ -n "${BINDING_EDITS[$idx]:-}" ]]; then
                            IFS='|' read -r display_mods display_key <<< "${BINDING_EDITS[$idx]}"
                            be_prefix="*"
                        fi
                        local keycombo="${display_mods}+${display_key}"
                        R=$(printf "%s%-17s %s" "$be_prefix" "$keycombo" "$be_desc")
                    fi ;;
                10) parse_toggle_item "${UTILITIES_ITEMS[$idx]}"
                    if [ "$TOGGLE_TYPE" = "toggle" ]; then
                        R=$(format_toggle_item "$TOGGLE_NAME" "$TOGGLE_OPT1" "$TOGGLE_OPT2" "${TOGGLE_SELECTIONS[$TOGGLE_ID]:-0}")
                    else
                        [[ "${TOGGLE_SELECTIONS[$TOGGLE_ID]:-0}" == "1" ]] && R=" [x] $TOGGLE_NAME" || R=" [ ] $TOGGLE_NAME"
                    fi ;;
                12|13|14|15)  # Hyprland settings
                    local hypr_arr
                    case $CATEGORY_CURSOR in
                        12) hypr_arr="HYPR_GENERAL_ITEMS" ;;
                        13) hypr_arr="HYPR_DECORATION_ITEMS" ;;
                        14) hypr_arr="HYPR_INPUT_ITEMS" ;;
                        15) hypr_arr="HYPR_GESTURES_ITEMS" ;;
                    esac
                    local -n hypr_ref="$hypr_arr"
                    local h_entry="${hypr_ref[$idx]}"
                    parse_hypr_item "$h_entry"
                    # Get display value: pending edit > current > default
                    local h_val="$HYPR_DEFAULT"
                    local full_key="${HYPR_SECTION}.${HYPR_KEY}"
                    [[ -n "${HYPR_CURRENT[$full_key]:-}" ]] && h_val="${HYPR_CURRENT[$full_key]}"
                    local h_prefix=" "
                    if [[ -n "${HYPR_EDITS[$HYPR_ID]:-}" ]]; then
                        local h_new="${HYPR_EDITS[$HYPR_ID]}"
                        h_prefix="*"
                        if [[ "$HYPR_TYPE" == "bool" ]]; then
                            [[ "$h_val" == "true" ]] && h_val="ON" || h_val="OFF"
                            [[ "$h_new" == "true" ]] && h_new="ON" || h_new="OFF"
                        fi
                        R=$(printf "%s%-24s %s > %s" "$h_prefix" "$HYPR_LABEL" "$h_val" "$h_new")
                    else
                        if [[ "$HYPR_TYPE" == "bool" ]]; then
                            [[ "$h_val" == "true" ]] && h_val="ON" || h_val="OFF"
                        fi
                        R=$(printf " %-24s %s" "$HYPR_LABEL" "$h_val")
                    fi ;;
                17) local entry="${EXTRA_THEMES[$idx]}"
                    local tname="${entry%%|*}"
                    local turl="${entry#*|}"
                    local tdir
                    tdir=$(get_theme_dir_name "$turl")
                    local installed_suffix=""
                    [[ -n "${INSTALLED_THEME_SET[$tdir]:-}" ]] && installed_suffix=" (installed)"
                    if [[ "${THEME_SELECTIONS[$tname]:-0}" == "1" ]]; then
                        R=" [x] ${tname}${installed_suffix}"
                    else
                        R=" [ ] ${tname}${installed_suffix}"
                    fi ;;
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
        elif (( Rsection )); then
            printf "${DIM}%s${RESET}│\n" "$Rfmt"
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
    if [ $CATEGORY_CURSOR -eq 17 ]; then
        printf '%s\n' "│         Arrows:Navigate  Space:Select  A:All  Enter:Confirm  Q:Quit          │"
    elif [ $CATEGORY_CURSOR -eq 5 ] || [ $CATEGORY_CURSOR -eq 6 ] || [ $CATEGORY_CURSOR -eq 7 ] || [ $CATEGORY_CURSOR -eq 12 ] || [ $CATEGORY_CURSOR -eq 13 ] || [ $CATEGORY_CURSOR -eq 14 ] || [ $CATEGORY_CURSOR -eq 15 ]; then
        printf '%s\n' "│          Arrows:Navigate  Space:Edit  R:Reset  Enter:Confirm  Q:Quit         │"
    else
        printf '%s\n' "│             Arrows:Navigate  Space:Select  Enter:Confirm  Q:Quit             │"
    fi
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
                            # Skip headers in Keybind Editor
                            if [ $CATEGORY_CURSOR -eq 5 ]; then
                                while [ $ITEM_CURSOR -gt 0 ] && is_binding_header $ITEM_CURSOR; do
                                    ((ITEM_CURSOR--))
                                done
                                if is_binding_header $ITEM_CURSOR; then
                                    ((ITEM_CURSOR++))
                                fi
                            fi
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
                            # Skip headers in Keybind Editor
                            if [ $CATEGORY_CURSOR -eq 5 ]; then
                                while [ $ITEM_CURSOR -lt $((item_count - 1)) ] && is_binding_header $ITEM_CURSOR; do
                                    ((ITEM_CURSOR++))
                                done
                            fi
                        fi
                    fi
                    ;;
                '[C')  # Right arrow - switch to right panel
                    if [ $CURRENT_PANEL -eq 0 ] && [ $item_count -gt 0 ]; then
                        CURRENT_PANEL=1
                        # Skip headers in Keybind Editor
                        if [ $CATEGORY_CURSOR -eq 5 ] && is_binding_header $ITEM_CURSOR; then
                            while [ $ITEM_CURSOR -lt $((item_count - 1)) ] && is_binding_header $ITEM_CURSOR; do
                                ((ITEM_CURSOR++))
                            done
                        fi
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
        'a'|'A')  # Select all / deselect all (Extra Themes only)
            if [ $CATEGORY_CURSOR -eq 17 ]; then
                toggle_all_themes
            fi
            ;;
        'r'|'R')  # Reset pending edit (Keybind Editor / Hyprland settings)
            if [ $CATEGORY_CURSOR -eq 5 ] && [ $CURRENT_PANEL -eq 1 ]; then
                unset 'BINDING_EDITS[$ITEM_CURSOR]'
            elif [ $CURRENT_PANEL -eq 1 ] && { [ $CATEGORY_CURSOR -eq 12 ] || [ $CATEGORY_CURSOR -eq 13 ] || [ $CATEGORY_CURSOR -eq 14 ] || [ $CATEGORY_CURSOR -eq 15 ]; }; then
                local hypr_arr
                case $CATEGORY_CURSOR in
                    12) hypr_arr="HYPR_GENERAL_ITEMS" ;;
                    13) hypr_arr="HYPR_DECORATION_ITEMS" ;;
                    14) hypr_arr="HYPR_INPUT_ITEMS" ;;
                    15) hypr_arr="HYPR_GESTURES_ITEMS" ;;
                esac
                local -n hypr_reset_ref="$hypr_arr"
                parse_hypr_item "${hypr_reset_ref[$ITEM_CURSOR]}"
                unset 'HYPR_EDITS[$HYPR_ID]'
            fi
            ;;
        'q'|'Q')  # Quit
            return 2
            ;;
    esac
    return 0
}

# Toggle all themes: if any are selected, deselect all; otherwise select all
toggle_all_themes() {
    local any_selected=false
    for entry in "${EXTRA_THEMES[@]}"; do
        local tname="${entry%%|*}"
        if [ "${THEME_SELECTIONS[$tname]:-0}" -eq 1 ]; then
            any_selected=true
            break
        fi
    done

    if [ "$any_selected" = true ]; then
        # Deselect all
        for entry in "${EXTRA_THEMES[@]}"; do
            local tname="${entry%%|*}"
            THEME_SELECTIONS[$tname]=0
        done
    else
        # Select all
        for entry in "${EXTRA_THEMES[@]}"; do
            local tname="${entry%%|*}"
            THEME_SELECTIONS[$tname]=1
        done
    fi
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
        4|8|9)  # Toggle items (Keybindings, Appearance, Keyboard)
            local items_var=""
            case $CATEGORY_CURSOR in
                4) items_var="KEYBINDINGS_ITEMS" ;;
                8) items_var="APPEARANCE_ITEMS" ;;
                9) items_var="KEYBOARD_ITEMS" ;;
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
        7)  # System (mixed: toggle + action)
            local item="${SYSTEM_ITEMS[$ITEM_CURSOR]}"
            parse_toggle_item "$item"
            local cur="${TOGGLE_SELECTIONS[$TOGGLE_ID]:-0}"
            if [ "$TOGGLE_TYPE" = "action" ]; then
                # Action items open dialogs
                stty echo 2>/dev/null
                tput cnorm
                case "$TOGGLE_ID" in
                    power_profile) show_power_profile_dialog ;;
                    battery_limit) show_battery_limit_dialog ;;
                esac
                tput civis
                stty -echo 2>/dev/null
            else
                # 3-state cycle: 0 -> 1 -> 2 -> 0
                if [ "$cur" -eq 0 ]; then
                    TOGGLE_SELECTIONS[$TOGGLE_ID]=1
                elif [ "$cur" -eq 1 ]; then
                    TOGGLE_SELECTIONS[$TOGGLE_ID]=2
                else
                    TOGGLE_SELECTIONS[$TOGGLE_ID]=0
                fi
            fi
            ;;
        5)  # Keybind Editor - open edit dialog
            if ! is_binding_header $ITEM_CURSOR; then
                stty echo 2>/dev/null
                tput cnorm
                edit_binding $ITEM_CURSOR
                tput civis
                stty -echo 2>/dev/null
            fi
            ;;
        6)  # Display (mixed: toggle/radio + action)
            local item="${DISPLAY_ITEMS[$ITEM_CURSOR]}"
            parse_toggle_item "$item"
            local cur="${TOGGLE_SELECTIONS[$TOGGLE_ID]:-0}"
            if [ "$TOGGLE_TYPE" = "action" ]; then
                # Action items open dialogs
                stty echo 2>/dev/null
                tput cnorm
                case "$TOGGLE_ID" in
                    detect_monitors) show_monitor_detection_dialog ;;
                    position_monitors) show_position_editor_dialog ;;
                esac
                tput civis
                stty -echo 2>/dev/null
            elif [ "$TOGGLE_TYPE" = "toggle" ]; then
                # 3-state cycle: 0 -> 1 -> 2 -> 0
                if [ "$cur" -eq 0 ]; then
                    TOGGLE_SELECTIONS[$TOGGLE_ID]=1
                elif [ "$cur" -eq 1 ]; then
                    TOGGLE_SELECTIONS[$TOGGLE_ID]=2
                else
                    TOGGLE_SELECTIONS[$TOGGLE_ID]=0
                fi
            else
                # Radio: 3-state cycle
                if [ "$cur" -eq 0 ]; then
                    TOGGLE_SELECTIONS[$TOGGLE_ID]=1
                elif [ "$cur" -eq 1 ]; then
                    TOGGLE_SELECTIONS[$TOGGLE_ID]=2
                else
                    TOGGLE_SELECTIONS[$TOGGLE_ID]=0
                fi
            fi
            ;;
        10)  # Utilities
            local item="${UTILITIES_ITEMS[$ITEM_CURSOR]}"
            parse_toggle_item "$item"
            local cur="${TOGGLE_SELECTIONS[$TOGGLE_ID]:-0}"
            if [ "$TOGGLE_TYPE" = "toggle" ]; then
                # 3-state cycle: 0 -> 1 -> 2 -> 0
                if [ "$cur" -eq 0 ]; then
                    TOGGLE_SELECTIONS[$TOGGLE_ID]=1
                elif [ "$cur" -eq 1 ]; then
                    TOGGLE_SELECTIONS[$TOGGLE_ID]=2
                else
                    TOGGLE_SELECTIONS[$TOGGLE_ID]=0
                fi
            else
                # Simple action: 0 -> 1 -> 0
                if [ "$cur" -eq 0 ]; then
                    TOGGLE_SELECTIONS[$TOGGLE_ID]=1
                else
                    TOGGLE_SELECTIONS[$TOGGLE_ID]=0
                fi
            fi
            ;;
        12|13|14|15)  # Hyprland settings - open edit dialog
            local hypr_arr
            case $CATEGORY_CURSOR in
                12) hypr_arr="HYPR_GENERAL_ITEMS" ;;
                13) hypr_arr="HYPR_DECORATION_ITEMS" ;;
                14) hypr_arr="HYPR_INPUT_ITEMS" ;;
                15) hypr_arr="HYPR_GESTURES_ITEMS" ;;
            esac
            local -n hypr_items_ref="$hypr_arr"
            stty echo 2>/dev/null
            tput cnorm
            edit_hypr_setting "${hypr_items_ref[$ITEM_CURSOR]}"
            tput civis
            stty -echo 2>/dev/null
            ;;
        17) # Extra Themes (simple toggle)
            local entry="${EXTRA_THEMES[$ITEM_CURSOR]}"
            local tname="${entry%%|*}"
            local cur="${THEME_SELECTIONS[$tname]:-0}"
            if [ "$cur" -eq 0 ]; then
                THEME_SELECTIONS[$tname]=1
            else
                THEME_SELECTIONS[$tname]=0
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

# Build list of selected themes (filtering out already-installed)
declare -a SELECTED_THEMES_FINAL=()
for entry in "${EXTRA_THEMES[@]}"; do
    local_tname="${entry%%|*}"
    local_turl="${entry#*|}"
    if [ "${THEME_SELECTIONS[$local_tname]:-0}" -eq 1 ]; then
        local_tdir=$(get_theme_dir_name "$local_turl")
        if [[ -z "${INSTALLED_THEME_SET[$local_tdir]:-}" ]]; then
            SELECTED_THEMES_FINAL+=("$local_tname|$local_turl")
        fi
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

# laptop_display: 1=Auto off, 2=Normal (remove)
LAPTOP_AUTO_OFF=false
LAPTOP_AUTO_NORMAL=false
case "${TOGGLE_SELECTIONS[laptop_display]:-0}" in
    1) LAPTOP_AUTO_OFF=true ;;
    2) LAPTOP_AUTO_NORMAL=true ;;
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

# clock_date: 1=Show, 2=Hide
SHOW_CLOCK_DATE=false
HIDE_CLOCK_DATE=false
case "${TOGGLE_SELECTIONS[clock_date]:-0}" in
    1) SHOW_CLOCK_DATE=true ;;
    2) HIDE_CLOCK_DATE=true ;;
esac

# window_title: 1=Show, 2=Hide
SHOW_WINDOW_TITLE=false
HIDE_WINDOW_TITLE=false
case "${TOGGLE_SELECTIONS[window_title]:-0}" in
    1) SHOW_WINDOW_TITLE=true ;;
    2) HIDE_WINDOW_TITLE=true ;;
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

# menu_shortcut: 1=Add, 2=Remove
ADD_MENU_SHORTCUT=false
REMOVE_MENU_SHORTCUT=false
case "${TOGGLE_SELECTIONS[menu_shortcut]:-0}" in
    1) ADD_MENU_SHORTCUT=true ;;
    2) REMOVE_MENU_SHORTCUT=true ;;
esac

# Check if anything was selected
has_selection=false
if [ ${#SELECTED_PACKAGES_FINAL[@]} -gt 0 ] || [ ${#SELECTED_WEBAPPS_FINAL[@]} -gt 0 ] || [ ${#SELECTED_THEMES_FINAL[@]} -gt 0 ]; then
    has_selection=true
fi
for key in "${!TOGGLE_SELECTIONS[@]}"; do
    if [ "${TOGGLE_SELECTIONS[$key]}" -ne 0 ]; then
        has_selection=true
        break
    fi
done
if [ ${#BINDING_EDITS[@]} -gt 0 ]; then
    has_selection=true
fi
if [ ${#HYPR_EDITS[@]} -gt 0 ]; then
    has_selection=true
fi
if [ "$MONITORS_POSITIONED" -eq 1 ]; then
    has_selection=true
fi
if [[ -n "$SELECTED_POWER_PROFILE" ]]; then
    has_selection=true
fi
if [[ -n "$SELECTED_BATTERY_LIMIT" ]]; then
    has_selection=true
fi

if [ "$has_selection" = false ]; then
    clear
    echo
    echo "Nothing selected."
    echo
    exit 0
fi

# Handle backup timing
BACKUP_BEFORE=false
BACKUP_AFTER=false
if [ "$BACKUP_CONFIGS" = true ]; then
    # Check if any tweaks are also selected (config-modifying actions)
    has_tweaks=false
    for key in "${!TOGGLE_SELECTIONS[@]}"; do
        if [ "$key" != "backup_config" ] && [ "${TOGGLE_SELECTIONS[$key]}" -ne 0 ]; then
            has_tweaks=true
            break
        fi
    done
    if [ ${#BINDING_EDITS[@]} -gt 0 ] || [ ${#HYPR_EDITS[@]} -gt 0 ]; then
        has_tweaks=true
    fi

    if [ "$has_tweaks" = true ]; then
        clear
        echo
        echo
        echo -e "${BOLD}  Backup Timing${RESET}"
        echo
        echo -e "  ${DIM}You selected tweaks that will modify config files.${RESET}"
        echo -e "  ${DIM}When would you like to back up?${RESET}"
        echo
        echo -e "    ${BOLD}1)${RESET}  Before changes  ${DIM}(preserve current state)${RESET}"
        echo -e "    ${BOLD}2)${RESET}  After changes   ${DIM}(save new configuration)${RESET}"
        echo -e "    ${BOLD}3)${RESET}  Both            ${DIM}(before and after)${RESET}"
        echo
        while true; do
            printf "  ${BOLD}Select (1-3):${RESET} "
            read -r < /dev/tty
            case "$REPLY" in
                1) BACKUP_BEFORE=true; break ;;
                2) BACKUP_AFTER=true; break ;;
                3) BACKUP_BEFORE=true; BACKUP_AFTER=true; break ;;
                *) echo -e "  ${DIM}Invalid selection. Please enter 1, 2, or 3.${RESET}" ;;
            esac
        done
    else
        BACKUP_BEFORE=true
    fi
fi

# Run backup before changes if requested
if [ "$BACKUP_BEFORE" = true ]; then
    backup_configs
fi

# Handle keybind reset (runs its own confirmation flow)
if [ "$RESET_KEYBINDS" = true ]; then
    rebind_close_window
fi

# Handle keybind restore (runs its own confirmation flow)
if [ "$RESTORE_KEYBINDS" = true ]; then
    restore_close_window
fi

# Handle monitor scaling (runs its own confirmation flow)
if [ "$MONITOR_4K" = true ]; then
    set_monitor_4k
fi

if [ "$MONITOR_1080_1440" = true ]; then
    set_monitor_1080_1440
fi

# Apply monitor positions (from position editor)
if [ "$MONITORS_POSITIONED" -eq 1 ]; then
    apply_monitor_positions
fi

if [ "$LAPTOP_AUTO_OFF" = true ]; then
    setup_laptop_auto_off
fi

if [ "$LAPTOP_AUTO_NORMAL" = true ]; then
    remove_laptop_auto_off
fi

if [[ -n "$SELECTED_POWER_PROFILE" ]]; then
    apply_power_profile
fi

if [[ -n "$SELECTED_BATTERY_LIMIT" ]]; then
    apply_battery_limit
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

# Apply keybind editor changes
apply_binding_edits

# Apply Hyprland setting changes
apply_hypr_edits

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

if [ "$SHOW_CLOCK_DATE" = true ]; then
    show_clock_date
fi

if [ "$HIDE_CLOCK_DATE" = true ]; then
    hide_clock_date
fi

if [ "$SHOW_WINDOW_TITLE" = true ]; then
    show_window_title
fi

if [ "$HIDE_WINDOW_TITLE" = true ]; then
    hide_window_title
fi

if [ "$ADD_MENU_SHORTCUT" = true ]; then
    add_to_omarchy_menu
fi

if [ "$REMOVE_MENU_SHORTCUT" = true ]; then
    remove_from_omarchy_menu
fi

# Run backup after changes if requested
if [ "$BACKUP_AFTER" = true ]; then
    backup_configs
fi

# Handle theme installations
if [ ${#SELECTED_THEMES_FINAL[@]} -gt 0 ]; then
    clear
    echo
    echo
    echo -e "${BOLD}  Confirm Theme Installation${RESET}"
    echo
    echo
    echo -e "${DIM}  Themes (${#SELECTED_THEMES_FINAL[@]}):${RESET}"
    for entry in "${SELECTED_THEMES_FINAL[@]}"; do
        local_tname="${entry%%|*}"
        echo -e "    ${DIM}•${RESET}  $local_tname"
    done
    echo
    echo
    echo -e "${DIM}  The last theme installed will become the active theme.${RESET}"
    echo
    echo
    printf "  ${BOLD}Continue?${RESET} ${DIM}(yes/no)${RESET} "
    read -r < /dev/tty

    if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo
        echo "  Installing themes..."
        echo

        local_current=0
        local_total=${#SELECTED_THEMES_FINAL[@]}
        local_timeout=30

        for entry in "${SELECTED_THEMES_FINAL[@]}"; do
            local_tname="${entry%%|*}"
            local_turl="${entry#*|}"
            ((local_current++))

            echo -e "  ${DIM}[$local_current/$local_total]${RESET} Installing $local_tname..."

            if timeout $local_timeout omarchy-theme-install "$local_turl" >/dev/null 2>&1; then
                echo -e "    ${CHECKED}✓${RESET}  Installed: $local_tname"
                SUMMARY_LOG+=("✓  Installed theme: $local_tname")
            elif [ $? -eq 124 ]; then
                echo -e "    ${DIM}✗${RESET}  Skipped: $local_tname (timed out -- may require GitHub auth)"
                SUMMARY_LOG+=("✗  Skipped theme: $local_tname (timed out)")
                local_timeout=15
            else
                echo -e "    ${DIM}✗${RESET}  Failed: $local_tname"
                SUMMARY_LOG+=("✗  Failed to install theme: $local_tname")
            fi
        done
        echo
    else
        SUMMARY_LOG+=("–  Theme installation cancelled")
    fi
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
        echo -e "    ${DIM}•${RESET}  $pkg"
    done
    echo
fi

if [ ${#SELECTED_WEBAPPS_FINAL[@]} -gt 0 ]; then
    echo -e "${DIM}  Web Apps (${#SELECTED_WEBAPPS_FINAL[@]}):${RESET}"
    for webapp in "${SELECTED_WEBAPPS_FINAL[@]}"; do
        echo -e "    ${DIM}•${RESET}  $webapp"
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
