# Zirconium CI/Workflow Deltas for sodimo/harness

## Summary

Upstream zirconium restructured from a monolithic build workflow into a reusable `reusable-build-bootc.yaml` called by thin per-variant trigger files. Our `build.yml` is still a flat single-job workflow derived from an earlier fork point. Several correctness fixes landed in zirconium after our fork diverged: `set -e` discipline in build steps (commit `1e1c6d6`), env-var passing to `just` via `sudo env` rather than GitHub env context (same commit), mkosi config rendering before the build for debugging (`5f61f2e`), and caching gated to non-PR runs to prevent cache poisoning (`9a148ea`). The submodule warning in our last run (#24710754732) is caused by a ghost submodule entry in `subprojects/dotfiles`; upstream avoids this by keeping only clean, registered submodules with `submodules: true` in the checkout action rather than our two-step manual `git submodule update --init --depth=1`.

---

## P0 — CI-breaking / security (apply before next build)

### P0-1: Cache poisoning — mkosi cache is restored on PR runs

**What zirconium does** (`reusable-build-bootc.yaml` lines 119–128):
```yaml
- name: Setup image cache
  uses: actions/cache@668228422ae6a00e4ad889ee87cd7109ec5666a7
  if: inputs.publish          # ← only when publishing (non-PR)
  with:
    path: mkosi.cache
    key: ${{ runner.os }}-mkosi-${{ env.IMAGE_NAME }}-${{ matrix.platform }}
```
The `if: inputs.publish` condition means PRs never read or write the shared cache.

**What we do** (`build.yml` lines 56–62):
```yaml
- name: Setup mkosi cache
  uses: actions/cache@668228422ae6a00e4ad889ee87cd7109ec5666a7
  with:              # ← no if: condition, always active including PRs
    path: mkosi.cache
    key: ${{ runner.os }}-mkosi-${{ env.IMAGE_NAME }}-amd64
```

**Recommended action:** Add `if: github.event_name != 'pull_request'` to the cache step in `build.yml`.

**Rationale:** A PR from a fork or a branch with a malicious package could poison the shared `mkosi.cache` and affect subsequent main-branch builds. Commit `9a148ea` in zirconium fixed exactly this. Low effort, high security value.

---

### P0-2: `sudo just` drops GitHub env vars — `IMAGE_FULL` never reaches just

**What zirconium does** (commit `1e1c6d6`, `reusable-build-bootc.yaml` lines 155–169):
```yaml
- name: Load image
  run: |
    set -e
    sudo env IMAGE_FULL="localhost/${IMAGE_NAME}:${DEFAULT_TAG}" "$(which just)" load

- name: Lint image
  run: |
    set -e
    sudo env IMAGE_FULL="localhost/${IMAGE_NAME}:${DEFAULT_TAG}" "$(which just)" lint
```
`sudo env VAR=val` explicitly threads the variable through the privilege boundary.

**What we do** (`build.yml` lines 77–82):
```yaml
- name: Load image
  run: |
    sudo env IMAGE_FULL="localhost/${IMAGE_NAME}:${DEFAULT_TAG}" $(which just) load

- name: Lint image
  run: |
    sudo env IMAGE_FULL="localhost/${IMAGE_NAME}:${DEFAULT_TAG}" $(which just) lint
```
The load and lint steps are already correct in our file (we do pass `IMAGE_FULL` via `sudo env`). However, the **Build image** step at line 73 does not:

```yaml
- name: Build image
  run: |
    sudo env IMAGE_FULL="localhost/${IMAGE_NAME}:${DEFAULT_TAG}" mkosi -B -ff
```

The build step is fine, but it also omits `set -e` and the `--debug --profile=bootc-ostree` flags present in upstream. See P1-1.

**Recommended action:** No change needed for load/lint. Verify build step has `set -e` (it does not — fix under P1-1).

---

## P1 — Correctness (apply soon)

### P1-1: Build step missing `set -e`, `--debug`, and explicit profile

**What zirconium does** (`reusable-build-bootc.yaml` lines 141–153):
```yaml
- name: Build image
  env:
    CI_MKOSI_PROFILES: ${{ inputs.profiles }}
    CI_MKOSI_RELEASE: ${{ inputs.release }}
    IMAGE_FULL: localhost/${{ env.IMAGE_NAME }}:${{ env.DEFAULT_TAG }}
  run: |
    set -e
    RELEASE_ARGUMENTS=()
    if [ "$CI_MKOSI_RELEASE" != "" ] ; then
      RELEASE_ARGUMENTS+=("--release=$CI_MKOSI_RELEASE")
    fi
    sudo mkosi -B -ff --debug --profile=bootc-ostree,${CI_MKOSI_PROFILES} ${PROFILE_ARGUMENTS} ${RELEASE_ARGUMENTS}
```

**What we do** (`build.yml` line 73–74):
```yaml
- name: Build image
  run: |
    sudo env IMAGE_FULL="localhost/${IMAGE_NAME}:${DEFAULT_TAG}" mkosi -B -ff
```

Three gaps:
1. No `set -e` — a non-zero exit from a subcommand won't abort the step.
2. No `--debug` — mkosi debug output is lost; makes failures like the Terra44 metalink mismatch harder to diagnose.
3. No explicit `--profile=bootc-ostree` — relies on default profile selection, which may behave differently.

**Recommended action:** Add `set -e`, `--debug`, and `--profile=bootc-ostree` to the build step.

---

### P1-2: `mkosi cat-config --debug` render step absent

**What zirconium does** (`reusable-build-bootc.yaml` line 138–139, commit `5f61f2e`):
```yaml
- name: Render configuration (for debugging)
  run: mkosi cat-config --debug
```
This runs before the build and dumps the resolved mkosi config into the log. When the Terra44 metalink checksum mismatch happened, this step would have revealed the exact repo URLs and checksums mkosi resolved.

**What we do:** No equivalent step.

**Recommended action:** Add a `mkosi cat-config --debug` step between "Install mkosi" and "Build image" in `build.yml`. One-liner, zero risk, immediately actionable for diagnosing the next flake.

---

### P1-3: Submodule checkout — ghost submodule causes post-job warning

**What zirconium does** (`reusable-build-bootc.yaml` line 103–106):
```yaml
- name: Checkout
  uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd
  with:
    submodules: true
```
Upstream's `.gitmodules` has three clean entries: `assets`, `mkosi.extra/usr/share/zirconium/zdots`, and `subprojects/ublue-brew`. All are registered and resolvable.

**What we do** (`build.yml` lines 47–51):
```yaml
- name: Checkout
  uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd
  # no submodules: true

- name: Init submodules (non-recursive)
  run: git submodule update --init --depth=1
```
Our `.gitmodules` has three entries: `subprojects/ublue-brew`, `subprojects/bluefin-common`, and `subprojects/dotfiles`. The dotfiles submodule (`subprojects/dotfiles`) contains a nested submodule at `plugins/.repos/0026f1eba8dedaec` that is not listed in `.gitmodules` — this is the ghost path causing:

```
fatal: No url found for submodule path 'subprojects/dotfiles/dmsFULLlatest/plugins/.repos/0026f1eba8dedaec' in .gitmodules
```

The post-job git cleanup iterates all submodule paths it finds in the working tree and fails when it encounters one with no registered URL.

**Recommended action (two parts):**
1. In `subprojects/dotfiles`, ensure `.gitmodules` inside that repo registers all nested submodule paths, or remove the orphaned `.git` directory at `plugins/.repos/0026f1eba8dedaec`.
2. Switch checkout to `submodules: true` and drop the manual `git submodule update` step, matching upstream's approach. The `--depth=1` flag on `git submodule update` is fine to keep if you want shallow clones — pass it via the checkout action's `fetch-depth` or keep the two-step form but fix the ghost entry first.

---

### P1-4: `ublue-os/legacy-rechunk` action vs. upstream's native `just ostree-rechunk`

**What zirconium does** (`reusable-build-bootc.yaml` lines 162–165):
```yaml
- name: Rechunk image
  run: |
    set -e
    sudo env IMAGE_FULL="localhost/${IMAGE_NAME}:${DEFAULT_TAG}" "$(which just)" ostree-rechunk
```
Upstream calls rechunk through `just`, keeping the logic in the Justfile.

**What we do** (`build.yml` lines 94–108):
```yaml
- name: Run Rechunker
  id: rechunk
  uses: ublue-os/legacy-rechunk@a925083d9af7cb04b3e2a6e8c01bfa495f38b710
  with:
    rechunk: 'ghcr.io/ublue-os/legacy-rechunk:v1.0.0-x86_64'
    ref: "localhost/${{ env.IMAGE_NAME }}:${{ env.DEFAULT_TAG }}"
    prev-ref: "${{ env.IMAGE_REGISTRY }}/${{ env.IMAGE_NAME }}:${{ env.DEFAULT_TAG }}"
    ...
```

We rely on the `ublue-os/legacy-rechunk` action (pinned at `a925083`). Upstream moved away from this to direct `just` invocation. The action is marked **legacy** in its own name. Additionally, our push step (`build.yml` line 128–132) pipes through `skopeo copy` from the rechunk output ref rather than using podman push directly — this works but differs from upstream's podman+retry loop.

**Recommended action:** This is a medium-effort change. The `legacy-rechunk` action still works and is pinned — not blocking. Align when the Justfile's `ostree-rechunk` target is confirmed equivalent. Mark for next maintenance window.

---

## P2 — Quality of life (apply when convenient)

### P2-1: Brew-based podman install for annotation support

**What zirconium does** (`reusable-build-bootc.yaml` lines 189–192, 206–213):
```yaml
- name: Install Podman from Brew
  if: inputs.publish && steps.brew-cache.outputs.cache-hit != 'true'
  run: /home/linuxbrew/.linuxbrew/bin/brew install podman

- name: Push to GHCR
  ...
  run: sudo /home/linuxbrew/.linuxbrew/bin/podman push ...
```
The Brew podman is used specifically to carry layer annotations (a workaround for https://github.com/containers/podman/issues/27796 not being fixed in Ubuntu 26.04 runners yet). There is also a Brew cache step keyed by platform.

**What we do:** We use `skopeo copy` for push, bypassing this issue entirely. Not a problem for us today, but if we ever switch to direct podman push we'll need this pattern.

**Recommended action:** No action required now. If rechunk push is ever migrated to podman, adopt the brew-cached podman approach.

---

### P2-2: Scheduled build cadence — daily vs. weekly

**What zirconium does** (`build-standard.yaml` line 14):
```yaml
schedule:
  - cron: "0 1 * * TUE"   # weekly, Tuesdays at 01:00 UTC
```

**What we do** (`build.yml` line 11):
```yaml
schedule:
  - cron: "05 10 * * *"   # daily at 10:05 UTC
```

Daily builds consume more runner minutes and generate more GHCR tags. For a harness image that changes infrequently, weekly is sufficient.

**Recommended action:** Switch to weekly cron when runner usage is a concern. No functional impact.

---

### P2-3: `merge_group` trigger missing

**What zirconium does** (all three trigger workflows, e.g. `build-standard.yaml` line 15):
```yaml
on:
  push:
  pull_request:
    branches: [main]
  merge_group:
  workflow_dispatch:
```

**What we do** (`build.yml` lines 3–16): No `merge_group` trigger.

**Recommended action:** Add `merge_group:` to the `on:` block if merge queues are enabled on the repo. Harmless to add even if not currently used.

---

### P2-4: `setup-just` action pinned to older version

**What zirconium does** (`reusable-build-bootc.yaml` line 109):
```yaml
uses: extractions/setup-just@53165ef7e734c5c07cb06b3c8e7b647c5aa16db3 # v4
```

**What we do** (`build.yml` line 54):
```yaml
uses: extractions/setup-just@f8a3cce218d9f83db3a2ecd90e41ac3de6cdfd9b # v3
```

We are on v3; upstream is on v4.

**Recommended action:** Bump to the upstream pin when convenient.

---

## P3 — Cosmetic / skip

- **Multi-variant matrix** (`build-nvidia.yaml`, `build-rawhide.yaml`): Zirconium's reusable pattern supports nvidia and rawhide variants via `profiles:` and `release:` inputs. We only need `latest`. No action.
- **S3 ISO upload** (`build-disk.yml`): Upstream uploads branded ISOs to S3. Our `build-iso.yml` uploads to GitHub artifacts. Relevant only if we set up external ISO hosting.
- **`cleanup_action` input / `ublue-os/remove-unwanted-software`**: Zirconium's reusable workflow has an optional `cleanup_action` input (default `false`). We call `remove-unwanted-software` unconditionally in `build.yml` line 38. No correctness delta — just a structural difference.
- **ArtifactHub OCI labels in manifest**: Zirconium's `manifest` job applies full ArtifactHub metadata labels. Our rechunk action applies a minimal label set. Only matters for ArtifactHub listing.

---

## Notes on upstream structure worth keeping in mind

**Reusable workflow pattern:** `reusable-build-bootc.yaml` is the single source of truth for build logic. Each variant (`build-standard`, `build-nvidia`, `build-rawhide`) is a 31-line file that only specifies `image-name`, `profiles`, `default-tag`, and the `publish`/`rechunk` guards. If we ever add a second harness variant (e.g. a `-nvidia` profile for the second Framework), adopting this split would pay off immediately.

**`publish` guard pattern:** Zirconium gates rechunk, cache writes, registry login, push, and signing behind a single `inputs.publish` boolean that evaluates to `false` on PRs. This is cleaner than repeating `github.event_name != 'pull_request' && github.ref == ...` on every step (which is what our `build.yml` does at lines 113, 123, 137, 140). When we adopt P0-1, consider also consolidating the per-step conditions into a job-level output or a `if: inputs.publish` pattern.

**Cosign pinning:** Upstream uses `sigstore/cosign-installer@cad07c2e89fa2edd6e2d7bab4c1aa38e53f76003 # v4.1.1`; we use `ba7bc0a3fef59531c69a25acd34668d6d3fe6f22 # v4.1.0`. Minor version behind — update when convenient (P3).
