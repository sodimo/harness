#!/usr/bin/env bash
# tests/verify-systemd-units.sh — run `systemd-analyze verify` on every
# systemd unit shipped by the harness image tree.
#
# Exit code: 0 if every unit verifies; non-zero otherwise.
# Usage:    bash tests/verify-systemd-units.sh
#
# Cross-ref: sodimo/harness#7 (sodimo-system.target), #8 (sysctl),
#            #10 (chezmoi unit removals). Part of the night-session
#            2026-04-22 verification pass.

set -u

cd "$(dirname "$0")/.."

fail=0
found=0

for unit in \
    mkosi.extra/usr/lib/systemd/system/*.service \
    mkosi.extra/usr/lib/systemd/system/*.target \
    mkosi.extra/usr/lib/systemd/system/*.mount \
    mkosi.extra/usr/lib/systemd/system/*.automount \
    mkosi.extra/usr/lib/systemd/system/*.socket \
    mkosi.extra/usr/lib/systemd/system/*.timer \
    mkosi.extra/usr/lib/systemd/user/*.service \
    mkosi.extra/usr/lib/systemd/user/*.timer ; do
    [ -f "$unit" ] || continue
    found=$((found + 1))
    if out=$(systemd-analyze verify "$unit" 2>&1); then
        echo "OK: $unit"
    else
        echo "FAIL: $unit"
        echo "$out" | sed 's/^/    /'
        fail=$((fail + 1))
    fi
done

echo
echo "Checked $found unit file(s); $fail failure(s)."
exit "$fail"
