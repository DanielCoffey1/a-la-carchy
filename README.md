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
- No external dependencies - works out of the box!

## How to Use

1. Run the script using one of the methods above
2. Use the two-panel interface:
   - **←/→** Switch between the category panel (left) and items panel (right)
   - **↑/↓** Navigate within the current panel
   - **Space** Select/deselect items (in the right panel)
   - **A** Select/deselect all (Extra Themes only)
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

#### Keybinding Management

| Tweak | Description |
|-------|-------------|
| Rebind close window | Changes SUPER+W to SUPER+Q |
| Bind/Unbind shutdown | SUPER+ALT+S for `systemctl poweroff` |
| Bind/Unbind restart | SUPER+ALT+R for `systemctl reboot` |
| Bind/Unbind theme menu | ALT+T for Omarchy theme selector |
| Swap Alt and Super keys | macOS-like modifier key layout |
| Restore Alt/Super keys | Return to default modifier layout |

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

| Tweak | Description |
|-------|-------------|
| Set monitor scaling for 4K | GDK_SCALE=1.75, Hyprland scale 1.666667 |
| Set monitor scaling for 1080p/1440p | GDK_SCALE=1, no scaling |

#### Window Management

| Tweak | Description |
|-------|-------------|
| Enable rounded corners | Adds rounded corners to windows |
| Disable rounded corners | Square window corners |
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
| `~/.config/hypr/monitors.conf` | Monitor scaling |
| `~/.config/hypr/bindings.conf` | Keybindings |
| `~/.config/hypr/looknfeel.conf` | Rounded corners, window gaps |
| `~/.config/hypr/input.conf` | Compose key, Alt/Super swapping |
| `~/.config/waybar/config.jsonc` | Clock format, tray icons |
| `~/.config/uwsm/default` | Screenshot/recording directories |
| `~/.local/share/omarchy/default/hypr/bindings/tiling-v2.conf` | Close window binding |

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
