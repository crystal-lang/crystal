$LLVM_CONFIG = $env:LLVM_CONFIG -or (Get-Command "llvm-config" -ErrorAction SilentlyContinue)

if (-not $LLVM_CONFIG) {
    $llvm_config_version = $(llvm-config --version 2>$null)
    $llvm_versions = Get-Content "$(Split-Path $MyInvocation.MyCommand.Path)/llvm-versions.txt"
    foreach ($version in $llvm_versions) {
        $LLVM_CONFIG = (Get-Command "llvm-config-$version" -ErrorAction SilentlyContinue).Path
        if (-not $LLVM_CONFIG) {
            $LLVM_CONFIG = (Get-Command "llvm-config${version.Split('.')[0]}" -ErrorAction SilentlyContinue).Path
        }
        if (-not $LLVM_CONFIG -and $llvm_config_version.StartsWith($version)) {
            $LLVM_CONFIG = (Get-Command "llvm-config" -ErrorAction SilentlyContinue).Path
        }
        if ($LLVM_CONFIG) {
            break
        }
    }
    if (-not $LLVM_CONFIG) {
        Write-Error "Error: Could not find location of llvm-config. Please specify path in environment variable LLVM_CONFIG."
        Write-Error "Supported LLVM versions: $($llvm_versions -replace '\.0','')"
        exit 1
    }
}
Write-Output $LLVM_CONFIG
