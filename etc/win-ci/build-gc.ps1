param(
    [Parameter(Mandatory)] [string] $BuildTree,
    [Parameter(Mandatory)] [string] $Version,
    [Parameter(Mandatory)] [string] $AtomicOpsVersion,
    [ValidateSet("Release", "Debug")] [string] $Config = "Release",
    [switch] $Dynamic
)

. "$(Split-Path -Parent $MyInvocation.MyCommand.Path)\setup.ps1"

[void](New-Item -Name (Split-Path -Parent $BuildTree) -ItemType Directory -Force)
Setup-Git -Path $BuildTree -Url https://github.com/ivmai/bdwgc.git -Ref v$Version
Setup-Git -Path $BuildTree\libatomic_ops -Url https://github.com/ivmai/libatomic_ops.git -Ref v$AtomicOpsVersion

Run-InDirectory $BuildTree {
    $args = "-Dbuild_cord=OFF -Denable_large_config=ON -DCMAKE_POLICY_DEFAULT_CMP0091=NEW -DCMAKE_FIND_USE_SYSTEM_ENVIRONMENT_PATH=OFF"
    if ($Dynamic) {
        $args = "-DBUILD_SHARED_LIBS=ON $args"
    } else {
        $args = "-DBUILD_SHARED_LIBS=OFF -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded $args"
    }
    if ($Config -eq "Debug") {
        $args = "-DCMAKE_SHARED_LINKER_FLAGS=/PDBALTPATH:gc.pdb -DCMAKE_MSVC_DEBUG_INFORMATION_FORMAT=Embedded -DCMAKE_POLICY_DEFAULT_CMP0141=NEW $args"
    }
    & $cmake . $args.split(' ')
    & $cmake --build . --config $Config
    if (-not $?) {
        Write-Host "Error: Failed to build libgc" -ForegroundColor Red
        Exit 1
    }
}

if ($Dynamic) {
    mv -Force $BuildTree\$Config\gc.lib libs\gc-dynamic.lib
    mv -Force $BuildTree\$Config\gc.dll dlls\
    if ($Config -eq "Debug") {
        mv -Force $BuildTree\$Config\gc.pdb dlls\
    }
} else {
    mv -Force $BuildTree\$Config\gc.lib libs\
}
