param(
    [Parameter(Mandatory = $true)][string]$Version,
    [Parameter(Mandatory = $true)][ValidateRange(1, 65535)][int]$BuildNumber,
    [string]$BuildDirectory = 'build/windows/x64/runner/Release',
    [string]$OutputDirectory = 'output/release',
    [string]$CompilerPath
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if ($Version -notmatch '^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$') {
    throw 'Version must be a semantic version, for example 0.1.0 or 0.2.0-beta.1.'
}
$versionParts = @([int]$Matches[1], [int]$Matches[2], [int]$Matches[3])
if ($versionParts | Where-Object { $_ -gt 65535 }) { throw 'Windows version components must not exceed 65535.' }
$windowsVersion = ($versionParts -join '.') + '.' + $BuildNumber
function Resolve-ProjectPath([string]$InputPath) {
    if ([IO.Path]::IsPathRooted($InputPath)) { return [IO.Path]::GetFullPath($InputPath) }
    return [IO.Path]::GetFullPath((Join-Path $projectRoot $InputPath))
}
$bundle = Resolve-ProjectPath $BuildDirectory
$destination = Resolve-ProjectPath $OutputDirectory
$required = @('minireel.exe', 'flutter_windows.dll', 'libmpv-2.dll', 'sqlite3.dll', 'msvcp140.dll', 'vcruntime140.dll', 'data/app.so', 'data/icudtl.dat', 'data/flutter_assets/assets/config/sources.json')
foreach ($relativePath in $required) {
    $requiredFile = Join-Path $bundle $relativePath
    if (!(Test-Path -LiteralPath $requiredFile -PathType Leaf)) { throw ('Incomplete Windows Release directory: missing ' + $relativePath) }
}

if (!$CompilerPath) {
    $candidates = @(
        (Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6/ISCC.exe'),
        (Join-Path $env:ProgramFiles 'Inno Setup 6/ISCC.exe')
    )
    $CompilerPath = $candidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
}
if (!$CompilerPath -or !(Test-Path -LiteralPath $CompilerPath -PathType Leaf)) {
    throw 'Inno Setup 6.3 or newer is required. Install Inno Setup or pass -CompilerPath.'
}
New-Item -ItemType Directory -Path $destination -Force | Out-Null
$arguments = @('/Qp', "/DAppVersion=$Version", "/DWindowsVersion=$windowsVersion", "/DBuildDir=$bundle", "/DOutputDir=$destination", (Join-Path $projectRoot 'installer/windows/minireel.iss'))
& $CompilerPath @arguments
if ($LASTEXITCODE -ne 0) { throw "Inno Setup compilation failed with exit code $LASTEXITCODE." }
$installer = Join-Path $destination "MiniReel-$Version-windows-x64-setup.exe"
if (!(Test-Path -LiteralPath $installer -PathType Leaf)) { throw 'The Windows installer was not generated.' }
Write-Output $installer
