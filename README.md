# A La Carchy

**Pick and choose what you want to remove, à la carte style!**

![A La Carchy TUI](screenshots/A%20La%20Carchy.png)

A simple TUI (Terminal User Interface) debloater for Omarchy Linux.

## Features

- **Beautiful centered TUI** with smooth navigation
- Interactive checklist of preinstalled packages **and webapps**
- Only shows packages and webapps that are currently installed
- Works with `yay`, `paru`, or `pacman`
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
2. Let you select packages to remove
3. Remove selected packages safely

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
   - **↑/↓** Navigate through applications
   - **Space** Select/deselect packages
   - **Enter** Continue with removal
   - **Q** Quit
3. Type `yes` when prompted to confirm removal

## What Gets Removed

### Packages

The script can remove the following preinstalled applications:

- **Browsers**: Chromium
- **Productivity**: LibreOffice Suite, Obsidian, Typora, Xournal++
- **Media**: Kdenlive, OBS Studio, MPV Media Player, Spotify
- **Graphics**: Pinta, IMV Image Viewer
- **Communication**: Signal, LocalSend
- **Development**: Docker (Core Engine, Buildx, Compose, UFW Integration), LazyDocker, Neovim, Alacritty, Ghostty
- **Security**: 1Password, 1Password CLI
- **Utilities**: Calculator, Document Viewer
- **Other**: Aether

### Web Apps

The script can also remove the following preinstalled Omarchy webapps:

- **Communication**: HEY, Basecamp, WhatsApp, Discord, Zoom
- **Google Services**: Google Photos, Google Contacts, Google Messages
- **Productivity**: ChatGPT, Figma, GitHub
- **Media**: YouTube, X

## Safety Features

- Never run as root (uses sudo only when needed)
- Confirmation prompt before removal
- Shows exactly what will be removed
- Uses `-Rns` flags to remove dependencies safely

## Package Names

The script uses the following package name mappings:

| Application | Package Name |
|------------|--------------|
| 1Password | 1password-beta |
| 1Password CLI | 1password-cli |
| Aether | aether |
| Alacritty | alacritty |
| Calculator | gnome-calculator |
| Chromium | chromium |
| Docker (Core Engine) | docker |
| Docker Buildx (Extended Build) | docker-buildx |
| Docker Compose (Orchestration) | docker-compose |
| Docker UFW (Firewall Integration) | ufw-docker |
| Document Viewer | evince |
| Ghostty | ghostty |
| Image Viewer | imv |
| Kdenlive | kdenlive |
| LazyDocker (Docker TUI) | lazydocker |
| LibreOffice | libreoffice-fresh |
| LibreOffice Base | libreoffice-fresh-base |
| LibreOffice Calc | libreoffice-fresh-calc |
| LibreOffice Draw | libreoffice-fresh-draw |
| LibreOffice Impress | libreoffice-fresh-impress |
| LibreOffice Math | libreoffice-fresh-math |
| LibreOffice Writer | libreoffice-fresh-writer |
| LocalSend | localsend-bin |
| Media Player | mpv |
| Neovim | neovim |
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
| HEY | HEY.desktop |
| Basecamp | Basecamp.desktop |
| WhatsApp | WhatsApp.desktop |
| Google Photos | Google Photos.desktop |
| Google Contacts | Google Contacts.desktop |
| Google Messages | Google Messages.desktop |
| ChatGPT | ChatGPT.desktop |
| YouTube | YouTube.desktop |
| GitHub | GitHub.desktop |
| X | X.desktop |
| Figma | Figma.desktop |
| Discord | Discord.desktop |
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
