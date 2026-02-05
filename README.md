# A La Carchy

**Pick and choose what you want to remove, à la carte style!**

![A La Carchy TUI](screenshots/A%20La%20Carchy.png)

A simple TUI (Terminal User Interface) debloater and configuration tool for Omarchy Linux.

## Features

- **Beautiful centered TUI** with smooth navigation
- Interactive checklist of preinstalled packages and webapps
- Only shows packages and webapps that are currently installed
- **40+ configuration tweaks** for keybindings, display, and system settings
- **Backup & restore** config directories with a single selection
- **Summary screen** after all actions complete
- Safe removal with confirmation prompts
- **No installation required** - just run the one-liner command!
- No external dependencies needed
- Clean, modern interface

## Quick Start (One-Liner)

Just paste this command in your terminal and press Enter:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/DanielCoffey1/a-la-carchy/master/a-la-carchy.sh)
```

That's it! The script will:
1. Show you a beautiful centered TUI
2. Let you select packages/webapps to remove and actions to run
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
2. Use the interactive menu:
   - **↑/↓** Navigate through applications and actions
   - **Space** Select/deselect items
   - **Enter** Continue with selected actions
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

Also generates `~/restore-omarchy-config.sh` — a self-contained script that extracts the archive back into place. Symlinks are followed so the actual file content is preserved in the backup.

To restore later:

```bash
bash ~/restore-omarchy-config.sh
```

## Safety Features

- Never run as root (uses sudo only when needed)
- Confirmation prompt before every action
- Shows exactly what will be removed
- Uses `-Rns` flags to remove dependencies safely
- Timestamped backups created before modifying any config file
- Config backup follows symlinks to preserve actual file content
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
