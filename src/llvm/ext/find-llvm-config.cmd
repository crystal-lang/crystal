
@echo off
setlocal

set LLVM_CONFIG=%LLVM_CONFIG%
set llvm_found=0

if not defined LLVM_CONFIG (
    for /f "tokens=*" %%i in ('where llvm-config') do (
        set llvm_config_path=%%i
        set llvm_found=1
        goto :found_llvm
    )
    for /f "tokens=*" %%i in ('llvm-config --version 2^>nul') do (
        set llvm_config_version=%%i
        for /f "tokens=*" %%j in ('type "%~dp0\llvm-versions.txt"') do (
            set version=%%j
            if "!llvm_config_version:%version%=!" neq "!llvm_config_version!" (
                for %%k in ("llvm-config-%%j" "llvm-config!version:~0,1!" "llvm-config!version:~0,3!" "llvm-config!version!") do (
                    for /f "tokens=*" %%l in ('where %%~k 2^>nul') do (
                        set llvm_config_path=%%l
                        set llvm_found=1
                        goto :found_llvm
                    )
                )
            )
        )
    )
)

:found_llvm
if %llvm_found% equ 1 (
    echo %llvm_config_path%
) else (
    echo Error: Could not find location of llvm-config. Please specify path in environment variable LLVM_CONFIG.
    set /p llvm_versions=<"%~dp0\llvm-versions.txt"
    echo Supported LLVM versions: %llvm_versions:.0=%
    exit /b 1
)
