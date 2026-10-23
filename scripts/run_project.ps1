# Ensure script runs from project root
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

Clear-Host

Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "       TIMETABLE FLUTTER RUN TOOL                " -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan

Write-Host ""
Write-Host "Platform:" -ForegroundColor Yellow
Write-Host "1. Android"
Write-Host "2. Windows (Desktop)"
Write-Host "3. Chrome (Web)"
Write-Host "4. iOS"
$platform = Read-Host "Select [1-4]"

$targetPlatform = ""
$deviceArg = ""

switch ($platform)
{
    "1" {
        $deviceArg = "-d android"
        Write-Host ""
        Write-Host "Target Architecture:" -ForegroundColor Yellow
        Write-Host "1. ARM64 (--target-platform android-arm64)"
        Write-Host "2. Universal (Default)"
        $arch = Read-Host "Select [1-2]"

        if ($arch -eq "1") {
            $targetPlatform = "--target-platform android-arm64"
        }
    }
    "2" {
        $deviceArg = "-d windows"
    }
    "3" {
        $deviceArg = "-d chrome"
    }
    "4" {
        $deviceArg = "-d ios"
    }
    Default {
        $deviceArg = ""
    }
}

Write-Host ""
Write-Host "IDE / Environment:" -ForegroundColor Yellow
Write-Host "1. VS Code"
Write-Host "2. Google Antigravity"
Write-Host "3. PowerShell / Terminal"
$ide = Read-Host "Select [1-3]"

Write-Host ""
Write-Host "Starting Flutter..." -ForegroundColor Green

$runCommand = "flutter run $deviceArg $targetPlatform".Trim()
Write-Host "Executing: $runCommand" -ForegroundColor DarkGray

if ($ide -eq "1")
{
    Invoke-Expression "$runCommand | findstr /V `"gralloc4`""
}
elseif ($ide -eq "2")
{
    flutter run $deviceArg $targetPlatform | Select-String -Pattern "gralloc4" -NotMatch
}
else
{
    Invoke-Expression $runCommand
}

Write-Host ""
Pause
