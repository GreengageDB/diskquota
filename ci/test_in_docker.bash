#!/usr/bin/env bash

set -xeu

source /usr/local/greengage-db-devel/greengage_path.sh;
source /home/gpadmin/gpdb_src/gpAux/gpdemo/gpdemo-env.sh;

pushd /home/gpadmin/gpdb_src
  make -C src/test/isolation2 install
popd

# build and install
mkdir build && cd build
cmake ..
cmake --build .
make install

if ! gpinitstandby -ar; then
  echo "failed to disable standby"
  exit 1
fi

export SHOW_REGRESS_DIFF=1
# test without standby
set +e
cmake --build . --target installcheck
errors=$?
set -e

cp tests/regress/regression.diffs /logs/regression_regress_with_standby.diffs || true
cp tests/isolation2/regression.diffs /logs/regression_isolation_with_standby.diffs || true

if ! gpinitstandby -a -s $(hostname) -P $((PGPORT + 1)) -S /home/gpadmin/gpdb_src/gpAux/gpdemo/datadirs/standby; then
  echo "failed to enable standby"
  exit 1
fi

# test with standby
set +e
cmake --build . --target installcheck
errors=$(( errors + $? ))
set -e

cp tests/regress/regression.diffs /logs/regression_regress_without_standby.diffs || true
cp tests/isolation2/regression.diffs /logs/regression_isolation_without_standby.diffs || true

exit $errors
