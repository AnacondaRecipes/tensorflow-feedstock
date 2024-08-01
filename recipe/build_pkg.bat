:: install the whl using pip
pip install --no-deps %SRC_DIR%\\tensorflow_pkg\\*.whl

:: The tensorboard package has the proper entrypoint
rm -f %LIBRARY_BIN%\\tensorboard
