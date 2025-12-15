#!/usr/bin/env bash

source gpdb_src/concourse/scripts/common.bash
# this command unpack binaries to `/usr/local/greengage-db-devel/`
install_and_configure_gpdb
gpdb_src/concourse/scripts/setup_gpadmin_user.bash
make_cluster

mkdir -p /logs
chown gpadmin:gpadmin /logs

su - gpadmin -c '
set -x
shopt -s extglob nullglob

source /usr/local/greengage-db-devel/greengage_path.sh;
source gpdb_src/gpAux/gpdemo/gpdemo-env.sh;

pushd /home/gpadmin/gpdb_src
  make -C src/test/isolation2 install
popd

# build and install
cd /home/gpadmin/diskquota
mkdir build && cd build
cmake ..
cmake --build .
make install

export SHOW_REGRESS_DIFF=1
# test with standby
cmake --build . --target installcheck
errors=$?

pushd /home/gpadmin
tar -czf "/logs/pg_log_standby.tar.gz" \
  gpdb_src/gpAux/gpdemo/datadirs/standby/@(log|pg_log)
popd

cp tests/regress/regression.diffs /logs/regression_regress_with_standby.diffs
cp tests/isolation2/regression.diffs /logs/regression_isolation_with_standby.diffs

if ! gpinitstandby -ar; then
  echo "failed to disable standby"
  exit 1
fi

# test without standby
cmake --build . --target installcheck
errors=$(( errors + $? ))

cp tests/regress/regression.diffs /logs/regression_regress_without_standby.diffs
cp tests/isolation2/regression.diffs /logs/regression_isolation_without_standby.diffs

cd /home/gpadmin
tar -czf "/logs/gpAdminLogs.tar.gz" gpAdminLogs
tar -czf "/logs/gpAux.tar.gz" gpdb_src/gpAux/gpdemo/datadirs/gpAdminLogs/
tar -czf "/logs/pg_log.tar.gz" \
  gpdb_src/gpAux/gpdemo/datadirs/qddir/demoDataDir-1/@(log|pg_log)  \
  gpdb_src/gpAux/gpdemo/datadirs/dbfast1/demoDataDir0/@(log|pg_log) \
  gpdb_src/gpAux/gpdemo/datadirs/dbfast2/demoDataDir1/@(log|pg_log) \
  gpdb_src/gpAux/gpdemo/datadirs/dbfast3/demoDataDir2/@(log|pg_log) \
  gpdb_src/gpAux/gpdemo/datadirs/dbfast_mirror1/demoDataDir0/@(log|pg_log) \
  gpdb_src/gpAux/gpdemo/datadirs/dbfast_mirror2/demoDataDir1/@(log|pg_log) \
  gpdb_src/gpAux/gpdemo/datadirs/dbfast_mirror3/demoDataDir2/@(log|pg_log)
#regression.diffs may not exist if tests were successful
tar -czf "/logs/results.tar.gz" \
  diskquota/tests/regress/results \
  diskquota/tests/isolation2/results

exit $errors
'
