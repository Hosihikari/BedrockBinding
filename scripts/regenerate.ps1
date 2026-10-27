param(
    [Parameter(Mandatory = $true)]
    [string]$Pdb,
    [Parameter(Mandatory = $true)]
    [string]$Exe,
    [string]$Elf = "",
    [string]$LeviLaminaRoot = "C:\Users\root\source\repos\hosihikari\LiteLoaderBDS",
    [string]$HeaderIr = "",
    [string]$Classes = "Actor,BlockPos,BlockSource,ChunkPos,ItemStack,ItemStackBase,Level,Vec3,AppPlatform,ServerInstance,Player,Mob,Dimension,Block,Item,ItemRegistryRef,Container",
    [string]$ClassesFile = "",
    [string]$Version = "1.21.3",
    [string]$Carrier = "BDS 1.21.3.01",
    [string]$TargetModule = "bedrock_server",
    [string]$GeneratorRoot = "",
    [string]$AbiRoot = "",
    [string]$Output = "artifacts/regenerated"
)

$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$Pdb = (Resolve-Path $Pdb).Path
$Exe = (Resolve-Path $Exe).Path
if (-not [string]::IsNullOrWhiteSpace($Elf)) {
    $Elf = (Resolve-Path $Elf).Path
}
if ([string]::IsNullOrWhiteSpace($GeneratorRoot)) {
    $GeneratorRoot = (Resolve-Path (Join-Path $RepoRoot "..\Binding.Generator")).Path
} else {
    $GeneratorRoot = (Resolve-Path $GeneratorRoot).Path
}
if ([string]::IsNullOrWhiteSpace($AbiRoot)) {
    $AbiRoot = (Resolve-Path (Join-Path $RepoRoot "..\Binding.Abi")).Path
} else {
    $AbiRoot = (Resolve-Path $AbiRoot).Path
}
$Output = if ([System.IO.Path]::IsPathRooted($Output)) { $Output } else { Join-Path $RepoRoot $Output }
if (-not [string]::IsNullOrWhiteSpace($ClassesFile)) {
    $ClassesFile = (Resolve-Path $ClassesFile).Path
    $Classes = (Get-Content $ClassesFile |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -ne "" -and -not $_.StartsWith("#") }) -join ","
}
# A reused header IR goes stale silently: the class list and the header list keep growing,
# and merging against a six-day-old IR binds almost nothing. Rebuild by default; pass
# -HeaderIr to reuse one on purpose.
if ([string]::IsNullOrWhiteSpace($HeaderIr)) {
    $HeaderIr = Join-Path $Output "header-ir"
    if (Test-Path (Join-Path $HeaderIr "ir-manifest.json")) {
        Remove-Item $HeaderIr -Recurse -Force
    }
} else {
    $HeaderIr = (Resolve-Path $HeaderIr).Path
}

$SymbolIr = Join-Path $Output "symbol-ir"
$MergedIr = Join-Path $Output "merged"
$Emitted = Join-Path $Output "emitted"
$AbiHeader = Join-Path $AbiRoot "native\hosihikari_abi.h"
if (-not (Test-Path $AbiHeader)) {
    throw "hosihikari_abi.h was not found under $AbiRoot."
}

# Past a few thousand names a comma-joined list overruns the 32,767-character Windows
# command line, so a file selection stays a file all the way down.
$symbolArguments = @{
    Pdb = $Pdb
    Exe = $Exe
    IrOutput = $SymbolIr
    NoPrototype = $true
    Version = $Version
    SkipBuild = $true
}
if (-not [string]::IsNullOrWhiteSpace($ClassesFile)) {
    $symbolArguments.ClassesFile = $ClassesFile
} else {
    $symbolArguments.Classes = @($Classes.Split(",") | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}
if (-not [string]::IsNullOrWhiteSpace($Elf)) {
    $symbolArguments.Elf = $Elf
}
& (Join-Path $GeneratorRoot "frontend\run-symbols.ps1") @symbolArguments

if (-not (Test-Path (Join-Path $HeaderIr "ir-manifest.json"))) {
    & (Join-Path $GeneratorRoot "frontend\run-levilamina-headers.ps1") `
        -LeviLaminaRoot $LeviLaminaRoot `
        -Output $HeaderIr `
        -SkipBuild
}

& python (Join-Path $GeneratorRoot "frontend\merge-symbol-ir.py") `
    --symbol $SymbolIr `
    --header $HeaderIr `
    --output $MergedIr `
    $(if ($ClassesFile) { @("--classes-file", $ClassesFile) } else { @("--classes", $Classes) })
if ($LASTEXITCODE -ne 0) { throw "merge-symbol-ir.py exited with $LASTEXITCODE" }

dotnet run --project (Join-Path $GeneratorRoot "src\Hosihikari.Bindings.Generator\Hosihikari.Bindings.Generator.csproj") -c Release -- `
    emit (Join-Path $MergedIr "ir-manifest.json") $MergedIr $Emitted `
    --abi-header $AbiHeader `
    --symbol-dispatch --target-module $TargetModule

$InteropTarget = Join-Path $RepoRoot "src\Hosihikari.Bindings.Bedrock.Interop\Generated"
$CoverageTarget = Join-Path $RepoRoot "coverage"
$Configurations = @("win-x64-server", "linux-x64-server")

if (Test-Path $InteropTarget) {
    Remove-Item $InteropTarget -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $InteropTarget | Out-Null
Copy-Item (Join-Path $Emitted "interop\bedrock\*") $InteropTarget -Recurse -Force

foreach ($Configuration in $Configurations) {
    $ShimSource = Join-Path $Emitted "shim\$Configuration\bedrock"
    if (-not (Test-Path $ShimSource)) {
        throw "The emitted shim is missing for $Configuration."
    }

    $ShimTarget = Join-Path $RepoRoot "native\BindingShim\generated\$Configuration\bedrock"
    if (Test-Path $ShimTarget) {
        Remove-Item $ShimTarget -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path $ShimTarget | Out-Null
    Copy-Item (Join-Path $ShimSource "*") $ShimTarget -Recurse -Force
}

New-Item -ItemType Directory -Force -Path $CoverageTarget | Out-Null
Copy-Item (Join-Path $Emitted "coverage\manifest.jsonl") $CoverageTarget -Force
Copy-Item (Join-Path $Emitted "coverage\summary.json") $CoverageTarget -Force

$Summary = Get-Content (Join-Path $CoverageTarget "summary.json") -Raw | ConvertFrom-Json
$Functions = (Select-String -Path (Join-Path $RepoRoot "native\BindingShim\generated\win-x64-server\bedrock\binding_table.h") -Pattern '\(\*hs_' -AllMatches).Count
foreach ($Configuration in $Configurations) {
    $Header = Join-Path $RepoRoot "native\BindingShim\generated\$Configuration\bedrock\binding_table.h"
    $ConfigurationFunctions = (Select-String -Path $Header -Pattern '\(\*hs_' -AllMatches).Count
    if ($ConfigurationFunctions -ne $Functions) {
        throw "The $Configuration shim has $ConfigurationFunctions functions, expected $Functions."
    }
}

function Get-Sha256([string]$Path) {
    return (Get-FileHash $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

$GeneratorVersion = (& dotnet run --project (Join-Path $GeneratorRoot "src\Hosihikari.Bindings.Generator\Hosihikari.Bindings.Generator.csproj") -c Release -- version).Trim()
$Provenance = [ordered]@{
    generator = $GeneratorVersion
    irVersion = $Summary.irVersion
    irManifestSha256 = $Summary.irManifestSha256
    coverageManifestSha256 = $Summary.manifestSha256
    carrier = $Carrier
    carrierPdbSha256 = "sha256:" + (Get-Sha256 $Pdb)
    carrierExeSha256 = "sha256:" + (Get-Sha256 $Exe)
    carrierElfSha256 = if ($Elf) { "sha256:" + (Get-Sha256 $Elf) } else { "" }
    surface = "bedrock"
    configurations = $Summary.configurations
    mode = "symbol-dispatch"
    targetModule = $TargetModule
    tableVersion = 1
    functions = $Functions
}
[System.IO.File]::WriteAllText(
    (Join-Path $CoverageTarget "provenance.json"),
    ($Provenance | ConvertTo-Json),
    (New-Object System.Text.UTF8Encoding($false)))

$BaselinePath = Join-Path $CoverageTarget "baseline.json"
if (-not (Test-Path $BaselinePath)) {
    $Baseline = [ordered]@{
        irVersion = $Summary.irVersion
        configurations = $Summary.configurations
        declarationsBound = $Summary.declarations.bound
        membersBound = $Summary.members.bound
        functions = $Functions
    }
    [System.IO.File]::WriteAllText(
        $BaselinePath,
        ($Baseline | ConvertTo-Json),
        (New-Object System.Text.UTF8Encoding($false)))
} else {
    $Baseline = Get-Content $BaselinePath -Raw | ConvertFrom-Json
    if ($Summary.declarations.bound -lt $Baseline.declarationsBound -or
        $Summary.members.bound -lt $Baseline.membersBound -or
        $Functions -lt $Baseline.functions) {
        Write-Warning "Generated coverage is below coverage/baseline.json; review the change before updating the baseline."
    }
}

$HashFiles = @()
$HashFiles += Get-ChildItem $InteropTarget -Recurse -Filter "*.g.cs"
foreach ($Configuration in $Configurations) {
    $HashFiles += Get-ChildItem (Join-Path $RepoRoot "native\BindingShim\generated\$Configuration\bedrock") -File
}
$HashFiles += Get-Item (Join-Path $CoverageTarget "manifest.jsonl"), (Join-Path $CoverageTarget "summary.json")
$HashLines = foreach ($File in $HashFiles | Sort-Object FullName) {
    $Relative = $File.FullName.Substring($RepoRoot.Length + 1).Replace('\', '/')
    "$(Get-Sha256 $File.FullName)  $Relative"
}
[System.IO.File]::WriteAllText(
    (Join-Path $CoverageTarget "generated.sha256"),
    (($HashLines -join "`n") + "`n"),
    (New-Object System.Text.UTF8Encoding($false)))

Write-Output "Regenerated: $Functions functions in $($Configurations.Count) configurations, $($Summary.declarations.bound) bound declarations, $($Summary.members.bound) bound members."
Write-Output "Review the diff, then run scripts/verify_generated.py."
