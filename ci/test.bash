#!/usr/bin/env bash

set -xeu

source /usr/local/greengage-db-devel/greengage_path.sh
source /home/gpadmin/gpdb_src/gpAux/gpdemo/gpdemo-env.sh

cd build

export SHOW_REGRESS_DIFF=1
errors=0

cmake --build . --target installcheck || errors=$(( errors + $? ))

tar --dereference -czf "/logs/result.tar.gz" \
  "tests/regress/results" \
  "tests/isolation2/results"

cp tests/regress/regression.diffs /logs/regression_regress.diffs || true
cp tests/isolation2/regression.diffs /logs/regression_isolation.diffs || true

gpstop -may -M immediate
export MASTER_DATA_DIRECTORY=/home/gpadmin/gpdb_src/gpAux/gpdemo/datadirs/standby
export COORDINATOR_DATA_DIRECTORY=$MASTER_DATA_DIRECTORY
export PGPORT=$(( PGPORT + 1 ))
gpactivatestandby -a -f -d $MASTER_DATA_DIRECTORY

# Run test again with standby master
cmake --build . --target installcheck || errors=$(( errors + $? ))

tar --dereference -czf "/logs/result_standby.tar.gz" \
  "tests/regress/results" \
  "tests/isolation2/results"

cp tests/regress/regression.diffs /logs/regression_regress_standby.diffs || true
cp tests/isolation2/regression.diffs /logs/regression_isolation_standby.diffs || true

exit $errors
