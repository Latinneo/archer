#!/bin/bash
ROOT_PARTITION="/dev/nvme0n1p4"
ROOT_UUID=$(lsblk -o UUID $ROOT_PARTITION | grep -v UUID)

# Install sound related packages
sudo pacman -Sy pipewire alsa-utils alsa-plugins pipewire-alsa pipewire-pulse pipewire-jack sof-firmware

# Install the X Window System and X Window System applications
sudo pacman -Sy xorg-server xorg-apps

# Install XDG related packages
sudo pacman -Sy xdg-user-dirs xdg-utils

# Install fonts
sudo pacman -Sy gnu-free-fonts noto-fonts ttf-bitstream-vera ttf-caladea ttf-carlito ttf-croscore ttf-dejavu ttf-hack opendesktop-fonts ttf-anonymous-pro ttf-arphic-ukai ttf-arphic-uming ttf-baekmuk ttf-cascadia-code ttf-cormorant ttf-droid ttf-eurof ttf-fantasque-sans-mono ttf-fira-code ttf-fira-mono ttf-fira-sans ttf-font-awesome ttf-hanazono ttf-hannom ttf-ibm-plex ttf-inconsolata ttf-indic-otf ttf-input ttf-ionicons ttf-iosevka-nerd ttf-jetbrains-mono ttf-joypixels ttf-junicode ttf-khmer ttf-lato ttf-liberation ttf-linux-libertine ttf-linux-libertine-g ttf-monofur ttf-monoid ttf-nerd-fonts-symbols ttf-opensans ttf-proggy-clean ttf-roboto ttf-roboto-mono ttf-sarasa-gothic ttf-sazanami ttf-tibetan-machine ttf-ubuntu-font-family

# Install Plasma and some KDE applications
sudo pacman -S plasma-meta plasma-wayland-session kde-utilities kde-system dolphin-plugins kde-graphics

# Install virtual machine management packages
sudo pacman -Sy virt-manager qemu qemu-arch-extra edk2-ovmf bridge-utils dnsmasq vde2 openbsd-netcat

# Install other applications
sudo pacman -Sy obs-studio

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
sudo btrfs scrub start

# Edit Snapper Configuration
sudo sed -i 's/QGROUP=""/QGROUP="1\/0"/' /etc/snappper/configs/root
sudo sed -i 's/NUMBER_LIMIT="50"/NUMBER_LIMIT="10-35"/' /etc/snappper/configs/root
sudo sed -i 's/NUMBER_LIMIT_IMPORTANT="50"/NUMBER_LIMIT_IMPORTANT="15-25"/' /etc/snappper/configs/root
sudo sed -i 's/TIMELINE_LIMIT_HOURLY="10"/TIMELINE_LIMIT_HOURLY="5"/' /etc/snappper/configs/root
sudo sed -i 's/TIMELINE_LIMIT_DAILY="10"/TIMELINE_LIMIT_DAILY="5"/' /etc/snappper/configs/root
sudo sed -i 's/TIMELINE_LIMIT_WEEKLY="0"/TIMELINE_LIMIT_WEEKLY="2"/' /etc/snappper/configs/root
sudo sed -i 's/TIMELINE_LIMIT_MONTHLY="10"/TIMELINE_LIMIT_MONTHLY="3"/' /etc/snappper/configs/root
sudo sed -i 's/TIMELINE_LIMIT_YEARLY="10"/TIMELINE_LIMIT_YEARLY="0"/' /etc/snappper/configs/root

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