#!/bin/bash

set -ex

# Override for GitHub Actions CI
if [[ "$CI" == "github_actions" ]]; then
  export CPU_COUNT=4
elif [[ "${target_platform}" == "linux-aarch64" ]]; then
  # To prevent memory exhaustion on CI
  export CPU_COUNT=12
elif [[ ${cuda_compiler_version} != "None" ]]; then
  # To prevent disk exhaustion on CI
  export CPU_COUNT=12
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
export TF_SYSTEM_LIBS="
  astor_archive
  astunparse_archive
  boringssl
  com_github_googlecloudplatform_google_cloud_cpp
  com_google_absl
  com_google_protobuf
  com_github_grpc_grpc
  com_googlesource_code_re2
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
    if [[ "${target_platform}" == "linux-64" ]]; then
        export CC_OPT_FLAGS="-march=nocona -mtune=haswell"
    fi

    if [[ "${cuda_compiler_version}" == 12* || "${cuda_compiler_version}" == 13* ]]; then
        if [[ "${cuda_compiler_version}" == 13* ]]; then
            export TF_CUDA_COMPUTE_CAPABILITIES=sm_75,sm_80,sm_86,sm_89,sm_90,sm_100,compute_90
        else
            export TF_CUDA_COMPUTE_CAPABILITIES=sm_60,sm_70,sm_75,sm_80,sm_86,sm_89,sm_90,compute_90
        fi
        export CUDNN_INSTALL_PATH=$PREFIX
        export NCCL_INSTALL_PATH=$PREFIX

        # CUDA toolkit layout differs by architecture:
        # - x86_64 uses targets/x86_64-linux
        # - aarch64 uses targets/sbsa-linux
        if [[ "${target_platform}" == "linux-aarch64" ]]; then
            CUDA_TARGET_DIR="targets/sbsa-linux"
        else
            CUDA_TARGET_DIR="targets/x86_64-linux"
        fi

        export CUDA_HOME="${BUILD_PREFIX}/${CUDA_TARGET_DIR}"
        export TF_CUDA_PATHS="${BUILD_PREFIX}/${CUDA_TARGET_DIR},${PREFIX}/${CUDA_TARGET_DIR}"
        
        export HERMETIC_CUDA_VERSION="${cuda_compiler_version}"
        export HERMETIC_CUDNN_VERSION="${cudnn}"
        export HERMETIC_CUDA_COMPUTE_CAPABILITIES=${TF_CUDA_COMPUTE_CAPABILITIES}
        export LOCAL_CUDA_PATH="${BUILD_PREFIX}/${CUDA_TARGET_DIR}"
        export LOCAL_CUDNN_PATH="${PREFIX}/${CUDA_TARGET_DIR}"
        export LOCAL_NCCL_PATH="${PREFIX}/${CUDA_TARGET_DIR}"

        # XLA can only cope with a single cuda header include directory, merge both
        rsync -a ${PREFIX}/${CUDA_TARGET_DIR}/include/ ${BUILD_PREFIX}/${CUDA_TARGET_DIR}/include/

        # Also merge CUDA libraries
        rsync -a ${PREFIX}/${CUDA_TARGET_DIR}/lib/ ${BUILD_PREFIX}/${CUDA_TARGET_DIR}/lib/

        # Although XLA supports a non-hermetic build, it still tries to find headers in the hermetic locations.
        # We do this in the BUILD_PREFIX to not have any impact on the resulting package.
        # Otherwise, these copied files would be included in the package.
        rm -rf ${BUILD_PREFIX}/${CUDA_TARGET_DIR}/include/third_party
        mkdir -p ${BUILD_PREFIX}/${CUDA_TARGET_DIR}/include/third_party/gpus/cuda/extras/CUPTI
        cp -r ${PREFIX}/${CUDA_TARGET_DIR}/include ${BUILD_PREFIX}/${CUDA_TARGET_DIR}/include/third_party/gpus/cuda/
        cp -r ${PREFIX}/${CUDA_TARGET_DIR}/include ${BUILD_PREFIX}/${CUDA_TARGET_DIR}/include/third_party/gpus/cuda/extras/CUPTI/
        mkdir -p ${BUILD_PREFIX}/${CUDA_TARGET_DIR}/include/third_party/gpus/cudnn
        cp ${PREFIX}/include/cudnn*.h ${BUILD_PREFIX}/${CUDA_TARGET_DIR}/include/third_party/gpus/cudnn/

        # CUDA 13 / CCCL 3.0 moved CUB/Thrust/libcudacxx headers under include/cccl/.
        # Copy them back to legacy paths so bare #include "cub/..." still resolves.
        # Use hard copies; symlinks don't survive Bazel's sandbox.
        for _incdir in \
            ${BUILD_PREFIX}/${CUDA_TARGET_DIR}/include \
            ${BUILD_PREFIX}/${CUDA_TARGET_DIR}/include/third_party/gpus/cuda/include \
            ${BUILD_PREFIX}/${CUDA_TARGET_DIR}/include/third_party/gpus/cuda/extras/CUPTI/include; do
            for _lib in cub thrust nv; do
                if [[ -d ${_incdir}/cccl/${_lib} && ! -d ${_incdir}/${_lib} ]]; then
                    cp -r ${_incdir}/cccl/${_lib} ${_incdir}/${_lib}
                fi
            done
            # cuda/ already exists (runtime headers); merge CCCL's cuda/ into it
            if [[ -d ${_incdir}/cccl/cuda ]]; then
                cp -rn ${_incdir}/cccl/cuda/ ${_incdir}/cuda/ 2>/dev/null || true
            fi
        done

        mkdir -p ${BUILD_PREFIX}/${CUDA_TARGET_DIR}/bin
        ln -s $(which ptxas) ${BUILD_PREFIX}/${CUDA_TARGET_DIR}/bin/ptxas
        ln -s $(which nvlink) ${BUILD_PREFIX}/${CUDA_TARGET_DIR}/bin/nvlink
        ln -s $(which fatbinary) ${BUILD_PREFIX}/${CUDA_TARGET_DIR}/bin/fatbinary
        ln -s $(which bin2c) ${BUILD_PREFIX}/${CUDA_TARGET_DIR}/bin/bin2c
        ln -s $(which nvprune) ${BUILD_PREFIX}/${CUDA_TARGET_DIR}/bin/nvprune
        ln -s $PREFIX/bin/crt ${BUILD_PREFIX}/${CUDA_TARGET_DIR}/bin/crt

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

# XLA's embed_gpu_specs_gen genrule needs xxd, which isn't available as a
# conda package. Provide a minimal Python shim that emulates `xxd -i`.
cp "${RECIPE_DIR}/xxd.py" xxd
chmod +x xxd

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
if [[ "${cuda_compiler_version}" == 12* || "${cuda_compiler_version}" == 13* ]]; then
    sed -i '/CUDA_TOOLKIT_PATH/d' .tf_configure.bazelrc
fi

if [[ "${build_platform}" == linux-* ]]; then
  $RECIPE_DIR/add_py_toolchain.sh
fi

cat >> .bazelrc <<EOF

build --crosstool_top=//bazel_toolchain:toolchain
build --noincompatible_enable_cc_toolchain_resolution
build --logging=6
build --verbose_failures
build --define=PREFIX=${PREFIX}
build --define=PROTOBUF_INCLUDE_PATH=${PREFIX}/include
build --copt=-D_GNU_SOURCE
build --host_copt=-D_GNU_SOURCE
build --conlyopt=-include
build --conlyopt=stdint.h
build --cxxopt=-include
build --cxxopt=cstdint
build --host_conlyopt=-include
build --host_conlyopt=stdint.h
build --host_cxxopt=-include
build --host_cxxopt=cstdint
build --repo_env=ML_WHEEL_TYPE=release
# TODO: re-enable once we upgrade from gcc 11.8 and get support for flag -mavx512fp16.
# See: https://github.com/google/XNNPACK/blob/master/BUILD.bazel
build --define=xnn_enable_avx512fp16=false
build --define=xnn_enable_avxvnniint8=false
build --cpu=${TARGET_CPU}
build --local_resources=cpu=${CPU_COUNT}
# If the final linking fails, stderr is trucated. Increase the size of the buffer.
build --experimental_ui_max_stdouterr_bytes=104857600

EOF

if [[ "${target_platform}" == "linux-aarch64" ]]; then
  # XNNPACK SME/SME2 kernels currently require ISA support not available in
  # our aarch64 GCC toolchain configuration on CI.
  echo "build --define=xnn_enable_arm_sme=false" >> .bazelrc
  echo "build --define=xnn_enable_arm_sme2=false" >> .bazelrc
  # Newer XNNPACK routes these kernels through YNNPACK feature flags.
  echo "build --define=ynn_enable_arm64_sme=false" >> .bazelrc
  echo "build --define=ynn_enable_arm64_sme2=false" >> .bazelrc
  # Disable BF16 YNNPACK kernels; current aarch64 toolchain errors in assembly
  # on arm_neonbf16 with `fmov v*.8h`.
  echo "build --define=ynn_enable_arm_neonbf16=false" >> .bazelrc
fi

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

# For reasons unknown, the linkopts from the systemlib shims are not propogating on linux.
# It's possible to manually add the link flags for each target, but that results 
# in hundreds of patched files. This seems to be related to the change between
# 2.19 and 2.20 where /third_party/absl/* was moved into /third_party/xla/third_party/absl/*.
# Remove this bandaid once TF_SYSTEM_LIBS properly handles absl again.
echo "build:linux --linkopt=-labsl_raw_hash_set" >> .bazelrc
echo "build:linux --linkopt=-labsl_hash" >> .bazelrc
echo "build:linux --linkopt=-labsl_city" >> .bazelrc  
echo "build:linux --linkopt=-labsl_status" >> .bazelrc
echo "build:linux --linkopt=-labsl_statusor" >> .bazelrc
echo "build:linux --linkopt=-labsl_strings" >> .bazelrc
echo "build:linux --linkopt=-labsl_strings_internal" >> .bazelrc
echo "build:linux --linkopt=-labsl_str_format_internal" >> .bazelrc
echo "build:linux --linkopt=-labsl_cord" >> .bazelrc
echo "build:linux --linkopt=-labsl_cord_internal" >> .bazelrc
echo "build:linux --linkopt=-labsl_cordz_functions" >> .bazelrc
echo "build:linux --linkopt=-labsl_cordz_info" >> .bazelrc
echo "build:linux --linkopt=-labsl_cordz_handle" >> .bazelrc
echo 'build:linux --host_linkopt=-labsl_cordz_info'  >> .bazelrc
echo 'build:linux --host_linkopt=-labsl_cord_internal'      >> .bazelrc
echo 'build:linux --host_linkopt=-labsl_cordz_functions'    >> .bazelrc
echo 'build:linux --host_linkopt=-labsl_cordz_handle'       >> .bazelrc
echo "build:linux --linkopt=-labsl_log_internal_message" >> .bazelrc
echo "build:linux --linkopt=-labsl_log_internal_check_op" >> .bazelrc
echo "build:linux --linkopt=-labsl_log_internal_nullguard" >> .bazelrc
echo "build:linux --linkopt=-labsl_log_internal_conditions" >> .bazelrc
echo "build:linux --linkopt=-labsl_log_internal_format" >> .bazelrc
echo "build:linux --linkopt=-labsl_log_internal_globals" >> .bazelrc
echo "build:linux --linkopt=-labsl_vlog_config_internal" >> .bazelrc
echo "build:linux --linkopt=-labsl_crc32c" >> .bazelrc
echo "build:linux --linkopt=-labsl_crc_cord_state" >> .bazelrc
echo "build:linux --linkopt=-labsl_crc_internal" >> .bazelrc
echo "build:linux --linkopt=-labsl_crc_cpu_detect" >> .bazelrc
echo "build:linux --linkopt=-labsl_time" >> .bazelrc
echo "build:linux --linkopt=-labsl_time_zone" >> .bazelrc
echo "build:linux --linkopt=-labsl_random_internal_randen_hwaes" >> .bazelrc
echo "build:linux --linkopt=-labsl_random_internal_randen_slow" >> .bazelrc
echo "build:linux --linkopt=-labsl_throw_delegate" >> .bazelrc
echo "build:linux --linkopt=-labsl_spinlock_wait" >> .bazelrc
echo "build:linux --linkopt=-labsl_kernel_timeout_internal" >> .bazelrc
echo 'build:linux --host_linkopt=-labsl_kernel_timeout_internal' >> .bazelrc
echo "build:linux --linkopt=-labsl_random_internal_randen" >> .bazelrc
echo "build:linux --linkopt=-labsl_die_if_null" >> .bazelrc
echo "build:linux --linkopt=-labsl_flags_internal" >> .bazelrc
echo "build:linux --linkopt=-labsl_flags_commandlineflag" >> .bazelrc
echo "build:linux --linkopt=-labsl_flags_commandlineflag_internal" >> .bazelrc
echo "build:linux --linkopt=-labsl_flags_config" >> .bazelrc
echo "build:linux --linkopt=-labsl_flags_marshalling" >> .bazelrc
echo "build:linux --linkopt=-labsl_flags_reflection" >> .bazelrc
echo "build:linux --linkopt=-labsl_flags_parse" >> .bazelrc
echo "build:linux --linkopt=-labsl_flags_private_handle_accessor" >> .bazelrc
echo "build:linux --linkopt=-labsl_random_internal_platform" >> .bazelrc
echo "build:linux --linkopt=-labsl_random_internal_randen_hwaes_impl" >> .bazelrc
echo 'build:linux --linkopt=-labsl_examine_stack'             >> .bazelrc
echo 'build:linux --host_linkopt=-labsl_examine_stack'        >> .bazelrc
echo 'build:linux --linkopt=-labsl_tracing_internal' >> .bazelrc
echo 'build:linux --host_linkopt=-labsl_tracing_internal' >> .bazelrc
echo 'build:linux --linkopt=-labsl_random_internal_entropy_pool' >> .bazelrc
echo 'build:linux --host_linkopt=-labsl_random_internal_entropy_pool' >> .bazelrc
echo 'build:linux --linkopt=-labsl_leak_check' >> .bazelrc
echo 'build:linux --host_linkopt=-labsl_leak_check' >> .bazelrc
echo 'build:linux --linkopt=-labsl_int128' >> .bazelrc
echo 'build:linux --host_linkopt=-labsl_int128' >> .bazelrc
echo 'build:linux --linkopt=-lre2' >> .bazelrc
echo 'build:linux --host_linkopt=-lre2' >> .bazelrc

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
