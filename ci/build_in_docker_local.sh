#!/bin/bash
# FILE:    ci/build_in_docker_local.sh
# CONTEXT: Build diskquota and package it as a .deb in container
# PURPOSE: Convenience wrapper for local development. Runs
#          ci/build_in_docker.sh in a selected Greengage developer image.
#
# USAGE:   ci/build_in_docker_local.sh [GREENGAGE_VERSION] [UBUNTU_VERSION]
# EXAMPLE: ci/build_in_docker_local.sh 6 24.04

set -euo pipefail

gp_version=${1:-6}
target_os_version=${2:-22.04}

if [[ "$target_os_version" == "22.04" ]]; then
    os_image=ubuntu
else
    os_image="ubuntu${target_os_version}"
fi

image="ghcr.io/greengagedb/greengage/ggdb${gp_version}_${os_image}:latest"
SRC=/diskquota/src

echo "Building diskquota for Greengage ${gp_version} on Ubuntu ${target_os_version}"

docker run --rm -it \
    -v "./:$SRC" -w "$SRC" \
    "$image" ci/build_in_docker.sh
