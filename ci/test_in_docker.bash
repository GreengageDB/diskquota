#!/usr/bin/env bash

bash /home/gpadmin/diskquota/ci/install.bash
cd /home/gpadmin/diskquota
su gpadmin -c 'bash ci/test.bash'
