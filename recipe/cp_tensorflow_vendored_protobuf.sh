#!/bin/bash

set -exuo pipefail

# Extract the vendored protobuf headers directly from the wheel to SRC_DIR for separate packaging
echo "Extracting vendored protobuf headers from TensorFlow wheel"
mkdir -p ${SRC_DIR}/tensorflow_protobuf_headers
cd ${SRC_DIR}/tensorflow_protobuf_headers
python -m zipfile -e ${SRC_DIR}/tensorflow_pkg/*.whl .
if [ -d "tensorflow/include/google" ]; then
    mv tensorflow/include/google ./
    rm -rf tensorflow
    echo "Protobuf headers extracted to ${SRC_DIR}/tensorflow_protobuf_headers/google"
else
    echo "ERROR: No vendored protobuf headers found in wheel"
    exit 1
fi

# Create the include directory in PREFIX
mkdir -p ${PREFIX}/include

# Move the extracted protobuf headers from SRC_DIR to SP_DIR/tensorflow/include
if [ -d "${SRC_DIR}/tensorflow_protobuf_headers/google" ]; then
    echo "Installing protobuf headers to ${SP_DIR}/tensorflow/include"
    mkdir -p ${SP_DIR}/tensorflow/include
    mv ${SRC_DIR}/tensorflow_protobuf_headers/google ${SP_DIR}/tensorflow/include
    echo "Protobuf headers installed successfully"
    
    # List the files for verification
    find ${SP_DIR}/tensorflow/include/google -name "*.h" | head -10 || echo "No header files found"
else
    echo "ERROR: No protobuf headers found in ${SRC_DIR}/tensorflow_protobuf_headers/google"
    echo "Available contents in SRC_DIR:"
    ls -la ${SRC_DIR}/ || echo "SRC_DIR not accessible"
    exit 1
fi

