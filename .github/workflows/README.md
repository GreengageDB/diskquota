# CI Workflows

## check.yml

Builds and runs the regression/isolation2 test suite against `ggdb6` and
`ggdb7` directly in the GPDB container image (no Docker build step).

## build_and_package.yml

Builds `diskquota` and packages it as a `.deb`/`.ddeb`.

### What it does

1. **Build in Docker** — runs `ci/build_in_docker.sh` inside the matching
   Greengage developer image
   (`ghcr.io/greengagedb/greengage/ggdb<version>_<os>`, see
   [ci/build_in_docker.sh](../../ci/build_in_docker.sh)), which already
   provides the build toolchain. The script installs the matching Greengage
   runtime package via apt, builds the extension against it, and packages
   it with `make -f package.mk pkg` (see [package.mk](../../package.mk))
2. **Rename artifacts** — moves the resulting `Package/` directory to
   `deb-packages-greengage<gp_version>-diskquota-<os><version>`
3. **Upload artifacts** — uploads `.deb`/`.ddeb` as a GitHub Actions artifact
4. **Test install** — installs the package into a clean `<os>:<version>`
   image via the shared
   [`tests/install/deb`](https://github.com/greengagedb/greengage-ci) action
   and verifies it with `dpkg -l greengage<gp_version>-diskquota`

### GP versions built

`gp_version: 6` (Ubuntu 22.04, 24.04) and `gp_version: 7` (Ubuntu 22.04).

### Artifacts

| Name | Contents |
| ---- | -------- |
| `deb-packages-greengage6-diskquota-ubuntu22.04` | `.deb`/`.ddeb` for GP6 / Ubuntu 22.04 |
| `deb-packages-greengage6-diskquota-ubuntu24.04` | `.deb`/`.ddeb` for GP6 / Ubuntu 24.04 |
| `deb-packages-greengage7-diskquota-ubuntu22.04` | `.deb`/`.ddeb` for GP7 / Ubuntu 22.04 |

### Triggers

| Event | Branches / refs |
| ----- | --------------- |
| `push` | `master`, tags |
| `pull_request` | all branches |

## greengage-release.yml

Uploads previously built `.deb`/`.ddeb` packages to a GitHub Release.

### What it does

Waits for `build_and_package.yml` to finish for the matching
`target_os` / `target_os_version` / `gp_version`, then attaches its
artifacts (`deb`, `ddeb`) to the release via the shared
[`upload-pkgs-to-release`](https://github.com/greengagedb/greengage-ci)
action.

### Triggers

| Event | Condition |
| ----- | --------- |
| `release` | `types: [released]` |
