param(
    [string]$Configuration = "win-x64-server",
    [string]$Surface = "bedrock",
    [string]$ShimSource = "",
    [string]$Output = "artifacts/native/Hosihikari.Bindings.Bedrock.Shim.dll"
)

$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$Output = if ([System.IO.Path]::IsPathRooted($Output)) { $Output } else { Join-Path $RepoRoot $Output }
$ShimDirectory = Join-Path $PSScriptRoot "generated\$Configuration\$Surface"
if ([string]::IsNullOrWhiteSpace($ShimSource)) {
    $ShimSource = Join-Path $ShimDirectory "binding_table.cpp"
}
$ShimSource = (Resolve-Path $ShimSource).Path
if (-not (Test-Path (Join-Path $ShimDirectory "hosihikari_abi.h"))) {
    throw "Generated BindingShim sources are missing under $ShimDirectory."
}

$OutputDirectory = Split-Path $Output -Parent
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null

$VsWhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$VsRoot = & $VsWhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (-not $VsRoot) { throw "Visual Studio with the C++ toolchain was not found." }
$DevCmd = Join-Path $VsRoot "Common7\Tools\VsDevCmd.bat"

$CommandLine = "cl /nologo /std:c++20 /EHsc /MD /O2 /LD `"$ShimSource`" /I `"$ShimDirectory`" /Fo:`"$OutputDirectory\\`" /Fd:`"$OutputDirectory\\shim-cl.pdb`" /Fe:`"$Output`""
& cmd.exe /c "`"$DevCmd`" -arch=x64 -host_arch=x64 -no_logo >nul 2>&1 && $CommandLine"
if ($LASTEXITCODE -ne 0) { throw "MSVC command failed: $CommandLine" }

Write-Output "Built $Output"
