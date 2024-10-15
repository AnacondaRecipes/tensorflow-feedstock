@echo on

set "PATH=%CD%:%PATH%"
@REM set LIBDIR=%LIBRARY_BIN:\=/%
@REM set INCLUDEDIR=%LIBRARY_INC:\=/%
@REM set PROTOBUF_INCLUDE_PATH=%LIBRARY_INC:\=/%
set BAZEL_VS=C:/Program Files/Microsoft Visual Studio/2022/BuildTools 
set BAZEL_VC=C:/Program Files/Microsoft Visual Studio/2022/BuildTools/VC
set Bazel_LLVM=C:/Program Files/LLVM

:: do not build with MKL support
set TF_NEED_MKL=0
set BAZEL_MKL_OPT=

mkdir bazel_output_base
set BAZEL_OPTS=

:: the following arguments are useful for debugging
::    --logging=6
::    --subcommands
:: jobs can be used to limit parallel builds and reduce resource needs
::    --jobs=20
:: Set compiler and linker flags as bazel does not account for CFLAGS,
:: CXXFLAGS and LDFLAGS.
set BUILD_OPTS=^
 --config=win_clang

set TF_ENABLE_XLA=0
set BUILD_TARGET=//tensorflow/tools/pip_package:wheel //tensorflow:libtensorflow.so //tensorflow:libtensorflow_cc.so

@REM set TF_SYSTEM_LIBS=^
@REM   astor_archive^
@REM   astunparse_archive^
@REM   boringssl^
@REM   com_github_googlecloudplatform_google_cloud_cpp^
@REM   com_github_grpc_grpc^
@REM   com_google_absl^
@REM   com_google_protobuf^
@REM   curl^
@REM   cython^
@REM   dill_archive^
@REM   flatbuffers^
@REM   gast_archive^
@REM   gif^
@REM   icu^
@REM   libjpeg_turbo^
@REM   org_sqlite^
@REM   png^
@REM   pybind11^
@REM   snappy^
@REM   zlib^

:: Python settings
set PYTHON_BIN_PATH=%PYTHON%
set PYTHON_LIB_PATH=%SP_DIR%
set USE_DEFAULT_PYTHON_LIB_PATH=1
set TF_PYTHON_VERSION=%PY_VER%

:: additional settings
set CC_OPT_FLAGS="-march=nocona -mtune=haswell"
set TF_NEED_OPENCL=0
set TF_NEED_OPENCL_SYCL=0
set TF_NEED_COMPUTECPP=0
set TF_NEED_CUDA=0
set TF_CUDA_CLANG=0
set TF_NEED_TENSORRT=0
set TF_NEED_ROCM=0
set TF_NEED_MPI=0
set TF_DOWNLOAD_CLANG=0
set TF_SET_ANDROID_WORKSPACE=0
@REM TODO: we will want to eventually use clang.
set TF_NEED_CLANG=0 
set TF_OVERRIDE_EIGEN_STRONG_INLINE=0

bazel clean --expunge
bazel shutdown

call configure

:: build using bazel
bazel %BAZEL_OPTS% build %BUILD_OPTS% %BUILD_TARGET%

:: build a whl file
mkdir %SRC_DIR%\\tensorflow_pkg
bazel-bin\\tensorflow\\tools\\pip_package\\build_pip_package %SRC_DIR%\\tensorflow_pkg

