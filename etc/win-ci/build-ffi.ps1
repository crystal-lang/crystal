param(
    [Parameter(Mandatory)] [string] $BuildTree,
    [Parameter(Mandatory)] [string] $Version,
    [switch] $Dynamic
)

. "$(Split-Path -Parent $MyInvocation.MyCommand.Path)\setup.ps1"

[void](New-Item -Name (Split-Path -Parent $BuildTree) -ItemType Directory -Force)
Invoke-WebRequest "https://github.com/libffi/libffi/releases/download/v${Version}/libffi-${Version}.tar.gz" -OutFile libffi.tar.gz
tar -xzf libffi.tar.gz
mv libffi-* $BuildTree
rm libffi.tar.gz

Run-InDirectory $BuildTree {
    $env:CHERE_INVOKING = 1

    & 'C:\cygwin64\bin\bash.exe' --login "$PSScriptRoot\cygwin-build-ffi.sh" "$(if ($Dynamic) { 1 })"
    if (-not $?) {
        Write-Host "Error: Failed to build libffi" -ForegroundColor Red
        Exit 1
    }
}

if ($Dynamic) {
    mv -Force $BuildTree\ffi\libffi.lib libs\ffi-dynamic.lib
    mv -Force $BuildTree\ffi\libffi-8.dll dlls\
} else {
    mv -Force $BuildTree\ffi\libffi.lib libs\ffi.lib
}
