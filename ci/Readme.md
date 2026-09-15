# HOWTO

## Run tests

6X:
```bash
docker run --rm -it -v .:/home/gpadmin/diskquota ghcr.io/greengagedb/greengage/ggdb6_ubuntu:latest bash /home/gpadmin/diskquota/ci/test_in_docker.bash
```

7X:
```bash
docker run --rm -it -v .:/home/gpadmin/diskquota ghcr.io/greengagedb/greengage/ggdb7_ubuntu:latest bash /home/gpadmin/diskquota/ci/test_in_docker.bash
```

## Build package

6X:
```bash
GP_MAJORVERSION=6 ci/build_in_docker_local.sh
```

7X:
```bash
GP_MAJORVERSION=7 ci/build_in_docker_local.sh
```
