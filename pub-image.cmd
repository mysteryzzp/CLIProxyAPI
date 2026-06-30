@echo off
setlocal EnableExtensions

rem docker-build-push.cmd - Windows CMD multi-platform Docker build and push script.
rem Fill IMAGE_TAG with the remote image tag before running this script.

set "IMAGE_TAG=YOUR_REGISTRY/cli-proxy-api:latest"
set "PLATFORMS=linux/amd64,linux/arm64"
set "BUILDER_NAME=cli-proxy-api-builder"

if "%~1"=="--help" goto :usage
if "%~1"=="-h" goto :usage
if not "%~1"=="" (
    echo Error: unknown option "%~1".
    goto :usage_error
)

if "%IMAGE_TAG%"=="YOUR_REGISTRY/cli-proxy-api:latest" (
    echo Error: update IMAGE_TAG in %~nx0 before pushing.
    exit /b 1
)

call :require_command docker
if errorlevel 1 exit /b 1

call :require_command git
if errorlevel 1 exit /b 1

for /f "usebackq delims=" %%i in (`git describe --tags --always --dirty`) do set "VERSION=%%i"
for /f "usebackq delims=" %%i in (`git rev-parse --short HEAD`) do set "COMMIT=%%i"
for /f "usebackq delims=" %%i in (`powershell -NoProfile -Command "(Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')"`) do set "BUILD_DATE=%%i"

echo Building and pushing Docker image:
echo   Image:      %IMAGE_TAG%
echo   Platforms:  %PLATFORMS%
echo   Version:    %VERSION%
echo   Commit:     %COMMIT%
echo   Build Date: %BUILD_DATE%
echo ----------------------------------------

docker buildx inspect "%BUILDER_NAME%" >nul 2>nul
if errorlevel 1 (
    echo Creating Docker buildx builder "%BUILDER_NAME%"...
    docker buildx create --name "%BUILDER_NAME%" --driver docker-container --use
    if errorlevel 1 exit /b 1
) else (
    docker buildx use "%BUILDER_NAME%"
    if errorlevel 1 exit /b 1
)

docker buildx inspect --bootstrap
if errorlevel 1 exit /b 1

docker buildx build ^
    --platform "%PLATFORMS%" ^
    --file Dockerfile ^
    --build-arg "VERSION=%VERSION%" ^
    --build-arg "COMMIT=%COMMIT%" ^
    --build-arg "BUILD_DATE=%BUILD_DATE%" ^
    --tag "%IMAGE_TAG%" ^
    --push ^
    .
if errorlevel 1 exit /b 1

echo Docker image pushed successfully: %IMAGE_TAG%
exit /b 0

:require_command
where %1 >nul 2>nul
if errorlevel 1 (
    echo Error: required command "%1" was not found in PATH.
    exit /b 1
)
exit /b 0

:usage
echo Usage: %~nx0
echo.
echo Builds and pushes a multi-platform Docker image for linux/amd64 and linux/arm64.
echo Update IMAGE_TAG inside this script before running.
exit /b 0

:usage_error
echo Usage: %~nx0
exit /b 1
