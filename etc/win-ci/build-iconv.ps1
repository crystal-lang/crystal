param(
    [Parameter(Mandatory)] [string] $BuildTree,
    [Parameter(Mandatory)] [string] $Version,
    [switch] $Dynamic
)

. "$(Split-Path -Parent $MyInvocation.MyCommand.Path)\setup.ps1"

[void](New-Item -Name (Split-Path -Parent $BuildTree) -ItemType Directory -Force)
Invoke-WebRequest "https://ftp.gnu.org/pub/gnu/libiconv/libiconv-${Version}.tar.gz" -OutFile libiconv.tar.gz
tar -xzf libiconv.tar.gz
mv libiconv-* $BuildTree
rm libiconv.tar.gz

Run-InDirectory $BuildTree {
    $env:CHERE_INVOKING = 1
    & 'C:\cygwin64\bin\bash.exe' --login "$PSScriptRoot\cygwin-build-iconv.sh" "$Version" "$(if ($Dynamic) { 1 })"
    if (-not $?) {
        Write-Host "Error: Failed to build libiconv" -ForegroundColor Red
        Exit 1
    }
}

if ($Dynamic) {
    mv -Force $BuildTree\iconv\lib\iconv.dll.lib libs\iconv-dynamic.lib
    mv -Force $BuildTree\iconv\bin\iconv-2.dll dlls\
} else {
    mv -Force $BuildTree\iconv\lib\iconv.lib libs\
}
