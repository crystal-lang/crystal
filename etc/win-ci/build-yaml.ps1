param(
    [Parameter(Mandatory)] [string] $BuildTree,
    [Parameter(Mandatory)] [string] $Version,
    [switch] $Dynamic
)

. "$(Split-Path -Parent $MyInvocation.MyCommand.Path)\setup.ps1"

[void](New-Item -Name (Split-Path -Parent $BuildTree) -ItemType Directory -Force)
Setup-Git -Path $BuildTree -Url https://github.com/yaml/libyaml.git -Ref $Version

Run-InDirectory $BuildTree {
    $args = "-DBUILD_TESTING=OFF -DCMAKE_POLICY_DEFAULT_CMP0091=NEW -DCMAKE_FIND_USE_SYSTEM_ENVIRONMENT_PATH=OFF"
    if ($Dynamic) {
        $args = "-DBUILD_SHARED_LIBS=ON $args"
    } else {
        $args = "-DBUILD_SHARED_LIBS=OFF -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded $args"
    }
    & $cmake . $args.split(' ')
    & $cmake --build . --config Release
    if (-not $?) {
        Write-Host "Error: Failed to build libyaml" -ForegroundColor Red
        Exit 1
    }
}

if ($Dynamic) {
    mv -Force $BuildTree\Release\yaml.lib libs\yaml-dynamic.lib
    mv -Force $BuildTree\Release\yaml.dll dlls\
} else {
    mv -Force $BuildTree\Release\yaml.lib libs\
}
