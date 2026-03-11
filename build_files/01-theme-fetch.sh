#!/bin/bash

set -xeuo pipefail

# COPR: zirconium/packages (for matugen, iio-niri, valent-git)
dnf -y copr enable zirconium/packages
dnf -y copr disable zirconium/packages
dnf -y --enablerepo copr:copr.fedorainfracloud.org:zirconium:packages install \
    matugen \
    iio-niri \
    valent-git

# COPR: yalter/niri-git
dnf -y copr enable yalter/niri-git
dnf -y copr disable yalter/niri-git
dnf -y config-manager setopt copr:copr.fedorainfracloud.org:yalter:niri-git.priority=1
dnf -y --enablerepo copr:copr.fedorainfracloud.org:yalter:niri-git install --setopt=install_weak_deps=False \
    niri
niri --version | grep -i -E "niri [[:digit:]]*\.[[:digit:]]* (.*\.git\..*)"

# COPR: errornointernet/quickshell (NOT avengemedia/danklinux)
dnf -y copr enable errornointernet/quickshell
dnf -y copr disable errornointernet/quickshell
dnf -y --enablerepo copr:copr.fedorainfracloud.org:errornointernet:quickshell install quickshell-git

# COPR: mecattaf/harnessRPM
dnf -y copr enable mecattaf/harnessRPM
dnf -y copr disable mecattaf/harnessRPM
dnf -y --enablerepo copr:copr.fedorainfracloud.org:mecattaf:harnessRPM install \
    asr-rs \
    atuin \
    bibata-cursor-themes \
    cliphist \
    eza \
    lisgd \
    mactahoe-oled \
    nwg-look \
    pi \
    shpool \
    starship \
    wl-gammarelay-rs

# COPR: monkeygold/nautilus-open-any-terminal
dnf -y copr enable monkeygold/nautilus-open-any-terminal
dnf -y copr disable monkeygold/nautilus-open-any-terminal
dnf -y --enablerepo copr:copr.fedorainfracloud.org:monkeygold:nautilus-open-any-terminal install \
    nautilus-open-any-terminal

# Wayland environment
dnf -y install \
    brightnessctl \
    kanshi \
    playerctl \
    webp-pixbuf-loader \
    wl-clipboard \
    wtype

# Niri core
dnf -y install \
    foot \
    xdg-desktop-portal-gnome \
    xdg-terminal-exec \
    xwayland-satellite

# Login
dnf -y install \
    greetd \
    greetd-selinux

# Qt theming (no weak deps)
dnf install -y --setopt=install_weak_deps=False \
    kf6-kimageformats \
    kf6-kirigami \
    kf6-qqc2-desktop-style \
    plasma-breeze \
    qt6ct \
    qt6-qtmultimedia

# Polkit
dnf -y install polkit

# Codecs (negativo17 fedora-multimedia repo)
dnf config-manager addrepo --from-repofile=https://negativo17.org/repos/fedora-multimedia.repo
dnf config-manager setopt fedora-multimedia.enabled=0
dnf -y install --enablerepo=fedora-multimedia \
    -x PackageKit* \
    ffmpeg \
    ffmpegthumbnailer \
    gstreamer1-plugins-bad-free \
    gstreamer1-plugins-bad-free-libs \
    gstreamer1-plugins-base \
    gstreamer1-plugins-good \
    lame \
    lame-libs \
    libavcodec \
    libjxl \
    @multimedia

# Desktop apps
dnf -y install \
    cava \
    chezmoi \
    ddcutil \
    fastfetch \
    glycin-thumbnailer \
    input-remapper \
    nautilus-python \
    orca \
    wl-mirror \
    gnome-disk-utility \
    gnome-keyring \
    imv \
    kitty \
    kitty-terminfo \
    nautilus \
    udiskie \
    vlc \
    xarchiver \
    zathura \
    zathura-pdf-poppler

# Input methods
dnf -y install \
    fcitx5-mozc \
    ibus

# Fonts (DNF)
dnf -y install \
    default-fonts \
    default-fonts-core-emoji \
    fontawesome-fonts-all \
    glibc-all-langpacks \
    gnome-icon-theme \
    gnome-themes-extra \
    google-noto-color-emoji-fonts \
    google-noto-emoji-fonts \
    google-noto-fonts-common \
    google-noto-sans-fonts \
    google-roboto-fonts \
    overpass-fonts \
    overpass-mono-fonts

# Portals
dnf -y install \
    dbus-daemon \
    dbus-tools \
    gsettings-desktop-schemas \
    xdg-desktop-portal-gtk \
    xdg-user-dirs

# Dev tools
dnf -y install \
    cmake \
    cpio \
    dbus-x11 \
    direnv \
    fish \
    gcc \
    gcc-c++ \
    gh \
    git-credential-libsecret \
    git-lfs \
    libadwaita \
    make \
    meson \
    neovim \
    p7zip \
    pandoc \
    pipx \
    python3-cairo \
    python3-pip \
    ripgrep \
    uv \
    yq \
    zoxide

# Podman
dnf -y install \
    podman-compose \
    podman-tui \
    podmansh

# Local AI
dnf -y install \
    ollama \
    ramalama \
    whisper-cpp

# ax-shell Python deps
dnf -y install \
    python3-gobject \
    python3-ijson \
    python3-numpy \
    python3-pillow \
    python3-psutil \
    python3-pywayland \
    python3-ramalama \
    python3-requests \
    python3-setproctitle \
    python3-toml \
    python3-watchdog \
    tesseract

# Benchmarking
dnf -y install radeontop

# Clone dotfiles into image for offline chezmoi apply
git clone https://github.com/mecattaf/dotfiles.git /usr/share/harness/dotfiles

# Run font pipeline
bash /ctx/build_files/fonts/install-fonts.sh

# Remove docs that break layer
rm -rf /usr/share/doc/niri
rm -rf /usr/share/doc/just
