param(
    [Parameter(Mandatory)] [string] $BuildTree,
    [Parameter(Mandatory)] [string] $Version,
    [switch] $Dynamic
)

. "$(Split-Path -Parent $MyInvocation.MyCommand.Path)\setup.ps1"

[void](New-Item -Name (Split-Path -Parent $BuildTree) -ItemType Directory -Force)
Setup-Git -Path $BuildTree -Url https://github.com/PCRE2Project/pcre2.git -Ref pcre2-$Version

Run-InDirectory $BuildTree {
    $args = "-DPCRE2_BUILD_PCRE2GREP=OFF -DPCRE2_BUILD_TESTS=OFF -DPCRE2_SUPPORT_UNICODE=ON -DPCRE2_SUPPORT_JIT=ON -DCMAKE_FIND_USE_SYSTEM_ENVIRONMENT_PATH=OFF"
    if ($Dynamic) {
        $args = "-DBUILD_STATIC_LIBS=OFF -DBUILD_SHARED_LIBS=ON $args"
    } else {
        $args = "-DBUILD_STATIC_LIBS=ON -DBUILD_SHARED_LIBS=OFF -DPCRE2_STATIC_RUNTIME=ON $args"
    }
    & $cmake . $args.split(' ')
    & $cmake --build . --config Release
    if (-not $?) {
        Write-Host "Error: Failed to build PCRE2" -ForegroundColor Red
        Exit 1
    }
}

if ($Dynamic) {
    mv -Force $BuildTree\Release\pcre2-8.lib libs\pcre2-8-dynamic.lib
    mv -Force $BuildTree\Release\pcre2-8.dll dlls\
} else {
    mv -Force $BuildTree\Release\pcre2-8-static.lib libs\pcre2-8.lib
}
