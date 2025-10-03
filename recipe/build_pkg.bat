:: install the whl using pip
%PYTHON% -m pip install --find-links=%SRC_DIR%\\tensorflow_pkg tensorflow_cpu --no-build-isolation --no-deps

:: The tensorboard package has the proper entrypoint
del /f /q "%LIBRARY_BIN%\tensorboard"