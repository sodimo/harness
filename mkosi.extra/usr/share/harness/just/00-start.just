toggle-autorotation:
    systemctl --user toggle iio-niri.service

toggle-fcitx5:
    systemctl --user toggle fcitx5.service

preinstalled-flatpaks:
    flatpak-manager apply
