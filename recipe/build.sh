#!/bin/bash

set -ex

# Override for GitHub Actions CI
if [[ "$CI" == "github_actions" ]]; then
  export CPU_COUNT=4
fi

export PATH="$PWD:$PATH"
export CC=$(basename $CC)
export CXX=$(basename $CXX)
export LIBDIR=$PREFIX/lib
export INCLUDEDIR=$PREFIX/include

export TF_PYTHON_VERSION=$PY_VER

# Upstream docstring for TF_SYSTEM_LIBS in:
# https://github.com/tensorflow/tensorflow/blob/v{{ version }}/third_party/systemlibs/syslibs_configure.bzl
#   * `TF_SYSTEM_LIBS`: list of third party dependencies that should use
#      the system version instead
#
# To avoid bazel installing lots of vendored (python) packages,
# we need to install these packages through meta.yaml and then
# tell bazel to use them. Note that the names don't necessarily
# match PyPI or conda, but are defined in:
# https://github.com/tensorflow/tensorflow/blob/v{{ version }}/tensorflow/workspace<i>.bzl

# Exceptions and TODOs:
# Build failures in tensorflow/core/platform/s3/aws_crypto.cc
# boringssl (i.e. system openssl)
# Most importantly: Write a patch that uses system LLVM libs for sure as well as MLIR and oneDNN/mkldnn
# TODO(check):
# absl_py
# com_github_googleapis_googleapis
# Needs c++17, try on linux
#  com_googlesource_code_re2
# com_github_grpc_grpc
export TF_SYSTEM_LIBS="
  astor_archive
  astunparse_archive
  boringssl
  com_github_googlecloudplatform_google_cloud_cpp
  com_google_absl
  curl
  cython
  dill_archive
  flatbuffers
  gast_archive
  gif
  icu
  libjpeg_turbo
  org_sqlite
  png
  pybind11
  snappy
  zlib
  "
# sed -i -e "s/GRPCIO_VERSION/${grpc_cpp}/" tensorflow/tools/pip_package/setup.py

# do not build with MKL support
export TF_NEED_MKL=0
export BAZEL_MKL_OPT=""

mkdir -p ./bazel_output_base
export BAZEL_STARTUP_OPTS=""
export BAZEL_BUILD_OPTS=""

# Set this to something as otherwise, it would include CFLAGS which itself contains a host path and this then breaks bazel's include path validation.
export CC_OPT_FLAGS="-O2"

# Quick debug:
# cp -r ${RECIPE_DIR}/build.sh . && bazel clean && bash -x build.sh --logging=6 | tee log.txt
# Dependency graph:
# bazel query 'deps(//tensorflow/tools/lib_package:libtensorflow)' --output graph > graph.in
if [[ "${target_platform}" == osx-* ]]; then
  export LDFLAGS="${LDFLAGS} -lz -framework CoreFoundation -Xlinker -undefined -Xlinker dynamic_lookup"
  # Remove DEVELOPER_DIR from .bazelrc
  sed -i.bak '/DEVELOPER_DIR=\/Applications\/Xcode.app/d' .bazelrc

  # Force Bazel to use the conda C++ toolchain instead of Bazel’s Apple toolchain.
  export BAZEL_NO_APPLE_CPP_TOOLCHAIN=1
  export DEVELOPER_DIR=/Library/Developer/CommandLineTools
  export SDKROOT=${CONDA_BUILD_SYSROOT}
else
  export LDFLAGS="${LDFLAGS} -lrt"
fi

if [[ ${cuda_compiler_version} != "None" ]]; then
    export LDFLAGS="${LDFLAGS} -lcusparse"
    export GCC_HOST_COMPILER_PATH="${GCC}"
    export GCC_HOST_COMPILER_PREFIX="$(dirname ${GCC})"

    export TF_NEED_CUDA=1
    export TF_CUDA_VERSION="${cuda_compiler_version}"
    export TF_CUDNN_VERSION="${cudnn}"
    export TF_NCCL_VERSION=$(pkg-config nccl --modversion | grep -Po '\d+\.\d+')

    export LDFLAGS="${LDFLAGS//-Wl,-z,now/-Wl,-z,lazy}"
    export CC_OPT_FLAGS="-march=nocona -mtune=haswell"

    if [[ ${cuda_compiler_version} == 11.8 ]]; then
        export TF_CUDA_COMPUTE_CAPABILITIES=sm_35,sm_50,sm_60,sm_62,sm_70,sm_72,sm_75,sm_80,sm_86,sm_87,sm_89,sm_90,compute_90
        export TF_CUDA_PATHS="${PREFIX},${CUDA_HOME}"
    elif [[ "${cuda_compiler_version}" == 12* ]]; then
        export TF_CUDA_COMPUTE_CAPABILITIES=sm_60,sm_70,sm_75,sm_80,sm_86,sm_89,sm_90,compute_90
        export CUDNN_INSTALL_PATH=$PREFIX
        export NCCL_INSTALL_PATH=$PREFIX
        export CUDA_HOME="${BUILD_PREFIX}/targets/x86_64-linux"
        export TF_CUDA_PATHS="${BUILD_PREFIX}/targets/x86_64-linux,${PREFIX}/targets/x86_64-linux"
        
        export HERMETIC_CUDA_VERSION="${cuda_compiler_version}"
        export HERMETIC_CUDNN_VERSION="${cudnn}"
        export HERMETIC_CUDA_COMPUTE_CAPABILITIES=${TF_CUDA_COMPUTE_CAPABILITIES}
        export LOCAL_CUDA_PATH="${BUILD_PREFIX}/targets/x86_64-linux"
        export LOCAL_CUDNN_PATH="${PREFIX}/targets/x86_64-linux"
        export LOCAL_NCCL_PATH="${PREFIX}/targets/x86_64-linux"

        # XLA can only cope with a single cuda header include directory, merge both
        rsync -a ${PREFIX}/targets/x86_64-linux/include/ ${BUILD_PREFIX}/targets/x86_64-linux/include/
        
        # Also merge CUDA libraries
        rsync -a ${PREFIX}/targets/x86_64-linux/lib/ ${BUILD_PREFIX}/targets/x86_64-linux/lib/

        # Although XLA supports a non-hermetic build, it still tries to find headers in the hermetic locations.
        # We do this in the BUILD_PREFIX to not have any impact on the resulting package.
        # Otherwise, these copied files would be included in the package.
        rm -rf ${BUILD_PREFIX}/targets/x86_64-linux/include/third_party
        mkdir -p ${BUILD_PREFIX}/targets/x86_64-linux/include/third_party/gpus/cuda/extras/CUPTI
        cp -r ${PREFIX}/targets/x86_64-linux/include ${BUILD_PREFIX}/targets/x86_64-linux/include/third_party/gpus/cuda/
        cp -r ${PREFIX}/targets/x86_64-linux/include ${BUILD_PREFIX}/targets/x86_64-linux/include/third_party/gpus/cuda/extras/CUPTI/
        mkdir -p ${BUILD_PREFIX}/targets/x86_64-linux/include/third_party/gpus/cudnn
        cp ${PREFIX}/include/cudnn*.h ${BUILD_PREFIX}/targets/x86_64-linux/include/third_party/gpus/cudnn/

        mkdir -p ${BUILD_PREFIX}/targets/x86_64-linux/bin
        ln -s $(which ptxas) ${BUILD_PREFIX}/targets/x86_64-linux/bin/ptxas
        ln -s $(which nvlink) ${BUILD_PREFIX}/targets/x86_64-linux/bin/nvlink
        ln -s $(which fatbinary) ${BUILD_PREFIX}/targets/x86_64-linux/bin/fatbinary
        ln -s $(which bin2c) ${BUILD_PREFIX}/targets/x86_64-linux/bin/bin2c
        ln -s $(which nvprune) ${BUILD_PREFIX}/targets/x86_64-linux/bin/nvprune
        ln -s $PREFIX/bin/crt ${BUILD_PREFIX}/targets/x86_64-linux/bin/crt

        export PATH=$PATH:${BUILD_PREFIX}/nvvm/bin
          
  # hmaarrfk -- 2023/12/30
        # This logic should be safe to keep in even when the underlying issue is resolved
        # xref: https://github.com/conda-forge/cuda-nvcc-impl-feedstock/issues/9
        if [[ -x ${BUILD_PREFIX}/nvvm/bin/cicc ]]; then
            cp ${BUILD_PREFIX}/nvvm/bin/cicc ${BUILD_PREFIX}/bin/cicc
        fi
    else
        echo "unsupported cuda version."
        exit 1
    fi
else
    export TF_NEED_CUDA=0
fi

source gen-bazel-toolchain

# Get rid of unwanted defaults
sed -i -e "/PREFIX/c\ " .bazelrc
# Ensure .bazelrc ends in a newline
echo "" >> .bazelrc

if [[ "${target_platform}" == "osx-arm64" ]]; then
  echo "build --config=macos_arm64" >> .bazelrc
fi

export TF_ENABLE_XLA=1
export BUILD_TARGET="//tensorflow/tools/pip_package:wheel"

# Python settings
export PYTHON_BIN_PATH=${PYTHON}
export PYTHON_LIB_PATH=${SP_DIR}
export USE_DEFAULT_PYTHON_LIB_PATH=1

# additional settings
export TF_NEED_OPENCL=0
export TF_NEED_OPENCL_SYCL=0
export TF_NEED_COMPUTECPP=0
export TF_CUDA_CLANG=0
if [[ "${target_platform}" == linux-* ]]; then
  export TF_NEED_CLANG=0
fi
export TF_NEED_TENSORRT=0
export TF_NEED_ROCM=0
export TF_NEED_MPI=0
export TF_DOWNLOAD_CLANG=0
export TF_SET_ANDROID_WORKSPACE=0
export TF_CONFIGURE_IOS=0


bazel clean --expunge
bazel shutdown

./configure

# Remove legacy flags set by configure that conflicts with CUDA 12's multi-directory approach.
if [[ "${cuda_compiler_version}" == 12* ]]; then
    sed -i '/CUDA_TOOLKIT_PATH/d' .tf_configure.bazelrc
fi

if [[ "${build_platform}" == linux-* ]]; then
  $RECIPE_DIR/add_py_toolchain.sh
fi

cat >> .bazelrc <<EOF

build --crosstool_top=//bazel_toolchain:toolchain
build --logging=6
build --verbose_failures
build --define=PREFIX=${PREFIX}
build --define=LIBDIR=${LIBDIR}
# TODO: re-enable once we upgrade from gcc 11.8 and get support for flag -mavx512fp16.
# See: https://github.com/google/XNNPACK/blob/master/BUILD.bazel
build --define=xnn_enable_avx512fp16=false
build --define=xnn_enable_avxvnniint8=false
build --cpu=${TARGET_CPU}
build --local_resources=cpu=${CPU_COUNT}
build --linkopt=-lgif
build --linkopt=-L${LIBDIR}

# Base libraries
build --linkopt=-labsl_base
build --linkopt=-labsl_log_severity
build --linkopt=-labsl_raw_logging_internal
build --linkopt=-labsl_spinlock_wait
build --linkopt=-labsl_malloc_internal
build --linkopt=-labsl_throw_delegate
build --linkopt=-labsl_exponential_biased
build --linkopt=-labsl_periodic_sampler

# String libraries
build --linkopt=-labsl_strings
build --linkopt=-labsl_strings_internal
build --linkopt=-labsl_string_view
build --linkopt=-labsl_str_format_internal
build --linkopt=-labsl_int128
build --linkopt=-labsl_utf8_for_code_point

# Cord (rope) libraries
build --linkopt=-labsl_cord
build --linkopt=-labsl_cord_internal
build --linkopt=-labsl_cordz_functions
build --linkopt=-labsl_cordz_handle
build --linkopt=-labsl_cordz_info
build --linkopt=-labsl_cordz_sample_token

# Synchronization libraries
build --linkopt=-labsl_synchronization
build --linkopt=-labsl_graphcycles_internal
build --linkopt=-labsl_kernel_timeout_internal

# Time libraries
build --linkopt=-labsl_time
build --linkopt=-labsl_time_zone
build --linkopt=-labsl_civil_time

# Status libraries
build --linkopt=-labsl_status
build --linkopt=-labsl_statusor

# Hash and container libraries
build --linkopt=-labsl_hash
build --linkopt=-labsl_city
build --linkopt=-labsl_low_level_hash
build --linkopt=-labsl_raw_hash_set
build --linkopt=-labsl_hashtablez_sampler

# Flags libraries (command-line flag parsing)
build --linkopt=-labsl_flags_internal
build --linkopt=-labsl_flags_reflection
build --linkopt=-labsl_flags_config
build --linkopt=-labsl_flags_marshalling
build --linkopt=-labsl_flags_commandlineflag
build --linkopt=-labsl_flags_commandlineflag_internal
build --linkopt=-labsl_flags_private_handle_accessor
build --linkopt=-labsl_flags_program_name
build --linkopt=-labsl_flags_parse
build --linkopt=-labsl_flags_usage
build --linkopt=-labsl_flags_usage_internal

# Random number generation libraries
build --linkopt=-labsl_random_distributions
build --linkopt=-labsl_random_seed_sequences
build --linkopt=-labsl_random_internal_pool_urbg
build --linkopt=-labsl_random_internal_platform
build --linkopt=-labsl_random_internal_seed_material
build --linkopt=-labsl_random_internal_randen
build --linkopt=-labsl_random_internal_randen_hwaes
build --linkopt=-labsl_random_internal_randen_hwaes_impl
build --linkopt=-labsl_random_internal_randen_slow
build --linkopt=-labsl_random_seed_gen_exception
build --linkopt=-labsl_random_internal_distribution_test_util

# Debugging libraries
build --linkopt=-labsl_stacktrace
build --linkopt=-labsl_symbolize
build --linkopt=-labsl_debugging_internal
build --linkopt=-labsl_demangle_internal
build --linkopt=-labsl_demangle_rust
build --linkopt=-labsl_decode_rust_punycode
build --linkopt=-labsl_examine_stack
build --linkopt=-labsl_failure_signal_handler
build --linkopt=-labsl_leak_check

# Logging libraries
build --linkopt=-labsl_log_internal_message
build --linkopt=-labsl_log_internal_check_op
build --linkopt=-labsl_log_internal_conditions
build --linkopt=-labsl_log_internal_format
build --linkopt=-labsl_log_internal_globals
build --linkopt=-labsl_log_internal_proto
build --linkopt=-labsl_log_internal_nullguard
build --linkopt=-labsl_log_internal_log_sink_set
build --linkopt=-labsl_log_internal_fnmatch
build --linkopt=-labsl_log_internal_structured_proto
build --linkopt=-labsl_log_globals
build --linkopt=-labsl_log_flags
build --linkopt=-labsl_log_initialize
build --linkopt=-labsl_log_entry
build --linkopt=-labsl_log_sink
build --linkopt=-labsl_vlog_config_internal

# CRC libraries
build --linkopt=-labsl_crc32c
build --linkopt=-labsl_crc_internal
build --linkopt=-labsl_crc_cpu_detect
build --linkopt=-labsl_crc_cord_state

# Utility libraries
build --linkopt=-labsl_bad_any_cast_impl
build --linkopt=-labsl_bad_optional_access
build --linkopt=-labsl_bad_variant_access
build --linkopt=-labsl_die_if_null
build --linkopt=-labsl_strerror
build --linkopt=-labsl_tracing_internal
build --linkopt=-labsl_scoped_set_env
build --linkopt=-labsl_poison

EOF

if [[ ${cuda_compiler_version} != "None" ]]; then
    echo "build --config=cuda_wheel" >> .bazelrc
fi

# Update TF lite schema with latest flatbuffers version
pushd tensorflow/compiler/mlir/lite/schema
flatc --cpp --gen-object-api schema.fbs
popd
rm -f tensorflow/lite/schema/conversion_metadata_generated.h
rm -f tensorflow/lite/experimental/acceleration/configuration/configuration_generated.h

# Replace placeholders from xxxx-Hardcode-BUILD_PREFIX-in-build_pip_package.patch
sed -ie "s;BUILD_PREFIX;${BUILD_PREFIX};g" tensorflow/tools/pip_package/build_pip_package.py

# build using bazel
bazel ${BAZEL_STARTUP_OPTS} build ${BAZEL_BUILD_OPTS} ${BUILD_TARGET}

# build a whl file
mkdir -p $SRC_DIR/tensorflow_pkg
cp bazel-bin/tensorflow/tools/pip_package/wheel_house/tensorflow*.whl $SRC_DIR/tensorflow_pkg

if [[ "${target_platform}" == osx-* ]]; then
  cp -RP bazel-bin/tensorflow/python/libtensorflow_cc.* $PREFIX/lib/
  cp -RP bazel-bin/tensorflow/python/libtensorflow_framework.* $PREFIX/lib/
else
  cp -d bazel-bin/tensorflow/python/libtensorflow_cc.so* $PREFIX/lib/
  cp -d bazel-bin/tensorflow/python/libtensorflow_framework.so* $PREFIX/lib/
  ln -sf $PREFIX/lib/libtensorflow_framework.so.2 $PREFIX/lib/libtensorflow_framework.so
fi

bazel clean --expunge
bazel shutdown

# This was only needed for protobuf_python
rm -rf $PREFIX/include/python
