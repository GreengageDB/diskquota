# CI Workflows

## check.yml

Builds and runs the regression/isolation2 test suite against `ggdb6` and
`ggdb7` directly in the GPDB container image (no Docker build step).

## build_and_package.yml

Builds `diskquota` and packages it as a `.deb`.

### What it does

1. **Build Docker image** — builds `ci/Dockerfile.ubuntu` with
   `--build-arg GP_MAJORVERSION=<version>`. Inside the image, Greengage is
   installed from the `greengagedb.org` apt repository (same source
   `pxf/ci/build_in_docker.sh` uses), then the extension is compiled against
   it and packaged via `cmake --build . --target package_deb` (CPack DEB
   generator, see [CMakeLists.txt](../../CMakeLists.txt))
2. **Extract artifacts** — copies `Package/` out of the built image
3. **Upload artifacts** — uploads the `.deb` as a GitHub Actions artifact

### GP versions built

Only `gp_version: 6` right now — the `greengagedb.org` apt repo doesn't
publish a `greengage7` package for Ubuntu 22.04/24.04 yet. Once it does, add
`7` back to the matrix; `ci/Dockerfile.ubuntu` and `CMakeLists.txt` already
support it.

### Artifacts

| Name                    | Contents                          |
| ------------------------ | ---------------------------------- |
| `diskquota-deb-gp6`      | `diskquota6_<version>_<arch>.deb`  |

### Triggers

| Event          | Branches / refs      |
| -------------- | --------------------- |
| `push`         | `master`, tags        |
| `pull_request` | all branches          |
