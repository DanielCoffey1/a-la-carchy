# A La Carchy

**Pick and choose what you want to remove, à la carte style!**

![A La Carchy TUI](screenshots/A%20La%20Carchy.png)

A two-panel TUI (Terminal User Interface) debloater and optimizer for Omarchy Linux.

## Features

- **Two-panel TUI** with categories on the left and items on the right
- **Description bar** showing context for the currently highlighted item
- Interactive checklist of preinstalled packages and webapps
- Only shows packages and webapps that are currently installed
- **86 extra community themes** browseable and installable with one click
- **Keybind Editor** to view and rebind all Hyprland keybindings via guided dialog
- **Hyprland Configurator** with 69 settings across 4 categories (General, Decoration, Input, Gestures)
- **Multi-monitor management** with detection, positioning, and laptop auto-off
- **40+ configuration tweaks** for keybindings, display, and system settings
- **Backup & restore** config directories with a single selection
- **Summary screen** after all actions complete
- Safe removal with confirmation prompts
- **No installation required** - just run the one-liner command!
- No external dependencies needed

## Quick Start (One-Liner)

Just paste this command in your terminal and press Enter:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/DanielCoffey1/a-la-carchy/master/a-la-carchy.sh)
```

That's it! The script will:
1. Show you a two-panel TUI with category navigation
2. Let you browse categories, select items, and configure tweaks
3. Execute your selections safely with confirmation prompts

## Alternative: Download and Run

If you prefer to download first:

```bash
curl -O https://raw.githubusercontent.com/DanielCoffey1/a-la-carchy/master/a-la-carchy.sh
chmod +x a-la-carchy.sh
./a-la-carchy.sh
```

## Requirements

- An AUR helper (`yay` or `paru`) recommended for full functionality
- `brightnessctl` for laptop display auto-off (preinstalled on Omarchy)
- `socat` or `nc` for real-time monitor plug/unplug events (falls back to polling if unavailable)
- `power-profiles-daemon` for power profile management (optional, shows error if unavailable)
- Battery with kernel `charge_control_end_threshold` support for battery charge limit (optional, shows error if unavailable)
- No other external dependencies - works out of the box!

## How to Use

1. Run the script using one of the methods above
2. Use the two-panel interface:
   - **←/→** Switch between the category panel (left) and items panel (right)
   - **↑/↓** Navigate within the current panel
   - **Space** Select/deselect items or edit a keybinding (in the right panel)
   - **A** Select/deselect all (Extra Themes only)
   - **R** Reset a pending keybinding edit (Keybind Editor only)
   - **Enter** Confirm and execute selected actions
   - **Q** Quit
3. Type `yes` when prompted to confirm

## What It Does

### Remove Packages

The script can remove the following preinstalled applications:

- **Browsers**: Chromium (omarchy-chromium)
- **Productivity**: LibreOffice Suite, Obsidian, Typora, Xournal++
- **Media**: Kdenlive, OBS Studio, Spotify
- **Graphics**: Pinta
- **Communication**: Signal, LocalSend
- **Development**: Docker (Core Engine, Buildx, Compose)
- **Security**: 1Password, 1Password CLI
- **Utilities**: Calculator (gnome-calculator)

### Remove Web Apps

The script can also remove the following preinstalled Omarchy webapps:

- **Communication**: Discord, HEY, WhatsApp, Zoom
- **Google Services**: Google Contacts, Google Maps, Google Messages, Google Photos
- **Productivity**: Basecamp, ChatGPT, Figma, Fizzy, GitHub
- **Media**: X, YouTube

### Configuration Tweaks

#### Keybinding Toggles

| Tweak | Description |
|-------|-------------|
| Rebind close window | Changes SUPER+W to SUPER+Q |
| Bind/Unbind shutdown | SUPER+ALT+S for `systemctl poweroff` |
| Bind/Unbind restart | SUPER+ALT+R for `systemctl reboot` |
| Bind/Unbind theme menu | ALT+T for Omarchy theme selector |
| Swap Alt and Super keys | macOS-like modifier key layout |
| Restore Alt/Super keys | Return to default modifier layout |

#### Keybind Editor

A full keybinding editor that loads all active Hyprland bindings from config files and displays them in a scrollable list organized by section (Clipboard, Tiling, Utilities, Media, User Bindings). Modified bindings are marked with a `*` prefix.

**Edit flow** — press Space on any binding to start a guided 3-step rebind:

1. **Modifier selection** — toggle SUPER, SHIFT, CTRL, ALT with Space, navigate with arrows
2. **Key input** — type a key name (e.g. Q, RETURN, F1) validated against known Hyprland keys
3. **Preview & confirm** — review the new binding before accepting; shows a **conflict warning** if the key combo is already bound to another action

Press `R` to reset a pending edit back to its current value.

On confirm, the editor writes `unbind` + `bindd` pairs to `~/.config/hypr/bindings.conf`, following Hyprland's standard override pattern. Existing overrides from previous sessions are detected and applied in-place so the editor always shows the currently active bindings.

**Data sources:**
- `~/.local/share/omarchy/default/hypr/bindings/clipboard.conf`
- `~/.local/share/omarchy/default/hypr/bindings/tiling-v2.conf`
- `~/.local/share/omarchy/default/hypr/bindings/utilities.conf`
- `~/.local/share/omarchy/default/hypr/bindings/media.conf`
- `~/.config/hypr/bindings.conf` (user overrides)

#### Hyprland Configurator

A dedicated Hyprland section with 69 curated settings across 4 categories, offering precise numeric, enum, color, and boolean control through guided input dialogs. Changes are written as managed blocks appended to config files using Hyprland's "last value wins" behavior, so they safely override defaults without touching original files.

**Edit dialogs** — press Space on any setting:
- **Bool** — toggles ON/OFF in-place, no dialog needed
- **Int/Float** — text input with range validation
- **Enum** — arrow-key option selection
- **Color** — text input supporting `rgba()`, `rgb()`, and gradients

Modified settings show a `*` prefix and `current > new` values. Press `R` to reset a pending edit. On confirm, settings are written to `~/.config/hypr/looknfeel.conf` or `~/.config/hypr/input.conf` as appropriate.

Previous settings are detected on subsequent runs so you always see your current configuration.

<details>
<summary>General (26 settings)</summary>

| Setting | Type | Description |
|---------|------|-------------|
| Gap between windows | int 0-100 | Gap size between tiled windows |
| Gap from edges | int 0-100 | Gap size from screen edges |
| Border width | int 0-10 | Window border thickness in pixels |
| Active border color | color | Border color of focused window |
| Inactive border color | color | Border color of unfocused windows |
| Drag-resize borders | bool | Allow resizing windows by dragging borders |
| No border floating | bool | Remove borders from floating windows |
| Border grab area | int 0-50 | Extra pixels for grabbing window borders |
| Allow screen tearing | bool | Allow tearing for reduced input lag |
| Window layout | dwindle/master | Tiling layout algorithm |
| Pseudotiling | bool | Windows keep requested size in tiling |
| Keep split direction | bool | Maintain split direction on resize |
| Split direction | 0/1/2 | Follow mouse, left/top, or right/bottom |
| Smart split | bool | Split direction follows cursor position |
| New window status | master/slave | Where new windows appear in master layout |
| Focus on activation | bool | Focus windows when they request activation |
| Disable startup logo | bool | Hide the Hyprland logo on startup |
| Variable refresh rate | 0/1/2 | Off, on, or fullscreen only (FreeSync/G-Sync) |
| New window vs fullscreen | 0/1/2 | Behind, unfullscreen, or new fullscreen |
| Middle click paste | bool | Paste clipboard on middle mouse click |
| Window swallowing | bool | Terminal windows absorb spawned child windows |
| Workspace back-forth | bool | Same workspace key toggles to previous |
| Workspace cycles | bool | Allow cycling through workspaces with binds |
| XWayland zero scale | bool | Fix blurry XWayland apps on scaled displays |
| Keypress wakes display | bool | Keypress wakes display from DPMS off |
| Mouse wakes display | bool | Mouse movement wakes display from DPMS off |

</details>

<details>
<summary>Decoration (22 settings)</summary>

| Setting | Type | Description |
|---------|------|-------------|
| Corner radius | int 0-30 | Window corner rounding in pixels |
| Shadows | bool | Enable window drop shadows |
| Shadow range | int 1-100 | Shadow spread distance in pixels |
| Shadow sharpness | int 1-4 | Shadow falloff power |
| Shadow color | color | Shadow color in rgba format |
| Blur | bool | Enable background blur on transparent windows |
| Blur radius | int 1-20 | Blur kernel size |
| Blur iterations | int 1-10 | Blur render passes |
| Blur special ws | bool | Apply blur to special workspace background |
| Blur brightness | float 0.0-2.0 | Brightness of blurred background |
| Blur contrast | float 0.0-2.0 | Contrast of blurred background |
| Blur noise | float 0.0-1.0 | Noise applied to blur |
| Blur popups | bool | Apply blur to popup windows and tooltips |
| Animations | bool | Enable window animations |
| Dim inactive | bool | Dim unfocused windows |
| Dim strength | float 0.0-1.0 | How much to dim inactive windows |
| Dim special ws bg | float 0.0-1.0 | Dim amount for special workspace background |
| Hide cursor on type | bool | Hide cursor when typing |
| Cursor size | int 16-48 | Cursor size in pixels |
| Active opacity | float 0.0-1.0 | Opacity of focused window |
| Inactive opacity | float 0.0-1.0 | Opacity of unfocused windows |
| Fullscreen opacity | float 0.0-1.0 | Opacity of fullscreen windows |

</details>

<details>
<summary>Input (16 settings)</summary>

| Setting | Type | Description |
|---------|------|-------------|
| Mouse sensitivity | float -1.0-1.0 | Mouse sensitivity |
| Focus follows mouse | 0/1/2/3 | Focus behavior on mouse move |
| Accel profile | flat/adaptive | Mouse acceleration profile |
| Disable acceleration | bool | Force disable mouse acceleration entirely |
| Left handed mouse | bool | Swap left and right mouse buttons |
| Key repeat speed | int 1-100 | Key repeat rate in characters per second |
| Key repeat delay | int 100-2000 | Delay before key repeat starts (ms) |
| Numlock on start | bool | Enable numlock on startup |
| Natural scroll | bool | Reverse scroll direction |
| Scroll speed | float 0.1-5.0 | Touchpad scroll speed multiplier |
| Off while typing | bool | Disable touchpad while typing |
| Tap to click | bool | Enable tap-to-click on touchpad |
| Drag lock | bool | Keep drag active after lifting finger |
| Middle btn emulation | bool | Emulate middle click with two-finger tap |
| Scroll button | int 0-999 | Button for on-button-down scrolling |
| Scroll method | 2fg/edge/on_button_down/no_scroll | Touchpad scroll method |

</details>

<details>
<summary>Gestures (5 settings)</summary>

| Setting | Type | Description |
|---------|------|-------------|
| Workspace swipe | bool | Swipe between workspaces on touchpad |
| Swipe fingers | int 2-5 | Number of fingers for workspace swipe |
| Swipe distance | int 50-1000 | Distance in pixels to trigger swipe |
| Invert swipe | bool | Reverse workspace swipe direction |
| Swipe new workspace | bool | Create new workspace at end of swipe |

</details>

**Config files written:**
- `~/.config/hypr/looknfeel.conf` — General, Decoration, and Gestures settings (managed block)
- `~/.config/hypr/input.conf` — Input settings (managed block)

#### Keyboard & Input

| Tweak | Description |
|-------|-------------|
| Restore Caps Lock | Moves compose key to Right Alt, restores Caps Lock |
| Use Caps Lock for compose | Omarchy default - Caps Lock becomes compose key |

**Compose key combinations** (when using Caps Lock as compose):
- `Caps Lock + Space + Space` → em dash (—)
- `Caps Lock + m + s` → emoji picker
- `Caps Lock + Space + n` → custom name
- `Caps Lock + Space + e` → custom email

#### Monitor & Display

| Tweak | Type | Description |
|-------|------|-------------|
| Monitor scale | radio | Set 4K (GDK_SCALE=1.75, scale 1.666667) or 1080p/1440p (GDK_SCALE=1, no scaling) |
| Detect monitors | action | Scan connected displays and show resolution, scale, position, and make/model |
| Position monitors | action | Arrange multi-monitor layout with a guided step-by-step editor |
| Laptop display | toggle | Auto-disable laptop screen when an external display is connected |

##### Detect Monitors

Press Space on "Detect monitors" to open a full-screen dialog that runs `hyprctl monitors` and displays all connected outputs with their details:

- Name (e.g. `eDP-2`, `HDMI-A-1`)
- Resolution, scale, and current position
- Make/model description
- Laptop displays (eDP-*) are tagged with a `(laptop)` label

If 2 or more monitors are detected, press **I** to identify — each monitor flashes its name and number on-screen for 2 seconds using `hyprctl notify`, so you can tell which physical display is which.

##### Position Monitors

Press Space on "Position monitors" to open a guided multi-step editor for arranging your monitor layout. Requires 2+ monitors (auto-detects if not already scanned).

**Step 1 — Select primary monitor:** Choose which monitor sits at the origin (0,0) using arrow keys and Enter, then select its rotation (Normal, 90°, 180°, 270°).

**Step 2 — Place each remaining monitor:** For each unplaced monitor:
1. Select which already-placed monitor to position it relative to (arrow selection)
2. Choose direction: Right of / Left of / Above / Below (arrow selection)
3. Select rotation: Normal (landscape), 90° (portrait right), 180° (inverted), 270° (portrait left)
4. Position is calculated automatically using **scaled coordinates** (effective width = resolution / scale), with width and height swapped for 90°/270° rotations to match the rotated dimensions

**Step 3 — Preview & confirm:** Review all monitors with their calculated positions and rotations, then type `yes` to queue the layout.

On confirm, the layout is written to `~/.config/hypr/monitors.conf` with:
- One `monitor=<name>,preferred,<x>x<y>,<scale>,transform,<n>` line per display
- `env = GDK_SCALE` set automatically (1.75 if any monitor scale > 1.5, otherwise 1)
- A `monitor=,preferred,auto,1` fallback line for hot-plugged displays
- Timestamped backup of the previous config

Supports L-shaped and stacked layouts — each secondary monitor can be placed relative to any already-placed monitor, not just the primary.

If a per-monitor layout already exists and you select the generic "Monitor scale" option (4K or 1080p/1440p), a warning is shown that it will replace the per-monitor config.

##### Laptop Display Auto-Off

Toggle "Laptop display" to "Auto off" to automatically disable the laptop screen whenever an external display is connected, and re-enable it when unplugged.

**How it works:**

1. Creates a watcher script at `~/.config/hypr/scripts/laptop-display-auto.sh` that:
   - Detects the laptop display (eDP-*) and the backlight device (auto-detected from `/sys/class/backlight/`)
   - On external display connect: disables the laptop monitor via `hyprctl keyword monitor` and turns off the backlight via `brightnessctl`
   - On external display disconnect: restores the laptop monitor and brightness
   - Saves the current brightness level before turning off and restores it exactly
   - Monitors for plug/unplug events via Hyprland's IPC socket (falls back to `nc`, then 5-second polling if `socat` is unavailable)
   - Includes a 1-second debounce to prevent rapid event oscillation
2. Adds an `exec-once` line to `~/.config/hypr/monitors.conf` (managed block) so the watcher starts automatically on login
3. Starts the watcher immediately (no logout required)

Toggle to "Normal" to disable: removes the watcher script, kills any running instance, removes the managed block from config, and re-enables the laptop display with restored brightness.

##### Power Profile

Press Space on "Power profile" to open an arrow-key selection dialog with three options:

- **Power saver** — reduces CPU frequency and brightness for maximum battery life
- **Balanced** — default profile balancing performance and power consumption
- **Performance** — maximum CPU performance at the cost of higher power draw

The dialog marks the currently active profile with `(active)` and any previously configured startup default with `(default)`.

On confirm, the selected profile is:
1. Applied immediately via `powerprofilesctl set`
2. Persisted across reboots by creating a startup script at `~/.config/hypr/scripts/power-profile-default.sh`
3. Auto-started on login via an `exec-once` managed block in `~/.config/hypr/monitors.conf`

Requires `power-profiles-daemon` (provides `powerprofilesctl`). If not installed, the dialog shows a graceful error message.

##### Battery Charge Limit

Press Space on "Battery limit" to open an arrow-key selection dialog with four presets:

- **60%** — Maximum longevity
- **80%** — Recommended
- **90%** — Slight protection
- **100%** — No limit (full charge)

The dialog marks the current sysfs threshold with `(current)` and any previously configured udev default with `(default)`.

On confirm, the selected limit is:
1. Applied immediately via `sudo tee` to `/sys/class/power_supply/BAT*/charge_control_end_threshold`
2. Persisted across reboots by writing a udev rule at `/etc/udev/rules.d/99-battery-charge-limit.rules`
3. Udev rules reloaded via `udevadm control --reload-rules`
4. Waybar battery tooltip updated to show the configured limit (e.g. "80% plugged (limit: 80%)")
5. Waybar plugged icon changed from plug to battery (since the battery stops charging at the limit)

Setting 100% (no limit) removes the udev rule and restores original waybar icon and tooltips.

Requires a battery with kernel-exposed `charge_control_end_threshold` support. If not available, the dialog shows a graceful error message.

#### Window Management

| Tweak | Description |
|-------|-------------|
| Enable rounded corners | Adds rounded corners to windows, Walker menus, SwayOSD, hyprlock, mako notifications, and waybar tooltips |
| Disable rounded corners | Returns all UI elements to sharp/square corners |
| Remove window gaps | Maximize screen real estate |
| Restore window gaps | Return to default window spacing |

#### Visual Customization

| Tweak | Description |
|-------|-------------|
| Show all tray icons | All system tray icons always visible |
| Hide tray icons | Use expander for cleaner bar |
| Enable 12-hour clock | Clock displays with AM/PM |
| Disable 12-hour clock | 24-hour format |
| Show clock date | Display day name on clock (e.g. "Sunday 10:55 AM") |
| Hide clock date | Show time only (e.g. "10:55 AM") |
| Show window title | Display active window name next to workspaces |
| Hide window title | Remove active window name from waybar |

#### Media Organization

| Tweak | Description |
|-------|-------------|
| Enable media directories | Screenshots → `~/Pictures/Screenshots`, Recordings → `~/Videos/Screencasts` |
| Disable media directories | Use default `~/Pictures` and `~/Videos` |

#### System Features

| Tweak | Description |
|-------|-------------|
| Enable suspend | Show suspend option in system menu |
| Disable suspend | Hide suspend from system menu |
| Enable hibernation | Creates swap subvolume matching RAM size |
| Disable hibernation | Removes hibernation support |
| Enable fingerprint auth | Set up fingerprint for sudo/login |
| Disable fingerprint auth | Remove fingerprint authentication |
| Enable FIDO2 auth | Set up security keys (YubiKey, etc.) |
| Disable FIDO2 auth | Remove security key authentication |
| Power profile | Set default power profile (power-saver, balanced, performance) restored on startup |
| Battery limit | Set maximum battery charge level (60%/80%/90%/100%) for longer lifespan |

### Extra Themes

Browse and install 86 community-made themes directly from the TUI. Themes are sourced from the [Omarchy Extra Themes](https://learn.omacom.io/2/the-omarchy-manual/90/extra-themes) directory and installed via `omarchy-theme-install`.

- Already-installed themes are marked with `(installed)` and skipped during installation
- The last theme installed becomes the active theme
- Themes are installed to `~/.config/omarchy/themes/`
- Press `A` to select/deselect all themes at once
- Themes that require GitHub authentication are automatically skipped after a timeout

<details>
<summary>Available themes (86)</summary>

| Theme | Repository |
|-------|------------|
| Aetheria | JJDizz1L/aetheria |
| All Hallow's Eve | guilhermetk/omarchy-all-hallows-eve-theme |
| Amberbyte | tahfizhabib/omarchy-amberbyte-theme |
| Arc Blueberry | vale-c/omarchy-arc-blueberry |
| Archwave | davidguttman/archwave |
| Artzen | tahfizhabib/omarchy-artzen-theme |
| Ash | bjarneo/omarchy-ash-theme |
| Aura | bjarneo/omarchy-aura-theme |
| Ayaka | abhijeet-swami/omarchy-ayaka-theme |
| Azure Glow | Hydradevx/omarchy-azure-glow-theme |
| Bauhaus | somerocketeer/omarchy-bauhaus-theme |
| Black Arch | ankur311sudo/black_arch |
| Black Gold | HANCORE-linux/omarchy-blackgold-theme |
| Black Turq | HANCORE-linux/omarchy-blackturq-theme |
| Bliss | mishonki3/omarchy-bliss-theme |
| Blue Ridge Dark | hipsterusername/omarchy-blueridge-dark-theme |
| bluedotrb | dotsilva/omarchy-bluedotrb-theme |
| Catppuccin Mocha Dark | Luquatic/omarchy-catppuccin-dark |
| Citrus Cynapse | Grey-007/citrus-cynapse |
| Cobalt2 | hoblin/omarchy-cobalt2-theme |
| Darcula | noahljungberg/omarchy-darcula-theme |
| Demon | HANCORE-linux/omarchy-demon-theme |
| Dotrb | dotsilva/omarchy-dotrb-theme |
| Drac | ShehabShaef/omarchy-drac-theme |
| Dracula | catlee/omarchy-dracula-theme |
| Eldritch | eldritch-theme/omarchy |
| Evergarden | celsobenedetti/omarchy-evergarden |
| Felix | TyRichards/omarchy-felix-theme |
| Fireside | bjarneo/omarchy-fireside-theme |
| Flexoki Dark | euandeas/omarchy-flexoki-dark-theme |
| Forest Green | abhijeet-swami/omarchy-forest-green-theme |
| Frost | bjarneo/omarchy-frost-theme |
| Futurism | bjarneo/omarchy-futurism-theme |
| Gold Rush | tahayvr/omarchy-gold-rush-theme |
| Green Garden | kalk-ak/omarchy-green-garden-theme |
| Green Hakkar | joaquinmeza/omarchy-hakker-green-theme |
| Gruvu | ankur311sudo/gruvu |
| Infernium | RiO7MAKK3R/omarchy-infernium-dark-theme |
| Map Quest | ItsABigIgloo/omarchy-mapquest-theme |
| Mars | steve-lohmeyer/omarchy-mars-theme |
| Mechanoonna | HANCORE-linux/omarchy-mechanoonna-theme |
| Miasma | OldJobobo/omarchy-miasma-theme |
| Midnight | JaxonWright/omarchy-midnight-theme |
| Milky Matcha | hipsterusername/omarchy-milkmatcha-light-theme |
| Monochrome | Swarnim114/omarchy-monochrome-theme |
| Monokai | bjarneo/omarchy-monokai-theme |
| Nagai Poolside | somerocketeer/omarchy-nagai-poolside-theme |
| Neo Sploosh | monoooki/omarchy-neo-sploosh-theme |
| Neovoid | RiO7MAKK3R/omarchy-neovoid-theme |
| NES | bjarneo/omarchy-nes-theme |
| Omacarchy | RiO7MAKK3R/omarchy-omacarchy-theme |
| One Dark Pro | sc0ttman/omarchy-one-dark-pro-theme |
| Pandora | imbypass/omarchy-pandora-theme |
| Pina | bjarneo/omarchy-pina-theme |
| Pink Blood | ITSZXY/pink-blood-omarchy-theme |
| Pulsar | bjarneo/omarchy-pulsar-theme |
| Purple Moon | Grey-007/purple-moon |
| Purplewave | dotsilva/omarchy-purplewave-theme |
| Rainy Night | atif-1402/omarchy-rainynight-theme |
| RetroPC | rondilley/omarchy-retropc-theme |
| Rose of Dune | HANCORE-linux/omarchy-roseofdune-theme |
| Rose Pine Dark | guilhermetk/omarchy-rose-pine-dark |
| Sakura | bjarneo/omarchy-sakura-theme |
| Sapphire | HANCORE-linux/omarchy-sapphire-theme |
| Shades of Jade | HANCORE-linux/omarchy-shadesofjade-theme |
| Snow | bjarneo/omarchy-snow-theme |
| Snow Black | ankur311sudo/snow_black |
| Solarized | Gazler/omarchy-solarized-theme |
| Solarized Light | dfrico/omarchy-solarized-light-theme |
| Solarized Osaka | motorsss/omarchy-solarizedosaka-theme |
| Space Monkey | TyRichards/omarchy-space-monkey-theme |
| Sunset | rondilley/omarchy-sunset-theme |
| Sunset Drive | tahayvr/omarchy-sunset-drive-theme |
| Super Game Bro | TyRichards/omarchy-super-game-bro-theme |
| Synthwave '84 | omacom-io/omarchy-synthwave84-theme |
| Temerald | Ahmad-Mtr/omarchy-temerald-theme |
| The Greek | HANCORE-linux/omarchy-thegreek-theme |
| Tokyo Night OLED | Justin-De-Sio/omarchy-tokyoled-theme |
| Torrentz Hydra | monoooki/omarchy-torrentz-hydra-theme |
| Tycho | leonardobetti/omarchy-tycho |
| Van Gogh | Nirmal314/omarchy-van-gogh-theme |
| Vesper | thmoee/omarchy-vesper-theme |
| VHS 80 | tahayvr/omarchy-vhs80-theme |
| Void | vyrx-dev/omarchy-void-theme |
| Waveform Dark | hipsterusername/omarchy-waveform-dark-theme |
| White Gold | HANCORE-linux/omarchy-whitegold-theme |

</details>

### Backup Config

Creates a timestamped archive (`~/omarchy-backup-YYYYMMDD_HHMMSS.tar.gz`) of your Omarchy configuration directories:

- `~/.config/hypr/`
- `~/.config/waybar/`
- `~/.config/mako/`
- `~/.config/omarchy/`
- `~/.config/walker/`
- `~/.config/alacritty/`
- `~/.config/kitty/`
- `~/.config/ghostty/`

Also generates `~/restore-omarchy-config.sh` — a self-contained script to restore from any previous backup. Symlinks are followed so the actual file content is preserved in the backup.

#### Backup Timing

When backup is selected alongside configuration tweaks, you'll be prompted to choose when to back up:

| Option | Description |
|--------|-------------|
| Before changes | Preserve current state as a rollback point |
| After changes | Save the new configuration |
| Both | Full safety net — before and after |

If backup is the only selection (no tweaks), it runs immediately.

#### Restoring from Backup

Run the restore script to choose from all available backups:

```bash
bash ~/restore-omarchy-config.sh
```

The restore script lists all backups with dates and sizes, letting you select which one to restore:

```
Available backups:

  1) 2026-02-11 14:30:15  (12K)
  2) 2026-02-11 14:28:42  (12K)

Select a backup to restore (1-2):
```

### Menu Shortcut

Adds an "A La Carchy" entry to the Omarchy launcher menu (SUPER+ALT+SPACE) so you can launch the TUI without remembering the curl command.

| Option | Description |
|--------|-------------|
| Add | Creates `~/.config/omarchy/extensions/menu.sh` with menu overrides |
| Remove | Removes the managed block (deletes the file if empty) |

The extension file is generated at runtime by reading the installed `omarchy-menu` script directly, preserving all icons and menu entries. It uses Omarchy's built-in extension mechanism (`~/.config/omarchy/extensions/menu.sh`) which is sourced after the default menu functions, so the overrides take effect immediately.

## Safety Features

- Never run as root (uses sudo only when needed)
- Confirmation prompt before every action
- Shows exactly what will be removed
- Uses `-Rns` flags to remove dependencies safely
- Timestamped backups created before modifying any config file
- Backup runs before any config modifications when selected with tweaks
- Config backup follows symlinks to preserve actual file content
- Restore script lists all backups and lets you choose which to restore
- Restore script prompts for confirmation before overwriting
- Idempotent operations - skips actions already applied

## Package Names

The script uses the following package name mappings:

| Application | Package Name |
|------------|--------------|
| 1Password | 1password-beta |
| 1Password CLI | 1password-cli |
| Calculator | gnome-calculator |
| Chromium | omarchy-chromium |
| Docker (Core Engine) | docker |
| Docker Buildx | docker-buildx |
| Docker Compose | docker-compose |
| Kdenlive | kdenlive |
| LibreOffice | libreoffice-fresh |
| LocalSend | localsend |
| OBS Studio | obs-studio |
| Obsidian | obsidian |
| Pinta | pinta |
| Signal | signal-desktop |
| Spotify | spotify |
| Typora | typora |
| Xournal++ | xournalpp |

### Web Apps

The script can remove the following Omarchy webapps (stored as `.desktop` files in `~/.local/share/applications`):

| Web App | Desktop File |
|---------|--------------|
| Basecamp | Basecamp.desktop |
| ChatGPT | ChatGPT.desktop |
| Discord | Discord.desktop |
| Figma | Figma.desktop |
| Fizzy | Fizzy.desktop |
| GitHub | GitHub.desktop |
| Google Contacts | Google Contacts.desktop |
| Google Maps | Google Maps.desktop |
| Google Messages | Google Messages.desktop |
| Google Photos | Google Photos.desktop |
| HEY | HEY.desktop |
| WhatsApp | WhatsApp.desktop |
| X | X.desktop |
| YouTube | YouTube.desktop |
| Zoom | Zoom.desktop |

## Configuration Files Modified

The script modifies the following Omarchy configuration files (with automatic backups):

| File | Purpose |
|------|---------|
| `~/.config/hypr/monitors.conf` | Monitor scaling, multi-monitor positions, laptop auto-off exec-once, power profile exec-once |
| `~/.config/hypr/bindings.conf` | Keybindings (toggles and keybind editor overrides) |
| `~/.config/hypr/looknfeel.conf` | Rounded corners, window gaps, Hyprland General/Decoration/Gestures settings |
| `~/.config/hypr/hyprlock.conf` | Rounded corners on lock screen password input |
| `~/.config/hypr/input.conf` | Compose key, Alt/Super swapping, Hyprland Input settings |
| `~/.config/hypr/scripts/laptop-display-auto.sh` | Laptop auto-off watcher script (created/removed by toggle) |
| `~/.config/hypr/scripts/power-profile-default.sh` | Power profile startup script (sets default profile on login) |
| `/etc/udev/rules.d/99-battery-charge-limit.rules` | Battery charge limit persistence (created/removed by battery limit) |
| `~/.config/waybar/config.jsonc` | Clock format, tray icons, battery charge limit tooltip |
| `~/.config/waybar/style.css` | Rounded corners on waybar tooltips |
| `~/.config/swayosd/style.css` | Rounded corners on volume/brightness overlay |
| `~/.config/uwsm/default` | Screenshot/recording directories |
| `~/.local/share/omarchy/default/walker/themes/omarchy-default/style.css` | Rounded corners, transparency on Walker launcher/menus |
| `~/.local/share/omarchy/default/mako/core.ini` | Rounded corners on notifications |
| `~/.local/share/omarchy/default/hypr/windows.conf` | Window transparency (global opacity rule) |
| `~/.local/share/omarchy/default/hypr/apps/browser.conf` | Browser transparency (chromium/firefox opacity rules) |
| `~/.local/share/omarchy/default/hypr/bindings/tiling-v2.conf` | Close window binding |
| `~/.config/omarchy/extensions/menu.sh` | Menu shortcut (A La Carchy entry in Omarchy menu) |
| `~/.local/share/omarchy/default/hypr/bindings/*.conf` | Read by keybind editor (not modified) |

## Troubleshooting

### "No AUR helper detected"
Install yay or paru:
```bash
sudo pacman -S --needed base-devel git
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si
```

### Package name doesn't match
If a package name is incorrect, you can edit the `PACKAGES` array in the script to match your system's actual package names.

## After Removal

After removing packages, you may want to clean up:

```bash
# Clean package cache
yay -Sc

# Remove orphaned packages
yay -Yc
```

## License

This is free and unencumbered software released into the public domain.

## Contributing

If you find incorrect package names or want to add more packages, please submit an issue or pull request.
