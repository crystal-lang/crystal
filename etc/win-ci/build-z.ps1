param(
    [Parameter(Mandatory)] [string] $BuildTree,
    [Parameter(Mandatory)] [string] $Version,
    [switch] $Dynamic
)

. "$(Split-Path -Parent $MyInvocation.MyCommand.Path)\setup.ps1"

[void](New-Item -Name (Split-Path -Parent $BuildTree) -ItemType Directory -Force)
Setup-Git -Path $BuildTree -Url https://github.com/madler/zlib.git -Ref v$Version

Run-InDirectory $BuildTree {
    $args = "-DCMAKE_POLICY_DEFAULT_CMP0091=NEW -DCMAKE_FIND_USE_SYSTEM_ENVIRONMENT_PATH=OFF"
    if ($Dynamic) {
        $args = "-DBUILD_SHARED_LIBS=ON $args"
    } else {
        $args = "-DBUILD_SHARED_LIBS=OFF -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded $args"
    }
    & $cmake . $args.split(' ')
    & $cmake --build . --target $(if ($Dynamic) { 'zlib' } else { 'zlibstatic' }) --config Release
    if (-not $?) {
        Write-Host "Error: Failed to build zlib" -ForegroundColor Red
        Exit 1
    }
}

if ($Dynamic) {
    mv -Force $BuildTree\Release\zlib.lib libs\z-dynamic.lib
    mv -Force $BuildTree\Release\zlib1.dll dlls\
} else {
    mv -Force $BuildTree\Release\zlibstatic.lib libs\z.lib
}
