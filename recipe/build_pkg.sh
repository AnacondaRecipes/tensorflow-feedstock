#! /bin/bash

set -exuo pipefail

# install the whl making sure to use host pip/python if cross-compiling
${PYTHON} -m pip install --no-deps --no-build-isolation $SRC_DIR/tensorflow_pkg/*.whl

# The tensorboard package has the proper entrypoint
rm -f ${PREFIX}/bin/tensorboard

# These will come from the vendored protobuf headers output
rm -rf $SP_DIR/tensorflow/include/google/protobuf