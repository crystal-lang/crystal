param(
    [Parameter(Mandatory)] [string] $BuildTree,
    [Parameter(Mandatory)] [string] $Version,
    [switch] $Dynamic
)

. "$(Split-Path -Parent $MyInvocation.MyCommand.Path)\setup.ps1"

[void](New-Item -Name (Split-Path -Parent $BuildTree) -ItemType Directory -Force)
Setup-Git -Path $BuildTree -Url https://github.com/openssl/openssl -Ref openssl-$Version

Run-InDirectory $BuildTree {
    Replace-Text Configurations\10-main.conf '/Zi /Fdossl_static.pdb' ''
    Replace-Text Configurations\10-main.conf '"/nologo /debug"' '"/nologo /debug:none"'

    if ($Dynamic) {
        perl Configure VC-WIN64A no-tests
    } else {
        perl Configure VC-WIN64A /MT -static no-tests
    }
    nmake
    if (-not $?) {
        Write-Host "Error: Failed to build OpenSSL" -ForegroundColor Red
        Exit 1
    }
}

if ($Dynamic) {
    $major = $Version -replace '\..*', ''
    mv -Force $BuildTree\libcrypto.lib libs\crypto-dynamic.lib
    mv -Force $BuildTree\libssl.lib libs\ssl-dynamic.lib
    mv -Force $BuildTree\libcrypto-$major-x64.dll dlls\
    mv -Force $BuildTree\libssl-$major-x64.dll dlls\
} else {
    mv -Force $BuildTree\libcrypto.lib libs\crypto.lib
    mv -Force $BuildTree\libssl.lib libs\ssl.lib
}
[IO.File]::WriteAllLines("libs\openssl_VERSION", $Version)
