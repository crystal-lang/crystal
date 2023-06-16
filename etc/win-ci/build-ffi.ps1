param(
    [Parameter(Mandatory)] [string] $BuildTree,
    [Parameter(Mandatory)] [string] $Version,
    [switch] $Dynamic
)

. "$(Split-Path -Parent $MyInvocation.MyCommand.Path)\setup.ps1"

[void](New-Item -Name (Split-Path -Parent $BuildTree) -ItemType Directory -Force)
Setup-Git -Path $BuildTree -Url https://github.com/winlibs/libffi.git -Ref libffi-$Version

Run-InDirectory $BuildTree {
    if ($Dynamic) {
        Replace-Text win32\vs16_x64\libffi\libffi.vcxproj 'StaticLibrary' 'DynamicLibrary'
    }

    echo '<Project>
        <PropertyGroup>
            <ForceImportAfterCppTargets>$(MsbuildThisFileDirectory)\Override.props</ForceImportAfterCppTargets>
        </PropertyGroup>
    </Project>' > 'Directory.Build.props'

    echo "<Project>
        <PropertyGroup>
            <WholeProgramOptimization>false</WholeProgramOptimization>
        </PropertyGroup>
        <ItemDefinitionGroup>
            <ClCompile>
                $(if ($Dynamic) {
                    '<PreprocessorDefinitions>FFI_BUILDING_DLL;%(PreprocessorDefinitions)</PreprocessorDefinitions>'
                } else {
                    '<RuntimeLibrary>MultiThreaded</RuntimeLibrary>'
                })
                <DebugInformationFormat>None</DebugInformationFormat>
                <WholeProgramOptimization>false</WholeProgramOptimization>
            </ClCompile>
            <Link>
                <GenerateDebugInformation>false</GenerateDebugInformation>
            </Link>
        </ItemDefinitionGroup>
    </Project>" > 'Override.props'

    MSBuild.exe /p:PlatformToolset=v143 /p:Platform=x64 /p:Configuration=Release win32\vs16_x64\libffi-msvc.sln -target:libffi:Rebuild
    if (-not $?) {
        Write-Host "Error: Failed to build libffi" -ForegroundColor Red
        Exit 1
    }
}

if ($Dynamic) {
    mv -Force $BuildTree\win32\vs16_x64\x64\Release\libffi.lib libs\ffi-dynamic.lib
    mv -Force $BuildTree\win32\vs16_x64\x64\Release\libffi.dll dlls\
} else {
    mv -Force $BuildTree\win32\vs16_x64\x64\Release\libffi.lib libs\ffi.lib
}
