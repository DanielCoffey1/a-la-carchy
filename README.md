# A La Carchy

**Pick and choose what you want to remove, à la carte style!**

A simple TUI (Terminal User Interface) debloater for Omarchy Linux.

## Features

- Interactive checklist of preinstalled packages
- Only shows packages that are currently installed
- Works with `yay`, `paru`, or `pacman`
- Safe removal with confirmation prompts
- **No installation required** - just run the one-liner command!
- Auto-installs dependencies (`dialog`) if needed
- Color-coded output for better visibility

## Quick Start (One-Liner)

Just paste this command in your terminal and press Enter:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/DanielCoffey1/a-la-carchy/master/a-la-carchy.sh)
```

That's it! The script will:
1. Auto-install `dialog` if needed
2. Show you an interactive checklist
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
- `dialog` will be auto-installed if not present

## How to Use

1. Run the script using one of the methods above
2. Use the interactive menu:
   - Navigate with arrow keys
   - Press `Space` to select/deselect packages
   - Press `Enter` to confirm your selection
3. Type `yes` when prompted to confirm removal

## What Gets Removed

The script can remove the following preinstalled applications:

- **Browsers**: Chromium
- **Productivity**: LibreOffice Suite, Obsidian, Typora, Xournal++
- **Media**: Kdenlive, OBS Studio, VLC Media Player, Spotify
- **Graphics**: Pinta, Image Viewer
- **Communication**: Signal, LocalSend
- **Development**: Docker, Neovim, Alacritty, Ghostty
- **Security**: 1Password
- **Utilities**: Calculator, Document Viewer
- **Other**: Aether

## Safety Features

- Never run as root (uses sudo only when needed)
- Confirmation prompt before removal
- Shows exactly what will be removed
- Uses `-Rns` flags to remove dependencies safely

## Package Names

The script uses the following package name mappings:

| Application | Package Name |
|------------|--------------|
| 1Password | 1password |
| Aether | aether |
| Alacritty | alacritty |
| Calculator | gnome-calculator |
| Chromium | chromium |
| Docker | docker |
| Document Viewer | evince |
| Ghostty | ghostty |
| Image Viewer | eog |
| Kdenlive | kdenlive |
| LibreOffice | libreoffice-still |
| LocalSend | localsend-bin |
| Media Player | vlc |
| Neovim | neovim |
| OBS Studio | obs-studio |
| Obsidian | obsidian |
| Pinta | pinta |
| Signal | signal-desktop |
| Spotify | spotify |
| Typora | typora |
| Xournal++ | xournalpp |

## Troubleshooting

### "dialog is not installed"
Install it with:
```bash
sudo pacman -S dialog
```

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
