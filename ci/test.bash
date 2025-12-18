#!/usr/bin/env bash

set -xeu

source /usr/local/greengage-db-devel/greengage_path.sh
source /home/gpadmin/gpdb_src/gpAux/gpdemo/gpdemo-env.sh

cd build

export SHOW_REGRESS_DIFF=1
errors=0

cmake --build . --target installcheck || errors=$(( errors + $? ))

cp tests/regress/regression.diffs /logs/regression_regress_with_standby.diffs || true
cp tests/isolation2/regression.diffs /logs/regression_isolation_with_standby.diffs || true

gpstop -may -M immediate
export MASTER_DATA_DIRECTORY=/home/gpadmin/gpdb_src/gpAux/gpdemo/datadirs/standby
export PGPORT=$(( PGPORT + 1 ))
gpactivatestandby -a -f -d $MASTER_DATA_DIRECTORY

# Run test again with standby master
cmake --build . --target installcheck || errors=$(( errors + $? ))

cp tests/regress/regression.diffs /logs/regression_regress_without_standby.diffs || true
cp tests/isolation2/regression.diffs /logs/regression_isolation_without_standby.diffs || true

exit $errors
