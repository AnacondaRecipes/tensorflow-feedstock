@echo off

@REM Ensure symlinks are allowed
echo test> symlink_test.txt
mklink symlink_test2.txt symlink_test.txt

IF %ERRORLEVEL% NEQ 0 (
    ECHO Enable Developer mode to enable symlinks %ERRORLEVEL%
    exit 1
)
rm -f symlink_test2.txt
rm -f symlink_test.txt

set "PATH=%CD%:%PATH%"
set BAZEL_VS="%VSINSTALLDIR%"
set BAZEL_VC="%VSINSTALLDIR%/VC"
set CLANG_COMPILER_PATH=%BUILD_PREFIX:\=/%/Library/bin/clang.exe
set BAZEL_LLVM=%BUILD_PREFIX:\=/%/Library/

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
 --keep_going^
 --define=no_tensorflow_py_deps=true^
 --config=win_clang

set TF_ENABLE_XLA=1
set BUILD_TARGET=//tensorflow/tools/pip_package:wheel --repo_env=WHEEL_NAME=tensorflow_cpu

@REM TF_SYSTEM_LIBS don't work on Windows: https://github.com/openxla/xla/blob/edf18ce242f234fbd20d1fbf4e9c96dfa5be2847/.bazelrc#L383
@REM set TF_SYSTEM_LIBS=

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
set TF_NEED_CLANG=1
set TF_OVERRIDE_EIGEN_STRONG_INLINE=0

bazel clean --expunge
bazel shutdown

call configure

ECHO build --features=layering_check>>.bazelrc
ECHO build --features=parse_headers>>.bazelrc
ECHO build --enable_runfiles>>.bazelrc

:: build using bazel
bazel %BAZEL_OPTS% build %BUILD_OPTS% %BUILD_TARGET%

:: build a whl file
mkdir %SRC_DIR%\\tensorflow_pkg
copy bazel-bin\\tensorflow\\tools\\pip_package\\wheel_house\\tensorflow*.whl %SRC_DIR%\\tensorflow_pkg

bazel clean --expunge
bazel shutdown