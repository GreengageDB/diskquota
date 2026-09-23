# CI Workflows

## Check ([check.yml](check.yml))

Builds and runs the regression/isolation2 test suite against `ggdb6` and
`ggdb7` directly in the GPDB container image (no Docker build step).

## Build and Package DEB ([build_and_package.yml](build_and_package.yml))

Builds `diskquota` and packages it as a `.deb`/`.ddeb`.

### What it does

1. **Build in Docker** — runs `ci/build_in_docker.sh` inside the matching
   Greengage developer image
   (`ghcr.io/greengagedb/greengage/ggdb<version>_<os>`, see
   [ci/build_in_docker.sh](../../ci/build_in_docker.sh)), which already
   provides the build toolchain. The script installs the matching Greengage
   runtime package via apt, builds the extension against it, and packages
   it with `make -f package.mk pkg` (see [package.mk](../../package.mk)).
   The output directory is set via `DEB_PACKAGES`, which is also the
   artifact name — no post-build rename step.
2. **Upload artifacts** — uploads the contents of the `DEB_PACKAGES`
   directory as a GitHub Actions artifact.
3. **Test install** — installs the package into a clean `<os>:<version>`
   image via the shared
   [`tests/install/deb`](https://github.com/greengagedb/greengage-ci) action
   and verifies it with `dpkg -l greengage<gp_version>-diskquota`.

### Matrix

The set of supported `gp_version` / `target_os_version` combinations is
defined by the `strategy.matrix` block in the workflow. Each entry
produces one artifact named
`deb-packages-greengage<gp_version>-diskquota-<target_os><target_os_version>`.

Example artifact names for the current matrix:

| Name |
| ---- |
| `deb-packages-greengage6-diskquota-ubuntu22.04` |
| `deb-packages-greengage6-diskquota-ubuntu24.04` |
| `deb-packages-greengage7-diskquota-ubuntu22.04` |

### Triggers

| Event | Ref |
| ----- | --- |
| `push` | branches: `main`; tags: any |
| `pull_request` | all branches |

A `concurrency` group keyed on the workflow + PR number (or ref) cancels
in-progress runs when a new commit arrives.

## GreengageDB diskquota Release ([release.yml](release.yml))

Uploads previously built `.deb`/`.ddeb` packages to a GitHub Release.

### What it does

For each matrix entry (`target_os` / `target_os_version` / `gp_version`),
invokes the shared
[`upload-pkgs-to-release`](https://github.com/greengagedb/greengage-ci)
action. The action locates the artifact produced by
`build_and_package.yml` for that combination and attaches it to the
release.

### Matrix

Mirrors the `build_and_package.yml` matrix: each entry lists the
extensions to upload (`deb`, `ddeb`).

### Triggers

| Event | Condition |
| ----- | --------- |
| `release` | `types: [released]` |
