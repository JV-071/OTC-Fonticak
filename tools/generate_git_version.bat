@echo off
set "GIT_BRANCH=unknown"
set "GIT_VERSION=1.0.0"
set "GIT_COMMITS=0"

WHERE git >nul 2>nul
IF %ERRORLEVEL% EQU 0 (
    IF EXIST "../.git" (
        FOR /F "tokens=*" %%i IN ('git rev-parse --abbrev-ref HEAD 2^>nul') DO set "GIT_BRANCH=%%i"
        FOR /F "tokens=*" %%i IN ('git describe --abbrev=0 --tag 2^>nul') DO set "GIT_VERSION=%%i"
        FOR /F "tokens=*" %%i IN ('git rev-list --count HEAD 2^>nul') DO set "GIT_COMMITS=%%i"
    )
)

> ../src/gitinfo.h echo #define GIT_BRANCH %GIT_BRANCH%
>> ../src/gitinfo.h echo #define GIT_VERSION %GIT_VERSION%
>> ../src/gitinfo.h echo #define GIT_COMMITS %GIT_COMMITS%