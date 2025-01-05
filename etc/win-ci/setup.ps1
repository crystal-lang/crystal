function Run-InDirectory {
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [scriptblock] $ScriptBlock
    )

    [void](New-Item -Name $Path -ItemType Directory -Force)
    Push-Location $Path
    [Environment]::CurrentDirectory = (Get-Location -PSProvider FileSystem).ProviderPath
    try { & $ScriptBlock } finally {
        Pop-Location
        [Environment]::CurrentDirectory = (Get-Location -PSProvider FileSystem).ProviderPath
    }
}

function Find-Git {
    $Path = Get-Command "git" -CommandType Application -TotalCount 1 -ErrorAction SilentlyContinue
    if ($Path) { return $Path.Path }

    $Path = "$env:ProgramFiles\Git\cmd\git.exe"
    if (Test-Path -Path $Path -PathType Leaf) { return $Path }

    Write-Host "Error: Cannot locate Git executable" -ForegroundColor Red
    Exit 1
}

function Find-CMake {
    $Path = Get-Command "cmake" -CommandType Application -TotalCount 1 -ErrorAction SilentlyContinue
    if ($Path) { return $Path.Path }

    $Path = "$env:ProgramFiles\CMake\bin\cmake.exe"
    if (Test-Path -Path $Path -PathType Leaf) { return $Path }

    Write-Host "Error: Cannot locate CMake executable" -ForegroundColor Red
    Exit 1
}

function Setup-Git {
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [string] $Url,
        [string] $Ref = $null
    )

    if (-not (Test-Path $Path)) {
        $args = "clone", "--config", "core.autocrlf=false", $Url, $Path
        Write-Host "$git $args" -ForegroundColor Cyan
        & $git $args
        if (-not $?) {
            Write-Host "Error: Failed to clone Git repository" -ForegroundColor Red
            Exit 1
        }
    }

    if ($Ref) {
        Run-InDirectory $Path {
            Write-Host "$git checkout $Ref" -ForegroundColor Cyan
            & $git checkout $Ref
        }
    }
}

function Replace-Text {
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [string] $Pattern,
        [Parameter(Mandatory)] [AllowEmptyString()] [string] $Replacement
    )

    $content = [System.IO.File]::ReadAllText($Path).Replace($Pattern, $Replacement)
    [System.IO.File]::WriteAllText($Path, $content)
}

$git = Find-Git
$cmake = Find-CMake

[void](New-Item -Name libs -ItemType Directory -Force)
[void](New-Item -Name dlls -ItemType Directory -Force)
