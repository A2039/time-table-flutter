# Ensure script runs from project root
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

Clear-Host

Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "       TIMETABLE FLUTTER RUN TOOL                " -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan

Write-Host ""
Write-Host "Platform:" -ForegroundColor Yellow
Write-Host "1. Android (Phone or Emulator)"
Write-Host "2. Windows (Desktop)"
Write-Host "3. Chrome (Web)"
Write-Host "4. iOS"
$platformInput = Read-Host "Select [1-4]"
$platform = if ($platformInput) { $platformInput.Trim() } else { "1" }

$deviceId = ""
$targetPlatform = ""

switch ($platform)
{
    "1" {
        Write-Host ""
        Write-Host "Detecting connected Android devices..." -ForegroundColor Gray
        try {
            $devicesJson = flutter devices --machine | ConvertFrom-Json -ErrorAction Stop
            $androidDevices = @($devicesJson | Where-Object { $_.targetPlatform -like "android*" })
        } catch {
            $androidDevices = @()
        }

        if ($androidDevices.Count -eq 1) {
            $selectedDev = $androidDevices[0]
            $deviceId = $selectedDev.id
            Write-Host "[OK] Found Android device: $($selectedDev.name) (ID: $($selectedDev.id))" -ForegroundColor Green
        }
        elseif ($androidDevices.Count -gt 1) {
            Write-Host ""
            Write-Host "Multiple Android devices detected:" -ForegroundColor Yellow
            for ($i = 0; $i -lt $androidDevices.Count; $i++) {
                $dev = $androidDevices[$i]
                Write-Host "$($i + 1). $($dev.name) [ID: $($dev.id), $($dev.sdk)]"
            }
            $devChoice = Read-Host "Select device [1-$($androidDevices.Count)] (Default: 1)"
            $idx = 0
            if ($devChoice -and [int]::TryParse($devChoice.Trim(), [ref]$idx) -and $idx -ge 1 -and $idx -le $androidDevices.Count) {
                $selectedDev = $androidDevices[$idx - 1]
            } else {
                $selectedDev = $androidDevices[0]
            }
            $deviceId = $selectedDev.id
            Write-Host "[OK] Using Android device: $($selectedDev.name) (ID: $($selectedDev.id))" -ForegroundColor Green
        }
        else {
            Write-Host "[INFO] No specific Android device ID queried, defaulting to 'android'" -ForegroundColor Yellow
            $deviceId = "android"
        }

        Write-Host ""
        Write-Host "Target Architecture:" -ForegroundColor Yellow
        Write-Host "1. ARM64 (--target-platform android-arm64)"
        Write-Host "2. Universal (Default)"
        $archInput = Read-Host "Select [1-2]"
        $arch = if ($archInput) { $archInput.Trim() } else { "2" }

        if ($arch -eq "1") {
            $targetPlatform = "android-arm64"
        }
    }
    "2" {
        $deviceId = "windows"
        Write-Host "[OK] Target: Windows Desktop" -ForegroundColor Green

        $sac = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\CI\Policy" -Name "VerifiedAndReputablePolicyState" -ErrorAction SilentlyContinue
        if ($sac -and $sac.VerifiedAndReputablePolicyState -eq 1) {
            Write-Host ""
            Write-Host "=================================================" -ForegroundColor Yellow
            Write-Host "[NOTICE] Windows Smart App Control (SAC) is Active" -ForegroundColor Yellow
            Write-Host "=================================================" -ForegroundColor Yellow
            Write-Host "Windows 11 Smart App Control automatically blocks newly compiled" -ForegroundColor Gray
            Write-Host "local binaries because they lack an external cloud reputation." -ForegroundColor Gray
            Write-Host "If execution is blocked, switch Smart App Control to 'Off' in:" -ForegroundColor Gray
            Write-Host "Windows Security -> App & browser control -> Smart App Control settings" -ForegroundColor Cyan
            Write-Host ""
        }
    }
    "3" {
        $deviceId = "chrome"
        Write-Host "[OK] Target: Google Chrome (Web)" -ForegroundColor Green
    }
    "4" {
        $deviceId = "ios"
        Write-Host "[OK] Target: iOS" -ForegroundColor Green
    }
    Default {
        $deviceId = "android"
    }
}

Write-Host ""
Write-Host "IDE / Environment:" -ForegroundColor Yellow
Write-Host "1. VS Code"
Write-Host "2. Google Antigravity / Android Studio"
Write-Host "3. PowerShell / Terminal"
$ideInput = Read-Host "Select [1-3]"
$ide = if ($ideInput) { $ideInput.Trim() } else { "2" }

Write-Host ""
Write-Host "Starting Flutter..." -ForegroundColor Green

# Construct arguments array for robust PowerShell splatting without string quoting/spacing issues
$flutterArgs = @("run")
if ($deviceId) {
    $flutterArgs += "-d"
    $flutterArgs += $deviceId
}
if ($targetPlatform) {
    $flutterArgs += "--target-platform"
    $flutterArgs += $targetPlatform
}

Write-Host "Executing: flutter $($flutterArgs -join ' ')" -ForegroundColor DarkGray
Write-Host ""
Write-Host "-------------------------------------------------" -ForegroundColor DarkGray
Write-Host "  Interactive Controls while running:" -ForegroundColor Yellow
Write-Host "    r : Hot reload changes" -ForegroundColor Cyan
Write-Host "    R : Hot restart application" -ForegroundColor Cyan
Write-Host "    v : Open Flutter DevTools in browser" -ForegroundColor Cyan
Write-Host "    q : Quit application" -ForegroundColor Cyan
Write-Host "-------------------------------------------------" -ForegroundColor DarkGray
Write-Host ""

# Direct execution preserving interactive terminal (stdin/stdout for hot reload)
& flutter @flutterArgs

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "[WARNING] Flutter run exited with code $LASTEXITCODE" -ForegroundColor Yellow

    if ($platform -eq "2") {
        $sac = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\CI\Policy" -Name "VerifiedAndReputablePolicyState" -ErrorAction SilentlyContinue
        if ($sac -and $sac.VerifiedAndReputablePolicyState -eq 1) {
            Write-Host ""
            Write-Host "=================================================" -ForegroundColor Yellow
            Write-Host "[FIX] Unblock Windows Desktop Local Executables   " -ForegroundColor Yellow
            Write-Host "=================================================" -ForegroundColor Yellow
            Write-Host "Smart App Control (SAC) blocked timetable_app.exe from launching." -ForegroundColor White
            Write-Host ""
            Write-Host "Would you like to open Windows Security to turn Smart App Control Off? [Y/N]" -ForegroundColor Cyan
            $openSec = Read-Host
            if ($openSec -and $openSec.Trim().ToUpper() -eq "Y") {
                Start-Process "windowsdefender://appbrowser"
                Write-Host "Opened Windows Security. Click 'Smart App Control settings' -> switch to 'Off'." -ForegroundColor Green
            }
        }
    }
}

Write-Host ""
Pause
