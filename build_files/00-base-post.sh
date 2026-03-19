#!/bin/bash

set -xeuo pipefail

cp -avf "/ctx/system_files"/. /
mkdir -p /mnt/nas
chmod 600 /etc/NetworkManager/system-connections/router-link.nmconnection

sed -i 's|^ExecStart=.*|ExecStart=/usr/bin/bootc update --quiet|' /usr/lib/systemd/system/bootc-fetch-apply-updates.service
sed -i 's|^OnUnitInactiveSec=.*|OnUnitInactiveSec=7d\nPersistent=true|' /usr/lib/systemd/system/bootc-fetch-apply-updates.timer
sed -i 's|#AutomaticUpdatePolicy.*|AutomaticUpdatePolicy=stage|' /etc/rpm-ostreed.conf
sed -i 's|#LockLayering.*|LockLayering=true|' /etc/rpm-ostreed.conf

# Enable system services from preset
systemctl preset auditd.service
systemctl preset bootc-fetch-apply-updates.timer
systemctl preset brew-setup.service
systemctl preset cockpit.socket
systemctl preset enable-linger.service
systemctl preset firewalld.service
systemctl preset systemd-resolved.service
systemctl preset systemd-timesyncd.service
systemctl preset mnt-nas.automount
