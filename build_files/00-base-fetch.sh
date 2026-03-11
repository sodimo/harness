#!/bin/bash

set -xeuo pipefail

dnf -y install 'dnf5-command(config-manager)'

dnf config-manager setopt keepcache=1
trap 'dnf config-manager setopt keepcache=0' EXIT

# Install custom repo files before installing packages from them
cp /ctx/system_files/etc/yum.repos.d/tailscale.repo /etc/yum.repos.d/
cp /ctx/system_files/etc/yum.repos.d/antigravity.repo /etc/yum.repos.d/
cp /ctx/system_files/etc/yum.repos.d/google-cloud-cli.repo /etc/yum.repos.d/

# Networking
dnf -y install \
  -x PackageKit* \
  NetworkManager \
  NetworkManager-adsl \
  NetworkManager-bluetooth \
  NetworkManager-config-connectivity-fedora \
  NetworkManager-libnm \
  NetworkManager-openconnect \
  NetworkManager-openvpn \
  NetworkManager-strongswan \
  NetworkManager-ssh \
  NetworkManager-ssh-selinux \
  NetworkManager-tui \
  NetworkManager-vpnc \
  NetworkManager-wifi \
  NetworkManager-wwan \
  mobile-broadband-provider-info \
  openconnect \
  tailscale \
  vpnc \
  whois \
  wireguard-tools

# Networking extras
dnf -y install \
  caddy \
  cockpit \
  cockpit-machines \
  cockpit-networkmanager \
  cockpit-podman \
  cockpit-selinux \
  cockpit-storaged \
  cockpit-system \
  pcp-zeroconf \
  systemd-resolved

# Firmware
dnf -y install \
  alsa-firmware \
  alsa-tools-firmware \
  atheros-firmware \
  brcmfmac-firmware \
  intel-audio-firmware \
  iwlegacy-firmware \
  iwlwifi-dvm-firmware \
  iwlwifi-mvm-firmware \
  kernel-modules-extra \
  mt7xxx-firmware \
  nxpwireless-firmware \
  realtek-firmware \
  tiwilink-firmware

# Media hardware
dnf -y install \
  alsa-sof-firmware \
  bluez \
  bluez-tools \
  gvfs \
  gvfs-mtp \
  pamixer \
  pipewire \
  pipewire-alsa \
  pipewire-jack-audio-connection-kit \
  pipewire-pulseaudio \
  wireplumber

# Camera
dnf -y install \
  libcamera \
  libcamera-gstreamer \
  libcamera-tools \
  libcamera-v4l2

# Printing
dnf -y install \
  cups \
  cups-pk-helper \
  dymo-cups-drivers \
  hplip \
  printer-driver-brlaser \
  ptouch-driver \
  system-config-printer-libs \
  system-config-printer-udev

# Filesystem / iOS
dnf -y install \
  cifs-utils \
  fuse \
  fuse-common \
  gvfs-archive \
  gvfs-nfs \
  gvfs-smb \
  ifuse \
  jmtpfs \
  libimobiledevice \
  libimobiledevice-utils

# Virtualization
dnf -y install \
  hyperv-daemons \
  open-vm-tools \
  open-vm-tools-desktop \
  qemu-guest-agent \
  spice-vdagent \
  systemd-container

# Security
dnf -y install \
  audispd-plugins \
  audit \
  firewalld \
  fprintd \
  fprintd-pam \
  gnome-keyring-pam \
  gnupg2-scdaemon \
  openssh-askpass \
  pam_yubico \
  pcsc-lite \
  ykman

# GPU
dnf -y install \
  linux-firmware \
  mesa-dri-drivers \
  mesa-libGLU \
  mesa-vulkan-drivers \
  vulkan-tools \
  vulkan-validation-layers

# System core
dnf -y install \
  acpi \
  age \
  antigravity \
  aria2 \
  bolt \
  flatpak \
  fpaste \
  fzf \
  gcr \
  git-core \
  gum \
  just \
  khal \
  libratbag-ratbagd \
  man-pages \
  plymouth \
  plymouth-system-theme \
  rsync \
  steam-devices \
  switcheroo-control \
  systemd-oomd-defaults \
  tuned \
  tuned-ppd \
  tuned-switcher \
  tuned-utils \
  usb_modeswitch \
  uxplay \
  zram-generator-defaults

# System extras
dnf -y install \
  sox \
  unrar-free \
  wmctrl \
  ydotool \
  yt-dlp

# Google Cloud CLI
dnf -y install \
  google-cloud-cli \
  libxcrypt-compat
