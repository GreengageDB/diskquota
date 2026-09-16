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

6X (default):

- Ubuntu 22.04 (default)

    ```bash
    ci/build_in_docker_local.sh
    ```

- Ubuntu 24.04:

    ```bash
    ci/build_in_docker_local.sh 6 24.04
    ```

7X:

- Ubuntu 22.04 (dxefault):

    ```bash
    ci/build_in_docker_local.sh 7
    ```
