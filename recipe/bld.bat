@echo on

set "PATH=%CD%:%PATH%"
set LIBDIR=%LIBRARY_BIN%
set INCLUDEDIR=%LIBRARY_INC%

set "TF_SYSTEM_LIBS=llvm,swig"

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
 --copt=-march=nocona^
 --copt=-mtune=haswell^
 --copt=-ftree-vectorize^
 --copt=-fPIC^
 --copt=-fstack-protector-strong^
 --copt=-O2^
 --cxxopt=-fvisibility-inlines-hidden^
 --cxxopt=-fmessage-length=0^
 --linkopt=-zrelro^
 --linkopt=-znow^
 --linkopt=-L${PREFIX}/lib^
 --verbose_failures^
 --action_env="PYTHON_BIN_PATH=%PYTHON%"^
 --action_env="PYTHON_LIB_PATH=%SP_DIR%"^
 --python_path="%PYTHON%"^
 --define=PREFIX="%PREFIX%"^
 --define=LIBDIR="%PREFIX%/lib"^
 --define=INCLUDEDIR="%PREFIX%/include"^
 %BAZEL_MKL_OPT%^
 --config=opt

set TF_ENABLE_XLA=0
set BUILD_TARGET="//tensorflow/tools/pip_package:wheel //tensorflow:libtensorflow.so //tensorflow:libtensorflow_cc.so"

:: Python settings
set PYTHON_BIN_PATH=%PYTHON%
set PYTHON_LIB_PATH=%SP_DIR%
set USE_DEFAULT_PYTHON_LIB_PATH=1

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

