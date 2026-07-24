param(
    [Parameter(Mandatory)] [string] $BuildTree,
    [switch] $Dynamic
)

. "$(Split-Path -Parent $MyInvocation.MyCommand.Path)\setup.ps1"

[void](New-Item -Name (Split-Path -Parent $BuildTree) -ItemType Directory -Force)
Setup-Git -Path $BuildTree -Url https://github.com/HertzDevil/mpir.git -Ref c3578f8d4a863482a785480e14cbda7e236f194b # vs2026-arm64@{2026-07-24}
$arch = (Get-CimInstance Win32_operatingsystem).OSArchitecture
$platform = if ($arch -eq "ARM 64-bit Processor") { "ARM64" } else { "x64" }

Run-InDirectory $BuildTree {
    $vsVersion = "vs$((& "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" -property displayName) -replace '.*\b\d\d(\d\d)\b.*', '$1')"

    echo '<Project>
        <PropertyGroup>
            <ForceImportAfterCppTargets>$(MsbuildThisFileDirectory)\Override.props</ForceImportAfterCppTargets>
        </PropertyGroup>
    </Project>' > 'msvc\Directory.Build.props'

    echo '<Project>
        <ItemDefinitionGroup>
            <ClCompile>
                <DebugInformationFormat>None</DebugInformationFormat>
                <WholeProgramOptimization>false</WholeProgramOptimization>
            </ClCompile>
            <Link>
                <GenerateDebugInformation>false</GenerateDebugInformation>
            </Link>
        </ItemDefinitionGroup>
    </Project>' > 'msvc\Override.props'

    if ($Dynamic) {
        MSBuild.exe /p:Platform=$platform /p:Configuration=Release "msvc\$vsVersion\dll_mpir_gc\dll_mpir_gc.vcxproj"
    } else {
        MSBuild.exe /p:Platform=$platform /p:Configuration=Release "msvc\$vsVersion\lib_mpir_gc\lib_mpir_gc.vcxproj"
    }
    if (-not $?) {
        Write-Host "Error: Failed to build MPIR" -ForegroundColor Red
        Exit 1
    }
}

if ($Dynamic) {
    mv -Force $BuildTree\dll\$platform\Release\mpir.lib libs\mpir-dynamic.lib
    mv -Force $BuildTree\dll\$platform\Release\mpir.dll dlls\
} else {
    mv -Force $BuildTree\lib\$platform\Release\mpir.lib libs\
}
