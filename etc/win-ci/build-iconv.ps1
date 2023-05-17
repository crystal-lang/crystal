param(
    [switch] $Dynamic
)

. "$(Split-Path -Parent $MyInvocation.MyCommand.Path)\setup.ps1"

Setup-Git -Path deps\iconv -Url https://github.com/pffang/libiconv-for-Windows.git -Commit 1353455a6c4e15c9db6865fd9c2bf7203b59c0ec # master@{2022-10-11}

Run-InDirectory deps\iconv {
    Replace-Text .\libiconv\include\iconv.h '__declspec (dllimport) ' ''

    echo "<Project>
        <PropertyGroup>
            <ForceImportAfterCppTargets>`$(MsbuildThisFileDirectory)\Override.props</ForceImportAfterCppTargets>
        </PropertyGroup>
    </Project>" > 'Directory.Build.props'

    echo "<Project>
        <ItemDefinitionGroup>
            <ClCompile>
                <DebugInformationFormat>None</DebugInformationFormat>
                <WholeProgramOptimization>false</WholeProgramOptimization>
            </ClCompile>
            <Link>
                <GenerateDebugInformation>false</GenerateDebugInformation>
            </Link>
        </ItemDefinitionGroup>
        <ItemDefinitionGroup Condition=`"'`$(Configuration)'=='ReleaseStatic'`">
            <ClCompile>
                <RuntimeLibrary>MultiThreaded</RuntimeLibrary>
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
    mv -Force deps\iconv\output\x64\Release\libiconv.lib libs\iconv-dynamic.lib
    mv -Force deps\iconv\output\x64\Release\libiconv.dll dlls\
} else {
    mv -Force deps\iconv\output\x64\ReleaseStatic\libiconvStatic.lib libs\iconv.lib
}
