param(
    [Parameter(Mandatory)] [string] $BuildTree,
    [Parameter(Mandatory)] [string] $Version,
    [switch] $Dynamic
)

function Find-7Zip {
    $Path = Get-Command "7z" -CommandType Application -TotalCount 1 -ErrorAction SilentlyContinue
    if ($Path) { return $Path.Path }

    $Path = "$env:ProgramFiles\7-Zip\7z.exe"
    if (Test-Path -Path $Path -PathType Leaf) { return $Path }

    $Path = "${env:ProgramFiles(x86)}\7-Zip\7z.exe"
    if (Test-Path -Path $Path -PathType Leaf) { return $Path }

    Write-Host "Error: Cannot locate 7-Zip executable" -ForegroundColor Red
    Exit 1
}

. "$(Split-Path -Parent $MyInvocation.MyCommand.Path)\setup.ps1"

[void](New-Item -Name (Split-Path -Parent $BuildTree) -ItemType Directory -Force)
Invoke-WebRequest https://cs.stanford.edu/pub/exim/pcre/pcre-$Version.zip -OutFile pcre.zip
& (Find-7Zip) x pcre.zip
mv pcre-* $BuildTree
rm pcre.zip

Run-InDirectory $BuildTree {
    $args = "-DPCRE_BUILD_PCREGREP=OFF -DPCRE_BUILD_TESTS=OFF -DPCRE_BUILD_PCRECPP=OFF -DPCRE_SUPPORT_JIT=ON -DPCRE_SUPPORT_UNICODE_PROPERTIES=ON -DCMAKE_FIND_USE_SYSTEM_ENVIRONMENT_PATH=OFF"
    if ($Dynamic) {
        $args = "-DBUILD_SHARED_LIBS=ON $args"
    } else {
        $args = "-DBUILD_SHARED_LIBS=OFF -DPCRE_STATIC_RUNTIME=ON $args"
    }
    & $cmake . $args.split(' ')
    & $cmake --build . --config Release
    if (-not $?) {
        Write-Host "Error: Failed to build PCRE" -ForegroundColor Red
        Exit 1
    }
}

if ($Dynamic) {
    mv -Force $BuildTree\Release\pcre.lib libs\pcre-dynamic.lib
    mv -Force $BuildTree\Release\pcre.dll dlls\
} else {
    mv -Force $BuildTree\Release\pcre.lib libs\
}
