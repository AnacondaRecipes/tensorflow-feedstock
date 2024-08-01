#!/bin/bash

set -exuo pipefail

if [[ "${target_platform}" == linux-* ]]; then
  export LDFLAGS="${LDFLAGS} -lrt"
fi
export CXXFLAGS="${CXXFLAGS} -std=c++17"
export CXXFLAGS="${CXXFLAGS} -I${CONDA_PREFIX}/include/tensorflow/third_party"
export CXXFLAGS="${CXXFLAGS} -I${CONDA_PREFIX}/include/tensorflow/third_party/xla"
${CXX} ${CXXFLAGS} ${LDFLAGS} -o test_cc test_cc.cc -ltensorflow_cc -ltensorflow_framework -labsl_status
./test_cc
