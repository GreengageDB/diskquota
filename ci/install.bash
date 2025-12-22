#!/usr/bin/env bash
set -xeo pipefail

source gpdb_src/concourse/scripts/common.bash
install_and_configure_gpdb
gpdb_src/concourse/scripts/setup_gpadmin_user.bash
make_cluster

source /usr/local/greengage-db-devel/greengage_path.sh
source /home/gpadmin/gpdb_src/gpAux/gpdemo/gpdemo-env.sh

pushd /home/gpadmin/gpdb_src
  make -C src/test/isolation2 install
popd

pushd "$(dirname "$0")/.."
  git config --global --add safe.directory $(pwd)
  mkdir build
  pushd build
    cmake ..
    cmake --build .
    make install
  popd
  chown -R gpadmin:gpadmin . /usr/local/greengage-db-devel
popd

mkdir -p /logs
chown gpadmin:gpadmin /logs
