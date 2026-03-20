#!/bin/bash

set -xeuo pipefail

# COPR: ublue-os/packages (uupd)
dnf -y copr enable ublue-os/packages
dnf -y copr disable ublue-os/packages
dnf -y --enablerepo copr:copr.fedorainfracloud.org:ublue-os:packages install uupd

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

# COPR: mecattaf/harnessRPM
dnf -y copr enable mecattaf/harnessRPM
dnf -y copr disable mecattaf/harnessRPM
dnf -y --enablerepo copr:copr.fedorainfracloud.org:mecattaf:harnessRPM install \
    asr-rs \
    atuin \
    bibata-cursor-themes \
    cliamp \
    cliphist \
    eza \
    gws \
    kitty \
    lisgd \
    mactahoe-oled \
    nwg-look \
    pi \
    quickshellX-git \
    shpool \
    starship \
    wl-gammarelay-rs

# COPR: monkeygold/nautilus-open-any-terminal
dnf -y copr enable monkeygold/nautilus-open-any-terminal
dnf -y copr disable monkeygold/nautilus-open-any-terminal
dnf -y --enablerepo copr:copr.fedorainfracloud.org:monkeygold:nautilus-open-any-terminal install \
    nautilus-open-any-terminal
