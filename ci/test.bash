#!/usr/bin/env bash

set -xeu

source /usr/local/greengage-db-devel/greengage_path.sh
source /home/gpadmin/gpdb_src/gpAux/gpdemo/gpdemo-env.sh

pushd /home/gpadmin/gpdb_src
  make -C src/test/isolation2 install
popd

# build and install
mkdir build && cd build
cmake ..
cmake --build .
make install

export SHOW_REGRESS_DIFF=1
errors=0

# test without standby
cmake --build . --target installcheck || errors=$(( errors + $? ))

cp tests/regress/regression.diffs /logs/regression_regress_with_standby.diffs || true
cp tests/isolation2/regression.diffs /logs/regression_isolation_with_standby.diffs || true

gpstop -may -M immediate
export MASTER_DATA_DIRECTORY=/home/gpadmin/gpdb_src/gpAux/gpdemo/datadirs/standby
export PGPORT=$(( PGPORT + 1 ))
gpactivatestandby -a -f -d $MASTER_DATA_DIRECTORY

# test with standby
cmake --build . --target installcheck || errors=$(( errors + $? ))

cp tests/regress/regression.diffs /logs/regression_regress_without_standby.diffs || true
cp tests/isolation2/regression.diffs /logs/regression_isolation_without_standby.diffs || true

exit $errors
