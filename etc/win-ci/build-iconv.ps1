param(
    [Parameter(Mandatory)] [string] $BuildTree,
    [switch] $Dynamic
)

. "$(Split-Path -Parent $MyInvocation.MyCommand.Path)\setup.ps1"

[void](New-Item -Name (Split-Path -Parent $BuildTree) -ItemType Directory -Force)
Setup-Git -Path $BuildTree -Url https://github.com/pffang/libiconv-for-Windows.git -Ref 1353455a6c4e15c9db6865fd9c2bf7203b59c0ec # master@{2022-10-11}

Run-InDirectory $BuildTree {
    Replace-Text libiconv\include\iconv.h '__declspec (dllimport) ' ''

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
                <DebugInformationFormat>None</DebugInformationFormat>
                <WholeProgramOptimization>false</WholeProgramOptimization>
            </ClCompile>
            <Link>
                <GenerateDebugInformation>false</GenerateDebugInformation>
            </Link>
        </ItemDefinitionGroup>
        <ItemDefinitionGroup Condition=`"'`$(Configuration)'=='Release'`">
            <ClCompile>
                <RuntimeLibrary>MultiThreadedDLL</RuntimeLibrary>
            </ClCompile>
        </ItemDefinitionGroup>
    </Project>" > 'Override.props'

    if ($Dynamic) {
        MSBuild.exe /p:Platform=x64 /p:Configuration=Release libiconv.vcxproj
    } else {
        MSBuild.exe /p:Platform=x64 /p:Configuration=ReleaseStatic libiconv.vcxproj
    }
    if (-not $?) {
        Write-Host "Error: Failed to build libiconv" -ForegroundColor Red
        Exit 1
    }
}

if ($Dynamic) {
    mv -Force $BuildTree\output\x64\Release\libiconv.lib libs\iconv-dynamic.lib
    mv -Force $BuildTree\output\x64\Release\libiconv.dll dlls\
} else {
    mv -Force $BuildTree\output\x64\ReleaseStatic\libiconvStatic.lib libs\iconv.lib
}
