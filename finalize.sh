#!/bin/bash
ROOT_PARTITION="/dev/nvme0n1p4"
ROOT_UUID=$(lsblk -o UUID $ROOT_PARTITION | grep -v UUID)

# Enable AUR Helper
git clone https://aur.archlinux.org/paru.git
cd paru
makepkg -sic

# Enable Snapshots in GRUB Menu
paru -Sa snap-pac-grub

# Enable Periodic Execution of TRIM
sudo systemctl enable fstrim.timer

# Enable Periodic Execution of btrfs scrub
UNIT_NAME=$(sudo systemd-escape --template btrfs-scrub@.timer --path /dev/disk/by-uuid/$ROOT_UUID)
sudo systemctl enable --now $UNIT_NAME
btrfs scrub start

# Edit Snapper Configuration
sed -i 's/QGROUP=""/QGROUP="1\/0"/' /etc/snappper/configs/root
sed -i 's/NUMBER_LIMIT="50"/NUMBER_LIMIT="10-35"/' /etc/snappper/configs/root
sed -i 's/NUMBER_LIMIT_IMPORTANT="50"/NUMBER_LIMIT_IMPORTANT="15-25"/' /etc/snappper/configs/root
sed -i 's/TIMELINE_LIMIT_HOURLY="10"/TIMELINE_LIMIT_HOURLY="5"/' /etc/snappper/configs/root
sed -i 's/TIMELINE_LIMIT_DAILY="10"/TIMELINE_LIMIT_DAILY="5"/' /etc/snappper/configs/root
sed -i 's/TIMELINE_LIMIT_WEEKLY="0"/TIMELINE_LIMIT_WEEKLY="2"/' /etc/snappper/configs/root
sed -i 's/TIMELINE_LIMIT_MONTHLY="10"/TIMELINE_LIMIT_MONTHLY="3"/' /etc/snappper/configs/root
sed -i 's/TIMELINE_LIMIT_YEARLY="10"/TIMELINE_LIMIT_YEARLY="0"/' /etc/snappper/configs/root

# Enable timeline snapshots timer.
sudo systemctl enable --now snapper-timeline.timer

# Enable the timeline cleanup timer.
sudo systemctl enable --now snapper-cleanup.timer

# Enable the multilib repository
sudo sed -i '93s/.//' /etc/pacman.conf
sudo sed -i '94s/.//' /etc/pacman.conf

# Refresh repositories
sudo pacman -Syy

# Install AUR packages and applications
paru -Sa amdgpu-pro-libgl lib32-amdgpu-pro-libgl opencl-amd decklink davinci-resolve-studio slack-desktop visual-studio-code-bin ttf-meslo-nerd-font-powerlevel10k nvm microsoft-edge-stable-bin teamredminer-bin 1password brother-hll2350dw zoom-system-qt

# Workaround for using proprietary OpenGL wtih Davinci Resolve
install /usr/share/applications/com.blackmagicdesign.resolve.desktop ~/.local/share/applications/com.blackmagicdesign.resolve.desktop
sed -i 's/Exec=\/opt\/resolve\/bin\/resolve %u/Exec=progl \/opt\/resolve\/bin\/resolve/' ~/.local/share/applications/com.blackmagicdesign.resolve.desktop

# Enable wayland for electron apps
echo -e "--enable-features=UseOzonePlatform\t--ozone-platform=wayland" >> ~/.config/electron-flags.conf

# Install Oh-My-Zsh
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# Install Oh-My-Zsh plugins
##########################################################################################################
#   1. install zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

#   2. install zsh-syntax-highlighting
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

#   3. Update plugins in ~/.zshrc
sed -i 's/plugins=(\(.*\))/plugins=(\1 archlinux zsh-autosuggestions zsh-syntax-highlighting)/' ~/.zshrc
