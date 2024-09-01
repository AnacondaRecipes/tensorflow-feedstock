#!/bin/bash

set -euxo pipefail

function apply_cc_template() {
  # Strip trailing/duplicate whitespace
  CFLAGS=$(echo $CFLAGS | xargs echo -n)
  CPPFLAGS=$(echo $CPPFLAGS | xargs echo -n)
  CXXFLAGS=$(echo $CXXFLAGS | xargs echo -n)
  LDFLAGS=$(echo $LDFLAGS | xargs echo -n)

  sed -ie "s:TARGET_CPU:${TARGET_CPU}:" $1
  sed -ie "s:TARGET_LIBC:${TARGET_LIBC}:" $1
  sed -ie "s:TARGET_SYSTEM:${TARGET_SYSTEM}:" $1
  sed -ie "s:TARGET_PLATFORM:${target_platform}:" $1
  sed -ie "s:\${CONDA_BUILD_SYSROOT}:${CONDA_BUILD_SYSROOT}:" $1
  sed -ie "s:\${COMPILER_VERSION}:${BAZEL_TOOLCHAIN_COMPILER_VERSION:-}:" $1
  sed -ie "s:\${SHORT_COMPILER_VERSION}:${SHORT_BAZEL_TOOLCHAIN_COMPILER_VERSION:-}:" $1
  sed -ie "s:\${GCC_COMPILER_PATH}:${GCC:-}:" $1
  sed -ie "s:\${BAZEL_TOOLCHAIN_GCC}:${BAZEL_TOOLCHAIN_GCC}:" $1
  sed -ie "s:\${CUDA_VERSION}:${cuda_compiler_version:-}:" $1
  sed -ie "s:\${CUDA_HOME}:${CUDA_HOME:-}:" $1
  sed -ie "s:\${PREFIX}:${PREFIX}:" $1
  sed -ie "s:\${CONDA_PREFIX}:${CONDA_PREFIX}:" $1
  sed -ie "s:\${HOST_PREFIX}:${HOST_PREFIX}:" $1
  sed -ie "s:\${BUILD_PREFIX}:${BUILD_PREFIX}:" $1
  sed -ie "s:\${LD}:${LD}:" $1
  sed -ie "s:\${CFLAGS}:${CFLAGS}:" $1
  sed -ie "s:\${CPPFLAGS}:${CPPFLAGS}:" $1
  sed -ie "s:\${CXXFLAGS}:${CXXFLAGS}:" $1
  sed -ie "s:\${LDFLAGS}:${LDFLAGS}:" $1
  sed -ie "s:\${NM}:${NM}:" $1
  sed -ie "s:\${STRIP}:${STRIP}:" $1
  sed -ie "s:\${AR}:${BAZEL_TOOLCHAIN_AR}:" $1
  sed -ie "s:\${HOST}:${HOST}:" $1
  sed -ie "s:\${LIBCXX}:${BAZEL_TOOLCHAIN_LIBCXX}:" $1
}

export BAZEL_USE_CPP_ONLY_TOOLCHAIN=1

# Fallback to $CONDA_PREFIX if run outside of conda-build
export PREFIX=${PREFIX:-$CONDA_PREFIX}

# set up bazel config file for conda provided clang toolchain
cp -r ${RECIPE_DIR}/custom_toolchain .
pushd custom_toolchain
  if [[ "${target_platform}" == osx-* ]]; then
    export BAZEL_TOOLCHAIN_COMPILER_VERSION=$($CC -v 2>&1 | head -n1 | cut -d' ' -f3)
    export SHORT_BAZEL_TOOLCHAIN_COMPILER_VERSION=$(echo ${BAZEL_TOOLCHAIN_COMPILER_VERSION} | cut -d. -f1)
    sed -e "s:\${CLANG}:${CLANG}:" \
        -e "s:\${INSTALL_NAME_TOOL}:${INSTALL_NAME_TOOL}:" \
        -e "s:\${CONDA_BUILD_SYSROOT}:${CONDA_BUILD_SYSROOT}:" \
        -e "s:\${MACOSX_SDK_VERSION}:${MACOSX_SDK_VERSION:-}:" \
        -e "s:\${MACOSX_DEPLOYMENT_TARGET}:${MACOSX_DEPLOYMENT_TARGET:-}:" \
        cc_wrapper.sh.template > cc_wrapper.sh
    chmod +x cc_wrapper.sh
    sed -e "s:\${CLANG}:${CC_FOR_BUILD}:" \
        -e "s:\${INSTALL_NAME_TOOL}:${INSTALL_NAME_TOOL//${HOST}/${BUILD}}:" \
        -e "s:\${CONDA_BUILD_SYSROOT}:${CONDA_BUILD_SYSROOT}:" \
        -e "s:\${MACOSX_SDK_VERSION}:${MACOSX_SDK_VERSION:-}:" \
        -e "s:\${MACOSX_DEPLOYMENT_TARGET}:${MACOSX_DEPLOYMENT_TARGET:-}:" \
        cc_wrapper.sh.template > cc_wrapper_build.sh
    chmod +x cc_wrapper_build.sh
    export BAZEL_TOOLCHAIN_GCC="cc_wrapper.sh"
    export BAZEL_TOOLCHAIN_LIBCXX="c++"
    export BAZEL_TOOLCHAIN_AR=${LIBTOOL}
  else
    export BAZEL_TOOLCHAIN_COMPILER_VERSION=$(${CC} -v 2>&1|tail -n1|cut -d' ' -f3)
    export SHORT_BAZEL_TOOLCHAIN_COMPILER_VERSION=${BAZEL_TOOLCHAIN_COMPILER_VERSION}
    export BAZEL_TOOLCHAIN_AR=$(basename ${AR})
    touch cc_wrapper.sh
    touch cc_wrapper_build.sh
    export BAZEL_TOOLCHAIN_LIBCXX="stdc++"
    export BAZEL_TOOLCHAIN_GCC="${GCC}"
    # for NVCC we need to use a crosstool wrapper
    if [[ "${cuda_compiler_version:-None}" != "None" ]]; then
      export BAZEL_TOOLCHAIN_GCC=crosstool_wrapper_driver_is_not_gcc
    fi
  fi

  # For the platform values see https://github.com/bazelbuild/platforms/tree/main
  export TARGET_SYSTEM="${HOST}"
  if [[ "${target_platform}" == "osx-64" ]]; then
    export TARGET_LIBC="macosx"
    export TARGET_CPU="darwin_x86_64"
    export TARGET_SYSTEM="x86_64-apple-macosx"
    export TARGET_PLATFORM_OS="macos"
    export TARGET_PLATFORM_CPU="x86_64"
  elif [[ "${target_platform}" == "osx-arm64" ]]; then
    export TARGET_LIBC="macosx"
    export TARGET_CPU="darwin_arm64"
    export TARGET_SYSTEM="arm64-apple-macosx"
    export TARGET_PLATFORM_OS="macos"
    export TARGET_PLATFORM_CPU="arm64"
  elif [[ "${target_platform}" == "linux-64" ]]; then
    export TARGET_LIBC="unknown"
    export TARGET_CPU="k8"
    export TARGET_PLATFORM_OS="linux"
    export TARGET_PLATFORM_CPU="x86_64"
  elif [[ "${target_platform}" == "linux-aarch64" ]]; then
    export TARGET_LIBC="unknown"
    export TARGET_CPU="aarch64"
    export TARGET_PLATFORM_OS="linux"
    export TARGET_PLATFORM_CPU="aarch64"
  elif [[ "${target_platform}" == "linux-ppc64le" ]]; then
    export TARGET_LIBC="unknown"
    export TARGET_CPU="ppc"
    export TARGET_PLATFORM_OS="linux"
    export TARGET_PLATFORM_CPU="ppc64le"
  fi
  export BUILD_SYSTEM=${BUILD}
  if [[ "${build_platform}" == "osx-64" ]]; then
    export BUILD_CPU="darwin"
    export BUILD_SYSTEM="x86_64-apple-macosx"
    export BUILD_PLATFORM_OS="macos"
    export BUILD_PLATFORM_CPU="x86_64"
  elif [[ "${build_platform}" == "osx-arm64" ]]; then
    export BUILD_CPU="darwin"
    export BUILD_SYSTEM="arm64-apple-macosx"
    export BUILD_PLATFORM_OS="macos"
    export BUILD_PLATFORM_CPU="arm64"
  elif [[ "${build_platform}" == "linux-64" ]]; then
    export BUILD_CPU="k8"
    export BUILD_PLATFORM_OS="linux"
    export BUILD_PLATFORM_CPU="x86_64"
  elif [[ "${build_platform}" == "linux-aarch64" ]]; then
    export BUILD_CPU="aarch64"
    export BUILD_PLATFORM_OS="linux"
    export BUILD_PLATFORM_CPU="aarch64"
  elif [[ "${build_platform}" == "linux-ppc64le" ]]; then
    export BUILD_CPU="ppc"
    export BUILD_PLATFORM_OS="linux"
    export BUILD_PLATFORM_CPU="ppc64le"
  fi
  # The current Bazel release cannot distinguish between osx-arm64 and osx-64.
  # This will change with later releases and then we should get rid of this section again.
  #if [[ "${target_platform}" == osx-* ]]; then
  #  if [[ "${build_platform}" == "${target_platform}" ]]; then
  #    export TARGET_CPU="darwin"
  #    export BUILD_CPU="darwin"
  #  fi
  #fi
  
  sed -ie "s:TARGET_CPU:${TARGET_CPU}:" BUILD
  sed -ie "s:BUILD_CPU:${BUILD_CPU}:" BUILD
  sed -ie "s:BUILD_PLATFORM_OS:${BUILD_PLATFORM_OS}:" BUILD
  sed -ie "s:BUILD_PLATFORM_CPU:${BUILD_PLATFORM_CPU}:" BUILD
  sed -ie "s:TARGET_PLATFORM_OS:${TARGET_PLATFORM_OS}:" BUILD
  sed -ie "s:TARGET_PLATFORM_CPU:${TARGET_PLATFORM_CPU}:" BUILD

  HOST_PREFIX=${PREFIX}

  cp cc_toolchain_config.bzl cc_toolchain_build_config.bzl
  apply_cc_template cc_toolchain_config.bzl
  apply_cc_template crosstool_wrapper_driver_is_not_gcc
  (
    if [[ "${build_platform}" != "${target_platform}" ]]; then
      if [[ "${target_platform}" == osx-* ]]; then
        BAZEL_TOOLCHAIN_GCC=cc_wrapper_build.sh
      else
        BAZEL_TOOLCHAIN_GCC=${BAZEL_TOOLCHAIN_GCC//${HOST}/${BUILD}}
      fi
      TARGET_CPU=${BUILD_CPU}
      TARGET_SYSTEM=${BUILD_SYSTEM}
      target_platform=${build_platform}
      PREFIX=${CONDA_PREFIX}
      LD=${LD//${HOST}/${BUILD}}
      CFLAGS=${CFLAGS//${HOST_PREFIX}/${CONDA_PREFIX}}
      CPPFLAGS=${CPPFLAGS//${HOST_PREFIX}/${CONDA_PREFIX}}
      CXXFLAGS=${CXXFLAGS//${HOST_PREFIX}/${CONDA_PREFIX}}
      CONDA_BUILD_SYSROOT=${CONDA_BUILD_SYSROOT//${HOST}/${BUILD}}
      LDFLAGS=${LDFLAGS//${HOST_PREFIX}/${CONDA_PREFIX}}
      NM=${NM//${HOST}/${BUILD}}
      STRIP=${STRIP//${HOST}/${BUILD}}
      BAZEL_TOOLCHAIN_AR=${BAZEL_TOOLCHAIN_AR//${HOST}/${BUILD}}
      HOST=${BUILD}
    fi
    apply_cc_template cc_toolchain_build_config.bzl
  )
popd
