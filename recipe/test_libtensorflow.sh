#!/bin/bash

set -euxo pipefail

${CC} ${CFLAGS} ${LDFLAGS} -o test_c test_c.c -ltensorflow -labsl_status
./test_c
