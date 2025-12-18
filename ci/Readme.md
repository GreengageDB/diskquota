# How to run tests

6X:
```bash
docker build -t gpdb6_diskquota -f ci/Dockerfile .
docker run --rm -it gpdb6_diskquota:latest bash /home/gpadmin/diskquota/ci/test_in_docker.bash
```

7X:
```bash
docker build -t gpdb7_diskquota -f ci/Dockerfile --build-arg GGDB_IMAGE=ghcr.io/greengagedb/greengage/ggdb7_ubuntu:latest .
docker run --rm -it gpdb7_diskquota:latest bash /home/gpadmin/diskquota/ci/test_in_docker.bash
```
