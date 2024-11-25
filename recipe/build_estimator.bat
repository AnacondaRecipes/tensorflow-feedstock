@echo on

pushd tensorflow-estimator
set WHEEL_DIR=wheel_dir

mkdir "%WHEEL_DIR%"

bazel build tensorflow_estimator/tools/pip_package:build_pip_package
bazel-bin\\tensorflow_estimator\\tools\\pip_package\\build_pip_package %WHEEL_DIR%
python -m pip install --no-deps --no-build-isolation %WHEEL_DIR%\\*.whl
bazel clean --expunge
bazel shutdown
popd