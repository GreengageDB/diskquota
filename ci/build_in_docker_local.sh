#!/bin/bash
# FILE:    ci/build_in_docker_local.sh
# CONTEXT: Build diskquota and package it as a .deb in container
# PURPOSE: Convenience wrapper for local development. Pulls the latest
#          Greengage developer image and runs ci/build_in_docker.sh inside it
#          with the current source tree bind-mounted, so a developer can
#          build a .deb without installing the Greengage build toolchain on
#          the host. Passes the caller's UID/GID through so
#          build_in_docker.sh can chown the bind-mounted sources back to the
#          host user after the build.

set -euo pipefail

export GP_MAJORVERSION=${GP_MAJORVERSION:-6}
export PG_HOME=/opt/greengagedb/greengage${GP_MAJORVERSION}
export GGDB_IMAGE=ghcr.io/greengagedb/greengage/ggdb${GP_MAJORVERSION}_ubuntu:latest
export SRC=/home/gpadmin/diskquota

# shellcheck disable=SC2046 # id -u / id -g output is a single numeric token
docker run --rm -it \
    -v "./:$SRC" -w "$SRC" \
    -e SRC \
    -e PG_HOME \
    -e GP_MAJORVERSION \
    -e HOST_UID=$(id -u) -e HOST_GID=$(id -g) \
    "$GGDB_IMAGE" ci/build_in_docker.sh
