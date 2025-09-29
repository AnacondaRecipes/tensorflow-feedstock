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

# The tensorboard package has the proper entrypoint
rm -f ${PREFIX}/bin/tensorboard

# These will come from the vendored protobuf headers output
rm -rf $SP_DIR/tensorflow/include/google/protobuf