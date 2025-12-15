#! /bin/bash

set -exuo pipefail

# workaround to get PBP to see that OSX_SDK_DIR is used
# and thus get it forwarded to the build
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo $OSX_SDK_DIR
    echo $OSX_SDK_VER
fi

# install the whl making sure to use host pip/python if cross-compiling
${PYTHON} -m pip install --no-deps --no-build-isolation $SRC_DIR/tensorflow_pkg/*.whl

if [[ "$target_platform" == "osx-"* ]]; then
  rm -rf ${SP_DIR}/tensorflow/python/libtensorflow.2.dylib
  rm -rf ${SP_DIR}/tensorflow/python/libtensorflow_cc.2.dylib
  ln -sf ${PREFIX}/lib/libtensorflow.2.dylib ${SP_DIR}/tensorflow/python/libtensorflow.2.dylib
  ln -sf ${PREFIX}/lib/libtensorflow_cc.2.dylib ${SP_DIR}/tensorflow/python/libtensorflow_cc.2.dylib
else
  rm -rf ${SP_DIR}/tensorflow/python/libtensorflow.so.2
  rm -rf ${SP_DIR}/tensorflow/python/libtensorflow_cc.so.2
  ln -sf ${PREFIX}/lib/libtensorflow.so.2 ${SP_DIR}/tensorflow/python/libtensorflow.so.2
  ln -sf ${PREFIX}/lib/libtensorflow_cc.so.2 ${SP_DIR}/tensorflow/python/libtensorflow_cc.so.2
fi

# The tensorboard package has the proper entrypoint
rm -f ${PREFIX}/bin/tensorboard
