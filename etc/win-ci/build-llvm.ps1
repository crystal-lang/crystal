param(
    [Parameter(Mandatory)] [string] $BuildTree,
    [Parameter(Mandatory)] [string] $Version,
    [Parameter(Mandatory)] [string[]] $TargetsToBuild,
    [switch] $Dynamic
)

if (-not $Dynamic) {
    Write-Host "Error: Building LLVM as a static library is not supported yet" -ForegroundColor Red
    Exit 1
}

. "$(Split-Path -Parent $MyInvocation.MyCommand.Path)\setup.ps1"

[void](New-Item -Name (Split-Path -Parent $BuildTree) -ItemType Directory -Force)
Setup-Git -Path $BuildTree -Url https://github.com/llvm/llvm-project.git -Ref llvmorg-$Version

Run-InDirectory $BuildTree\build {
    $args = "-Thost=x64 -DLLVM_TARGETS_TO_BUILD=$($TargetsToBuild -join ';') -DCMAKE_FIND_USE_SYSTEM_ENVIRONMENT_PATH=OFF -DLLVM_INCLUDE_BENCHMARKS=OFF -DLLVM_INCLUDE_DOCS=OFF -DLLVM_INCLUDE_TESTS=OFF -DLLVM_ENABLE_ZSTD=OFF"
    if ($Dynamic) {
        $args = "-DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreadedDLL $args"
    } else {
        $args = "-DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded -DLLVM_BUILD_LLVM_C_DYLIB=OFF $args"
    }
    & $cmake ..\llvm $args.split(' ')
    & $cmake --build . --config Release --target llvm-config --target LLVM-C
    if (-not $?) {
        Write-Host "Error: Failed to build LLVM" -ForegroundColor Red
        Exit 1
    }
}

if ($Dynamic) {
    mv -Force $BuildTree\build\Release\lib\LLVM-C.lib libs\llvm-dynamic.lib
    mv -Force $BuildTree\build\Release\bin\LLVM-C.dll dlls\
} else {
    # TODO (probably never)
}

Add-Content libs\llvm_VERSION $(& "$BuildTree\build\Release\bin\llvm-config.exe" --version)
Add-Content libs\llvm_VERSION $(& "$BuildTree\build\Release\bin\llvm-config.exe" --targets-built)
Add-Content libs\llvm_VERSION $(& "$BuildTree\build\Release\bin\llvm-config.exe" --system-libs)
