# First things to do on new device setup

```
        sign in with google chrome
        signin with gh
        signin with tailscale
        signin with cloudflare
        curl -fsSL https://claude.ai/install.sh | bash
```
possibly use flatpak manager to enable from the start


Then setting up the whisperlivekit:
```
  # should be already done automatically
  # loginctl enable-linger $USER
  systemctl --user daemon-reload
  systemctl --user enable --now asr-toolbox


```



Below find instructions for navidrome and immich quadlets

  # Reload so systemd picks up the new quadlet files
  systemctl --user daemon-reload

  # Navidrome
  systemctl --user start navidrome

  # Immich (starting immich-server pulls in postgres, redis, network automatically; ml
  is a soft dep)
  systemctl --user start immich-server

  # Optional: enable so they start on login
  systemctl --user enable navidrome
  systemctl --user enable immich-server

  Before first start, change DB_PASSWORD=changeme to a real password in both
  immich-postgres.container and immich-server.container (they must match).

  You can check status with:
  systemctl --user status navidrome
  systemctl --user status immich-server immich-postgres immich-redis immich-ml

  And the web UIs will be at:
  - Navidrome: http://localhost:4533
  - Immich: http://localhost:2283

