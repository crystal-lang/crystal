param(
    [Parameter(Mandatory)] [string] $BuildTree,
    [Parameter(Mandatory)] [string] $Version,
    [switch] $Dynamic
)

. "$(Split-Path -Parent $MyInvocation.MyCommand.Path)\setup.ps1"

[void](New-Item -Name (Split-Path -Parent $BuildTree) -ItemType Directory -Force)
Setup-Git -Path $BuildTree -Url https://github.com/openssl/openssl -Ref openssl-$Version
$arch = (Get-CimInstance Win32_operatingsystem).OSArchitecture

Run-InDirectory $BuildTree {
    Replace-Text Configurations\10-main.conf '/Zi /Fdossl_static.pdb' ''
    Replace-Text Configurations\10-main.conf '"/nologo /debug"' '"/nologo /debug:none"'

    $platform = if ($arch -eq "ARM 64-bit Processor") { "VC-WIN64-ARM" } else { "VC-WIN64A" }

    if ($Dynamic) {
        perl Configure "$platform" no-tests
    } else {
        perl Configure "$platform" /MT -static no-tests
    }
    nmake
    if (-not $?) {
        Write-Host "Error: Failed to build OpenSSL" -ForegroundColor Red
        Exit 1
    }
}

if ($Dynamic) {
    $major = $Version -replace '\..*', ''
    $suffix = if ($arch -eq "ARM 64-bit Processor") { "arm64" } else { "x64" }
    mv -Force $BuildTree\libcrypto.lib libs\crypto-dynamic.lib
    mv -Force $BuildTree\libssl.lib libs\ssl-dynamic.lib
    mv -Force $BuildTree\libcrypto-$major-$suffix.dll dlls\
    mv -Force $BuildTree\libssl-$major-$suffix.dll dlls\
} else {
    mv -Force $BuildTree\libcrypto.lib libs\crypto.lib
    mv -Force $BuildTree\libssl.lib libs\ssl.lib
}
[IO.File]::WriteAllLines("libs\openssl_VERSION", $Version)
