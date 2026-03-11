Here's the condensed reference:

---

**Device:** Apple Magic Trackpad 2 (Lightning), Product ID `0x0265`
**Vendor IDs:** `0x004C` (Bluetooth), `0x05AC` (USB)

**Fix:** Create `/etc/libinput/local-overrides.quirks`

```ini
[Apple Magic Trackpad 2 (Bluetooth)]
MatchBus=bluetooth
MatchVendor=0x004C
MatchProduct=0x0265
AttrTouchSizeRange=20:10
AttrPressureRange=3:0
AttrPalmSizeThreshold=900
AttrThumbSizeThreshold=700

[Apple Magic Trackpad 2 (USB)]
MatchBus=usb
MatchVendor=0x05AC
MatchProduct=0x0265
AttrTouchSizeRange=20:10
AttrPressureRange=3:0
AttrPalmSizeThreshold=900
AttrThumbSizeThreshold=700
```

**What it does:** Upstream `50-system-apple.quirks` has entries for this device but omits `AttrPressureRange`. Without it, libinput falls back to default pressure guessing (~30), misclassifies touches, and multi-finger gestures (including two-finger swipe back/forward in Chrome) fail silently. `AttrPressureRange=3:0` and `AttrTouchSizeRange=20:10` together give libinput correct touch/pressure data so it can distinguish individual fingers reliably.

**What it enables:** Palm rejection, thumb detection, and correct multi-touch gesture recognition — including two-finger horizontal swipe (browser back/forward in Chrome Flatpak), which already works on built-in laptop trackpads that ship with complete quirks.

**Path:** `/etc/libinput` (writable overlay on Fedora immutable, persists across rpm-ostree rebases). File permissions `644`. Requires reboot.

**Verify:** `sudo libinput quirks list /dev/input/eventXX` — should show all attrs. `sudo libinput list-devices | grep -A5 "Magic"` — must show as touchpad, not pointer.
