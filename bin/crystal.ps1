param(
    [Parameter(Position = 0, ValueFromRemainingArguments)] [string[]] $CrystalArgs
)

# https://www.powershellgallery.com/packages/PowerGit/0.6.1/Content/Functions%5CResolve-RealPath.ps1
function Resolve-RealPath {
    <#
        .SYNOPSIS
        Implementation of Unix realpath().

        .PARAMETER Path
        Must exist
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Position = 0, Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('FullName')]
        [string] $Path
    )

    if ($PSVersionTable.PSVersion.Major -lt 6 -or $IsWindows) {
        return [IO.Path]::GetFullPath($Path)
    }

    [string[]] $parts = ($Path.TrimStart([IO.Path]::DirectorySeparatorChar).Split([IO.Path]::DirectorySeparatorChar))
    [string] $realPath = ''
    foreach ($part in $parts) {
        $realPath += [string] ([IO.Path]::DirectorySeparatorChar + $part)
        $item = Get-Item $realPath
        if ($item.Target) {
            $realPath = $item.Target
        }
    }
    $realPath
}

# adopted from https://stackoverflow.com/a/15669365
function Write-StdErr {
<#
.SYNOPSIS
Writes text to stderr when running in a regular console window,
to the host''s error stream otherwise.

.DESCRIPTION
Writing to true stderr allows you to write a well-behaved CLI
as a PS script that can be invoked from a batch file, for instance.

Note that PS by default sends ALL its streams to *stdout* when invoked from
cmd.exe.
#>
    param(
        [Parameter(Mandatory)] [string] $Line,
        $ForegroundColor
    )
    if ($Host.Name -eq 'ConsoleHost') {
        if ($ForegroundColor) {
            [Console]::ForegroundColor = $ForegroundColor
        }
        [Console]::Error.WriteLine($Line)
        if ($ForegroundColor) {
            [Console]::ResetColor()
        }
    } else {
        [void] $host.ui.WriteErrorLine($Line)
    }
}

# https://stackoverflow.com/a/43030126
function Invoke-WithEnvironment {
<#
.SYNOPSIS
Invokes commands with a temporarily modified environment.

.DESCRIPTION
Modifies environment variables temporarily based on a hashtable of values,
invokes the specified script block, then restores the previous environment.

.PARAMETER Environment
A hashtable that defines the temporary environment-variable values.
Assign $null to (temporarily) remove an environment variable that is
currently set.

.PARAMETER ScriptBlock
The command(s) to execute with the temporarily modified environment.

.EXAMPLE
> Invoke-WithEnvironment @{ PORT=8080 } { node index.js }

Runs node with environment variable PORT temporarily set to 8080, with its
previous value, if any 
#>
    param(
        [Parameter(Mandatory)] [System.Collections.IDictionary] $Environment,
        [Parameter(Mandatory)] [scriptblock] $ScriptBlock
    )
    # Modify the environment based on the hashtable and save the original 
    # one for later restoration.
    $htOrgEnv = @{}
    foreach ($kv in $Environment.GetEnumerator()) {
        $htOrgEnv[$kv.Key] = (Get-Item -EA SilentlyContinue "env:$($kv.Key)").Value
        Set-Item "env:$($kv.Key)" $kv.Value
    }
    # Invoke the script block
    try {
        & $ScriptBlock
    } finally {
        # Restore the original environment.
        foreach ($kv in $Environment.GetEnumerator()) {
            # Note: setting an environment var. to $null or '' *removes* it.
            Set-Item "env:$($kv.Key)" $htOrgEnv[$kv.Key]
        }
    }
}

# Code ported from:
# https://source.dot.net/#System.Diagnostics.Process/System/Diagnostics/ProcessStartInfo.cs
# https://source.dot.net/#System.Diagnostics.Process/PasteArguments.cs
# Licensed to the .NET Foundation under one or more agreements.
# The .NET Foundation licenses this file to you under the MIT license.
function Append-Argument {
    param(
        [Parameter(Mandatory)] [Text.StringBuilder] $Builder,
        [Parameter(Mandatory)] [AllowEmptyString()] [string] $Arg
    )

    if (-not $Builder.Length -eq 0) {
        [void]$Builder.Append(' ')
    }

    # Parsing rules for non-argv[0] arguments:
    #   - Backslash is a normal character except followed by a quote.
    #   - 2N backslashes followed by a quote ==> N literal backslashes followed by unescaped quote
    #   - 2N+1 backslashes followed by a quote ==> N literal backslashes followed by a literal quote
    #   - Parsing stops at first whitespace outside of quoted region.
    #   - (post 2008 rule): A closing quote followed by another quote ==> literal quote, and parsing remains in quoting mode.
    if ((-not $Builder.Length -eq 0) -and (ContainsNoWhitespaceOrQuotes $Arg)) {
        # Simple case - no quoting or changes needed.
        [void]$Builder.Append($Arg)
    } else {
        [void]$Builder.Append('"')
        $idx = 0
        while ($idx -lt $Arg.Length) {
            $c = $Arg[$idx++]
            if ($c -eq '\') {
                $numBackSlash = 1
                while (($idx -lt $Arg.Length) -and ($Arg[$idx] -eq '\')) {
                    $idx++
                    $numBackslash++
                }

                if ($idx -eq $Arg.Length) {
                    # We'll emit an end quote after this so must double the number of backslashes.
                    [void]$Builder.Append('\', $numBackSlash * 2)
                } elseif ($Arg[$idx] -eq '"') {
                    # Backslashes will be followed by a quote. Must double the number of backslashes.
                    [void]$Builder.Append('\', $numBackSlash * 2 + 1)
                    [void]$Builder.Append('"')
                    $idx++
                } else {
                    # Backslash will not be followed by a quote, so emit as normal characters.
                    [void]$Builder.Append('\', $numBackSlash)
                }

                continue
            }

            if ($c -eq '"') {
                # Escape the quote so it appears as a literal. This also guarantees that we won't end up generating a closing quote followed
                # by another quote (which parses differently pre-2008 vs. post-2008.)
                [void]$Builder.Append('\')
                [void]$Builder.Append('"')
                continue
            }

            [void]$Builder.Append($c)
        }

        [void]$Builder.Append('"')
    }
}

function ContainsNoWhitespaceOrQuotes {
    param(
        [Parameter(Mandatory)] [AllowEmptyString()] [string] $s
    )

    for ($i = 0; $i -lt $s.Length; $i += 1) {
        $c = $s[$i]
        if ([char]::IsWhiteSpace($c) -or ($c -eq '"')) {
            return $False
        }
    }

    $True
}

function Build-Arguments {
    param(
        [Parameter(Mandatory)] [AllowEmptyString()] [AllowNull()] [string[]] $Args
    )

    if ($Args.count -eq 0) { return '' }

    $Builder = [Text.StringBuilder]::new()
    $Args | Foreach-Object { Append-Argument $Builder $_ }
    $Builder.ToString()
}

function Exec-Process {
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [AllowEmptyString()] [AllowNull()] [string[]] $Args
    )

    if ($Args[0] -eq '--%') {
        $null, $Args = $Args

        if ($Args) {
            $Process = Start-Process $Path -Argument $Args -NoNewWindow -PassThru
        } else {
            $Process = Start-Process $Path -NoNewWindow -PassThru
        }
    } else {
        # `Start-Process` simply joins all arguments without escaping and passes it to `ProcessStartInfo.Arguments`;
        # here we replicate the logic for `ProcessStartInfo.ArgumentList` on .NET 5 and above
        # See also: https://github.com/PowerShell/PowerShell/issues/14747
        # (note that we must nonetheless implement it by ourselves if we support Windows Powershell 5.1)
        $EscapedArgs = Build-Arguments $Args
        if ($EscapedArgs) {
            $Process = Start-Process $Path -ArgumentList $EscapedArgs -NoNewWindow -PassThru
        } else {
            $Process = Start-Process $Path -NoNewWindow -PassThru
        }
    }

    # workaround to obtain the exit status properly: https://stackoverflow.com/a/23797762
    $hnd = $Process.Handle
    Wait-Process -Id $Process.Id

    Exit $Process.ExitCode
}

$ScriptPath = Resolve-RealPath $PSCommandPath
$ScriptRoot = Split-Path -Path $ScriptPath -Parent
$CrystalRoot = Split-Path -Path $ScriptRoot -Parent
$CrystalDir = "$CrystalRoot\.build"

Invoke-WithEnvironment @{
    CRYSTAL_PATH = if ($env:CRYSTAL_PATH) { $env:CRYSTAL_PATH } else { "lib;$CrystalRoot\src" }
    CRYSTAL_HAS_WRAPPER = "true"
    CRYSTAL = if ($env:CRYSTAL) { $env:CRYSTAL } else { "crystal" }
    CRYSTAL_CONFIG_LIBRARY_PATH = $env:CRYSTAL_CONFIG_LIBRARY_PATH
    CRYSTAL_LIBRARY_PATH = $env:CRYSTAL_LIBRARY_PATH
} {
    if (!$env:CRYSTAL_PATH.Contains("$CrystalRoot\src")) {
        Write-StdErr "CRYSTAL_PATH env variable does not contain $CrystalRoot\src" -ForegroundColor DarkYellow
    }

    if (!$env:CRYSTAL_CONFIG_LIBRARY_PATH -or !$env:CRYSTAL_LIBRARY_PATH) {
        Invoke-WithEnvironment @{ PATH = $env:PATH.Split(';') -ne $ScriptRoot -ne "bin" -join ';' } {
            $CrystalInstalled = Get-Command "crystal" -CommandType ExternalScript, Application -ErrorAction SilentlyContinue
            $CrystalInstalledLibraryPath = if ($CrystalInstalled) { crystal env CRYSTAL_LIBRARY_PATH } else { $null }
            if (!$env:CRYSTAL_CONFIG_LIBRARY_PATH) { $env:CRYSTAL_CONFIG_LIBRARY_PATH = $CrystalInstalledLibraryPath }
            if (!$env:CRYSTAL_LIBRARY_PATH) { $env:CRYSTAL_LIBRARY_PATH = $CrystalInstalledLibraryPath }
        }
    }

    if (Test-Path -Path "$CrystalDir/crystal.exe" -PathType Leaf) {
        Write-StdErr "Using compiled compiler at $($CrystalDir.Replace($pwd, "."))\crystal.exe" -ForegroundColor DarkYellow
        Exec-Process "$CrystalDir/crystal.exe" $CrystalArgs
    } else {
        $CrystalCmd = Get-Command $env:CRYSTAL -CommandType ExternalScript, Application -ErrorAction SilentlyContinue
        if (!$CrystalCmd) {
            Write-StdErr 'You need to have a crystal executable in your path! or set CRYSTAL env variable' -ForegroundColor Red
            Exit 1
        } else {
            $CrystalInstalledDir = Split-Path -Path $CrystalCmd.Path -Parent
            if ($CrystalInstalledDir -eq $ScriptRoot -or $CrystalInstalledDir -eq "bin") {
                Invoke-WithEnvironment @{ PATH = $env:PATH.Split(';') -ne $ScriptRoot -ne "bin" -join ';' } {
                    Exec-Process $ScriptPath $CrystalArgs
                }
            } else {
                Exec-Process $CrystalCmd.Path $CrystalArgs
            }
        }
    }
}
