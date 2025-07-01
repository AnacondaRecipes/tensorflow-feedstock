@echo off
setlocal enabledelayedexpansion

:: Extract the vendored protobuf headers directly from the wheel to SRC_DIR for separate packaging
echo Extracting vendored protobuf headers from TensorFlow wheel
if not exist "%SRC_DIR%\tensorflow_protobuf_headers" mkdir "%SRC_DIR%\tensorflow_protobuf_headers"
cd /d "%SRC_DIR%\tensorflow_protobuf_headers"

:: Find the actual wheel file (Windows doesn't expand wildcards automatically)
for %%f in ("%SRC_DIR%\tensorflow_pkg\*.whl") do (
    set "WHEEL_FILE=%%f"
    goto :found_wheel
)
echo ERROR: No wheel file found in %SRC_DIR%\tensorflow_pkg\
exit 1

:found_wheel
echo Found wheel file: %WHEEL_FILE%
%PYTHON% -m zipfile -e "%WHEEL_FILE%" .
if exist "tensorflow\include\google" (
    move "tensorflow\include\google" ".\google"
    if errorlevel 1 exit 1
    rmdir /s /q tensorflow
    echo Protobuf headers extracted to %SRC_DIR%\tensorflow_protobuf_headers\google
) else (
    echo ERROR: No vendored protobuf headers found in wheel
    exit 1
)


:: Move the extracted protobuf headers from SRC_DIR to PREFIX/include
if exist "%SRC_DIR%\tensorflow_protobuf_headers\google" (
    echo Installing protobuf headers to %PREFIX%\include\google
    if not exist "%SP_DIR%\tensorflow\include" mkdir "%SP_DIR%\tensorflow\include"

    move "%SRC_DIR%\tensorflow_protobuf_headers\google" "%SP_DIR%\tensorflow\include\google"
    if errorlevel 1 exit 1
    echo Protobuf headers installed successfully
    
    :: List some files for verification
    dir "%PREFIX%\include\google\*.h" /S /B 2>nul | findstr /N "^" | findstr /R "^[1-9]:" || echo No header files found
) else (
    echo ERROR: No protobuf headers found in %SRC_DIR%\tensorflow_protobuf_headers\google
    echo Available contents in SRC_DIR:
    dir "%SRC_DIR%" 2>nul
    exit 1
)