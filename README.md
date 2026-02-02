# A La Carchy

**Pick and choose what you want to remove, à la carte style!**

![A La Carchy TUI](screenshots/A%20La%20Carchy.png)

A simple TUI (Terminal User Interface) debloater and configuration tool for Omarchy Linux.

## Features

- **Beautiful centered TUI** with smooth navigation
- Interactive checklist of preinstalled packages **and webapps**
- Only shows packages and webapps that are currently installed
- **Rebind close window** from SUPER+W to SUPER+Q
- **Bind/unbind shutdown/restart** keybindings (SUPER+ALT+S / SUPER+ALT+R)
- **Monitor scaling** options for 4K and 1080p/1440p displays
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

### Rebind Close Window

Changes the close window keybinding from SUPER+W (Omarchy default) to SUPER+Q. Creates a backup of the original config before making changes.

### Shutdown & Restart Keybindings

Adds or removes keybindings in `~/.config/hypr/bindings.conf` for powering off or restarting the system:

- **Bind SUPER+ALT+S** — Shutdown (`systemctl poweroff`)
- **Bind SUPER+ALT+R** — Restart (`systemctl reboot`)
- **Unbind SUPER+ALT+S** — Remove shutdown keybinding
- **Unbind SUPER+ALT+R** — Remove restart keybinding

A timestamped backup of `bindings.conf` is created before any changes are applied. Skips if the binding already exists (or doesn't exist for unbind).

### Monitor Scaling

Configures `~/.config/hypr/monitors.conf` for your display resolution. Two options are available:

- **4K** — Sets `GDK_SCALE=1.75` with 1.666667 Hyprland scaling
- **1080p/1440p** — Sets `GDK_SCALE=1` with no scaling

A timestamped backup of `monitors.conf` is created before any changes are applied.

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
- Config backup follows symlinks to preserve actual file content
- Restore script prompts for confirmation before overwriting

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
