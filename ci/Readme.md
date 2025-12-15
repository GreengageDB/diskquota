# How to run tests

6X:
```bash
docker build -t gpdb6_distquota -f ci/Dockerfile .  
docker run --rm -it -v /tmp/logs:/logs gpdb6_distquota:latest bash /home/gpadmin/diskquota/ci/test_in_docker.bash
```

7X:
```bash
docker build -t gpdb7_distquota -f ci/Dockerfile --build-arg GGDB_IMAGE=ghcr.io/greengagedb/greengage/ggdb7_ubuntu:latest .  
docker run --rm -it -v /tmp/logs:/logs gpdb7_distquota:latest bash /home/gpadmin/diskquota/ci/test_in_docker.bash
```
