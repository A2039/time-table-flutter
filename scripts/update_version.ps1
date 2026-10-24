<#
.SYNOPSIS
    Automated and Interactive Version Manager for Time Table Flutter Application.
.DESCRIPTION
    - Automatically increments Developer Version (Build Number / versionCode) on every build without prompting.
    - Interactively prompts the developer for Feature Version (L.M.S: Major, Minor, Patch) updates.
    - Synchronously updates 'pubspec.yaml', 'lib/config/app_config.json', and 'lib/core/config/app_config.dart'.
    - Displays version change summary to the developer/client before build execution.
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [ValidateSet("L", "M", "S", "None", "")]
    [string]$FeatureBump = "",

    [Parameter(Mandatory = $false)]
    [switch]$NonInteractive
)

# Resolve project root directory
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path (Join-Path $projectRoot "pubspec.yaml"))) {
    $projectRoot = (Get-Location).Path
}

$pubspecPath = Join-Path $projectRoot "pubspec.yaml"
$appConfigJsonPath = Join-Path $projectRoot "lib\config\app_config.json"
$appConfigDartPath = Join-Path $projectRoot "lib\core\config\app_config.dart"

if (-not (Test-Path $pubspecPath)) {
    Write-Host "[ERROR] pubspec.yaml not found at: $pubspecPath" -ForegroundColor Red
    exit 1
}

# Ensure lib/config/app_config.json exists
$configDir = Join-Path $projectRoot "lib\config"
if (-not (Test-Path $configDir)) {
    New-Item -ItemType Directory -Path $configDir -Force | Out-Null
}
if (-not (Test-Path $appConfigJsonPath)) {
    '{"version":"1.0.0","buildNumber":1}' | Set-Content -Path $appConfigJsonPath -Encoding utf8
}

# 1. Read and parse current version from pubspec.yaml (using UTF8 to preserve characters)
$pubspecContent = Get-Content -Path $pubspecPath -Raw -Encoding utf8
if ($pubspecContent -match '(?m)^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)') {
    $major = [int]$matches[1]
    $minor = [int]$matches[2]
    $patch = [int]$matches[3]
    $developerVersion = [int]$matches[4]
} else {
    Write-Host "[ERROR] Could not parse 'version: X.Y.Z+B' from pubspec.yaml!" -ForegroundColor Red
    exit 1
}

$oldFeatureVersion = "$major.$minor.$patch"
$oldDeveloperVersion = $developerVersion
$oldFullVersion = "$oldFeatureVersion+$oldDeveloperVersion"

# 2. Automatically increment developer version (Build Number / versionCode) on every build
$newDeveloperVersion = $oldDeveloperVersion + 1

# 3. Interactive prompt for Feature Version update (L, M, S)
Write-Host ""
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "         TIMETABLE VERSION MANAGER               " -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host " Current Version      : " -NoNewline -ForegroundColor White
Write-Host "$oldFullVersion" -ForegroundColor Yellow
Write-Host "   Feature Version    : $oldFeatureVersion (L.M.S -> Major.Minor.Patch)" -ForegroundColor Gray
Write-Host "   Developer Version  : +$oldDeveloperVersion (Build Number / versionCode)" -ForegroundColor Gray
Write-Host ""
Write-Host " [AUTO] Developer Version automatically incremented: " -NoNewline -ForegroundColor Green
Write-Host "+$newDeveloperVersion" -ForegroundColor Yellow
Write-Host ""

$newMajor = $major
$newMinor = $minor
$newPatch = $patch
$featureUpdated = $false
$bumpTypeLabel = "None (Unchanged)"

if ($NonInteractive) {
    if ($FeatureBump -eq "L") {
        $newMajor = $major + 1; $newMinor = 0; $newPatch = 0
        $featureUpdated = $true; $bumpTypeLabel = "Large (Major)"
    } elseif ($FeatureBump -eq "M") {
        $newMinor = $minor + 1; $newPatch = 0
        $featureUpdated = $true; $bumpTypeLabel = "Medium (Minor)"
    } elseif ($FeatureBump -eq "S") {
        $newPatch = $patch + 1
        $featureUpdated = $true; $bumpTypeLabel = "Small (Patch)"
    }
} else {
    # Ask developer whether to update feature version
    $promptAnswer = Read-Host "Do you want to update the feature version? (y/n)"
    if ($promptAnswer -match '^(y|yes)$') {
        $validChoice = $false
        while (-not $validChoice) {
            Write-Host ""
            Write-Host "Select Feature Version update type:" -ForegroundColor Yellow
            Write-Host "  [L] Large  (Major: $($major + 1).0.0)" -ForegroundColor White
            Write-Host "  [M] Medium (Minor: $major.$($minor + 1).0)" -ForegroundColor White
            Write-Host "  [S] Small  (Patch: $major.$minor.$($patch + 1))" -ForegroundColor White
            $versionChoice = (Read-Host "Enter choice [L/M/S]").Trim().ToUpper()

            switch ($versionChoice) {
                "L" {
                    $newMajor = $major + 1
                    $newMinor = 0
                    $newPatch = 0
                    $validChoice = $true
                    $featureUpdated = $true
                    $bumpTypeLabel = "Large (Major -> $newMajor.$newMinor.$newPatch)"
                }
                "M" {
                    $newMajor = $major
                    $newMinor = $minor + 1
                    $newPatch = 0
                    $validChoice = $true
                    $featureUpdated = $true
                    $bumpTypeLabel = "Medium (Minor -> $newMajor.$newMinor.$newPatch)"
                }
                "S" {
                    $newMajor = $major
                    $newMinor = $minor
                    $newPatch = $patch + 1
                    $validChoice = $true
                    $featureUpdated = $true
                    $bumpTypeLabel = "Small (Patch -> $newMajor.$newMinor.$newPatch)"
                }
                default {
                    Write-Host "[WARNING] Invalid selection '$versionChoice'. Please type L, M, or S." -ForegroundColor Red
                }
            }
        }
    } else {
        Write-Host "Skipping feature version update. Retaining feature version $oldFeatureVersion." -ForegroundColor DarkYellow
    }
}

$newFeatureVersion = "$newMajor.$newMinor.$newPatch"
$newFullVersion = "$newFeatureVersion+$newDeveloperVersion"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

# 4. Write updated version to pubspec.yaml
$updatedPubspec = $pubspecContent -replace '(?m)^version:\s*.*$', "version: $newFullVersion"
[System.IO.File]::WriteAllText($pubspecPath, $updatedPubspec, $utf8NoBom)

# 5. Write updated version to lib/config/app_config.json
$appConfigRaw = Get-Content -Path $appConfigJsonPath -Raw -Encoding utf8
$updatedAppConfig = $appConfigRaw -replace '"version"\s*:\s*"[^"]*"', "`"version`": `"$newFeatureVersion`""
$updatedAppConfig = $updatedAppConfig -replace '"buildNumber"\s*:\s*\d+', "`"buildNumber`": $newDeveloperVersion"
[System.IO.File]::WriteAllText($appConfigJsonPath, $updatedAppConfig, $utf8NoBom)

# 6. Write updated version to lib/core/config/app_config.dart if present
if (Test-Path $appConfigDartPath) {
    $dartConfigRaw = Get-Content -Path $appConfigDartPath -Raw -Encoding utf8
    $updatedDartConfig = $dartConfigRaw -replace "static (const )?String appVersion = '[^']*';", "static String appVersion = '$newFeatureVersion';"
    $updatedDartConfig = $updatedDartConfig -replace "static (const )?int appBuildNumber = \d+;", "static int appBuildNumber = $newDeveloperVersion;"
    [System.IO.File]::WriteAllText($appConfigDartPath, $updatedDartConfig, $utf8NoBom)
}

# 7. Display visual summary to developer / client
Write-Host ""
Write-Host "=================================================" -ForegroundColor Green
Write-Host "          VERSION UPDATE SUCCESSFUL              " -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor Green
Write-Host "  Previous Version : $oldFullVersion (Feature: $oldFeatureVersion | Developer Build: +$oldDeveloperVersion)" -ForegroundColor DarkGray
Write-Host "  New Version      : " -NoNewline -ForegroundColor White
Write-Host "$newFullVersion" -ForegroundColor Yellow
Write-Host "    - Feature (L.M.S) : $newFeatureVersion [$bumpTypeLabel]" -ForegroundColor White
Write-Host "    - Developer Build : +$newDeveloperVersion [Auto-Incremented]" -ForegroundColor White
Write-Host ""
Write-Host "  Updated Target Files:" -ForegroundColor Cyan
Write-Host "    [v] pubspec.yaml                   -> version: $newFullVersion" -ForegroundColor Gray
Write-Host "    [v] lib\config\app_config.json      -> version: `"$newFeatureVersion`", buildNumber: $newDeveloperVersion" -ForegroundColor Gray
if (Test-Path $appConfigDartPath) {
    Write-Host "    [v] lib\core\config\app_config.dart -> appVersion: '$newFeatureVersion', appBuildNumber: $newDeveloperVersion" -ForegroundColor Gray
}
Write-Host "=================================================" -ForegroundColor Green
Write-Host ""

# Export values for calling script
$env:TIMETABLE_NEW_FULL_VERSION = $newFullVersion
$env:TIMETABLE_NEW_FEATURE_VERSION = $newFeatureVersion
$env:TIMETABLE_NEW_BUILD_NUMBER = $newDeveloperVersion

exit 0
