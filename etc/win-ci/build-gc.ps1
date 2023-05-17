param(
    [Parameter(Mandatory)] [string] $Version,
    [switch] $Dynamic
)

. "$(Split-Path -Parent $MyInvocation.MyCommand.Path)\setup.ps1"

Setup-Git -Path deps\gc -Url https://github.com/ivmai/bdwgc.git -Branch v$Version
Setup-Git -Path deps\gc\libatomic_ops -Url https://github.com/ivmai/libatomic_ops.git -Branch v7.8.0

Run-InDirectory deps\gc {
    $args = "-Dbuild_cord=OFF -Denable_large_config=ON -DCMAKE_POLICY_DEFAULT_CMP0091=NEW -DCMAKE_FIND_USE_SYSTEM_ENVIRONMENT_PATH=OFF"
    if ($Dynamic) {
        $args = "-DBUILD_SHARED_LIBS=ON $args"
    } else {
        $args = "-DBUILD_SHARED_LIBS=OFF -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded $args"
    }
    & $cmake . $args.split(' ')
    & $cmake --build . --config Release
    if (-not $?) {
        Write-Host "Error: Failed to build libgc" -ForegroundColor Red
        Exit 1
    }
}

if ($Dynamic) {
    mv -Force deps\gc\Release\gc.lib libs\gc-dynamic.lib
    mv -Force deps\gc\Release\gc.dll dlls\
} else {
    mv -Force deps\gc\Release\gc.lib libs\
}

