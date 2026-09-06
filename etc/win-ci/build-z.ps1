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
    if ([Version]$Version -lt [Version]"1.3.2") {
        if ($Dynamic) {
            $args = "-DBUILD_SHARED_LIBS=ON $args"
        } else {
            $args = "-DBUILD_SHARED_LIBS=OFF -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded $args"
        }
    } else {
        if ($Dynamic) {
            $args = "-DZLIB_BUILD_SHARED=ON -DZLIB_BUILD_STATIC=OFF $args"
        } else {
            $args = "-DZLIB_BUILD_SHARED=OFF -DZLIB_BUILD_STATIC=ON -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded $args"
        }
    }

    & $cmake . $args.split(' ')
    & $cmake --build . --target $(if ($Dynamic) { 'zlib' } else { 'zlibstatic' }) --config Release

    if (-not $?) {
        Write-Host "Error: Failed to build zlib" -ForegroundColor Red
        Exit 1
    }
}

if ([Version]$Version -lt [Version]"1.3.2") {
    if ($Dynamic) {
        mv -Force $BuildTree\Release\zlib.lib libs\z-dynamic.lib
        mv -Force $BuildTree\Release\zlib1.dll dlls\
    } else {
        mv -Force $BuildTree\Release\zlibstatic.lib libs\z.lib
    }
} else {
    if ($Dynamic) {
        mv -Force $BuildTree\Release\libz.lib libs\z-dynamic.lib
        mv -Force $BuildTree\Release\libz.dll dlls\
    } else {
        mv -Force $BuildTree\Release\libzs.lib libs\z.lib
    }
}
