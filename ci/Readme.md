# How to run tests

6X:
```bash
docker build -t gpdb6_diskquota -f ci/Dockerfile .
docker run --rm -it gpdb6_diskquota:latest bash
```

7X:
```bash
docker build -t gpdb7_diskquota -f ci/Dockerfile --build-arg GGDB_IMAGE=ghcr.io/greengagedb/greengage/ggdb7_ubuntu:latest .
docker run --rm -it gpdb7_diskquota:latest bash
```

```bash
source gpdb_src/concourse/scripts/common.bash
install_and_configure_gpdb
gpdb_src/concourse/scripts/setup_gpadmin_user.bash
make_cluster

su - gpadmin
source /usr/local/greengage-db-devel/greengage_path.sh;
source gpdb_src/gpAux/gpdemo/gpdemo-env.sh;

cd diskquota
bash ci/test_in_docker.bash
```
