param(
    [Parameter(Mandatory)] [string] $BuildTree,
    [switch] $Dynamic
)

. "$(Split-Path -Parent $MyInvocation.MyCommand.Path)\setup.ps1"

[void](New-Item -Name (Split-Path -Parent $BuildTree) -ItemType Directory -Force)
Setup-Git -Path $BuildTree -Url https://github.com/BrianGladman/mpir.git -Ref dc82b0475dea84d5338356e49176c40be03a5bdf # master@{2023-02-10}

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
        MSBuild.exe /p:Platform=x64 /p:Configuration=Release "msvc\$vsVersion\dll_mpir_gc\dll_mpir_gc.vcxproj"
    } else {
        MSBuild.exe /p:Platform=x64 /p:Configuration=Release "msvc\$vsVersion\lib_mpir_gc\lib_mpir_gc.vcxproj"
    }
    if (-not $?) {
        Write-Host "Error: Failed to build MPIR" -ForegroundColor Red
        Exit 1
    }
}

if ($Dynamic) {
    mv -Force $BuildTree\dll\x64\Release\mpir.lib libs\mpir-dynamic.lib
    mv -Force $BuildTree\dll\x64\Release\mpir.dll dlls\
} else {
    mv -Force $BuildTree\lib\x64\Release\mpir.lib libs\
}
