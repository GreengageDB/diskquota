#!/usr/bin/env bash

source /home/gpadmin/gpdb_src/concourse/scripts/common.bash
install_and_configure_gpdb
/home/gpadmin/gpdb_src/concourse/scripts/setup_gpadmin_user.bash
make_cluster
mkdir -p /logs
chown gpadmin:gpadmin /logs
