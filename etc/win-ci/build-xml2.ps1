param(
    [Parameter(Mandatory)] [string] $BuildTree,
    [Parameter(Mandatory)] [string] $Version,
    [switch] $Dynamic
)

. "$(Split-Path -Parent $MyInvocation.MyCommand.Path)\setup.ps1"

[void](New-Item -Name (Split-Path -Parent $BuildTree) -ItemType Directory -Force)
Setup-Git -Path $BuildTree -Url https://gitlab.gnome.org/GNOME/libxml2.git -Ref v$Version

Run-InDirectory $BuildTree {
    $args = "-DLIBXML2_WITH_TESTS=OFF -DLIBXML2_WITH_PROGRAMS=OFF -DLIBXML2_WITH_HTTP=OFF -DLIBXML2_WITH_FTP=OFF -DLIBXML2_WITH_ICONV=OFF -DLIBXML2_WITH_LZMA=OFF -DLIBXML2_WITH_PYTHON=OFF -DLIBXML2_WITH_ZLIB=OFF -DCMAKE_FIND_USE_SYSTEM_ENVIRONMENT_PATH=OFF"
    if ($Dynamic) {
        $args = "-DBUILD_SHARED_LIBS=ON $args"
    } else {
        $args = "-DBUILD_SHARED_LIBS=OFF -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded $args"
    }
    & $cmake . $args.split(' ')
    & $cmake --build . --config Release
    if (-not $?) {
        Write-Host "Error: Failed to build libxml2" -ForegroundColor Red
        Exit 1
    }
}

if ($Dynamic) {
    mv -Force $BuildTree\Release\libxml2.lib libs\xml2-dynamic.lib
    mv -Force $BuildTree\Release\libxml2.dll dlls\
} else {
    mv -Force $BuildTree\Release\libxml2s.lib libs\xml2.lib
}
