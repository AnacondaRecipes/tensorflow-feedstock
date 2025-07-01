#!/bin/bash

set -exuo pipefail

if [[ "${target_platform}" == linux-* ]]; then
  export LDFLAGS="${LDFLAGS} -lrt"
fi
if [[ "${target_platform}" == osx-64 ]]; then
  export CXXFLAGS="${CXXFLAGS} -isysroot ${SDKROOT} -mmacosx-version-min=10.15"
fi
export CXXFLAGS="${CXXFLAGS} -std=c++17"
export CXXFLAGS="${CXXFLAGS} -I${CONDA_PREFIX}/include/tensorflow/third_party"
export CXXFLAGS="${CXXFLAGS} -I${CONDA_PREFIX}/include/tensorflow/third_party/xla"
export CXXFLAGS="${CXXFLAGS} -I${SP_DIR}/tensorflow/include"
export CXXFLAGS="${CXXFLAGS} -I${CONDA_PREFIX}/include"
${CXX} ${CXXFLAGS} ${LDFLAGS} -o test_cc test_cc.cc -ltensorflow_cc -ltensorflow_framework -labsl_status
./test_cc
