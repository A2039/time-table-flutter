# Ensure script runs from project root
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

Clear-Host

Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "       TIMETABLE FLUTTER BUILD TOOL              " -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan

Write-Host ""
Write-Host "Build Mode:" -ForegroundColor Yellow
Write-Host "1. Release (AAB - for Google Play)"
Write-Host "2. Debug (APK - for testing)"
Write-Host "3. Release (APK - for direct installation)"
$buildMode = Read-Host "Select [1-3]"

if ($buildMode -ne "1" -and $buildMode -ne "2" -and $buildMode -ne "3") {
    Write-Host "[ERROR] Invalid Build Mode selection. Exiting." -ForegroundColor Red
    Pause
    exit 1
}

Write-Host ""
Write-Host "Platform:" -ForegroundColor Yellow
Write-Host "1. Android"
Write-Host "2. iOS"
Write-Host "3. Windows (Desktop)"
Write-Host "4. Web"
$platform = Read-Host "Select [1-4]"

if ($platform -ne "1" -and $platform -ne "2" -and $platform -ne "3" -and $platform -ne "4") {
    Write-Host "[ERROR] Invalid Platform selection. Exiting." -ForegroundColor Red
    Pause
    exit 1
}

$arch = "1"
if ($platform -eq "1" -and $buildMode -eq "1") {
    Write-Host ""
    Write-Host "Target Architecture:" -ForegroundColor Yellow
    Write-Host "1. Universal AAB (Recommended for Google Play)"
    Write-Host "2. ARM64 AAB"
    $arch = Read-Host "Select [1-2]"
}

# ==============================================================================
# STEP 1: VERSION MANAGEMENT (Automatic Developer Version & Optional Feature Bump)
# ==============================================================================
Write-Host ""
Write-Host ">>> [1/4] Running Version Manager..." -ForegroundColor Cyan
$versionScript = Join-Path $PSScriptRoot "update_version.ps1"
if (-not (Test-Path $versionScript)) {
    Write-Host "[ERROR] update_version.ps1 not found at $versionScript" -ForegroundColor Red
    Pause
    exit 1
}

& $versionScript
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "[ERROR] Version update failed with exit code $LASTEXITCODE. Aborting build." -ForegroundColor Red
    Pause
    exit $LASTEXITCODE
}

# ==============================================================================
# STEP 2: CLEAN PROJECT
# ==============================================================================
Write-Host ""
Write-Host ">>> [2/4] Cleaning project (flutter clean)..." -ForegroundColor Cyan
flutter clean
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "[ERROR] flutter clean failed with exit code $LASTEXITCODE. Aborting build." -ForegroundColor Red
    Pause
    exit $LASTEXITCODE
}

# ==============================================================================
# STEP 3: RESOLVE DEPENDENCIES
# ==============================================================================
Write-Host ""
Write-Host ">>> [3/4] Resolving dependencies (flutter pub get)..." -ForegroundColor Cyan
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "[ERROR] flutter pub get failed with exit code $LASTEXITCODE. Aborting build." -ForegroundColor Red
    Pause
    exit $LASTEXITCODE
}

# ==============================================================================
# STEP 4: EXECUTE BUILD
# ==============================================================================
Write-Host ""
Write-Host ">>> [4/4] Starting compilation..." -ForegroundColor Cyan
$builtArtifactPath = $null

if ($platform -eq "1")
{
    if ($buildMode -eq "1")
    {
        # Check signing configuration
        $keyPropsFile = Join-Path $projectRoot "android\key.properties"
        if (-not (Test-Path $keyPropsFile)) {
            Write-Host "[WARNING] android/key.properties not found." -ForegroundColor Yellow
            Write-Host "Building release bundle with default credentials or project config." -ForegroundColor Gray
        }

        # Clear stale release bundle
        $aabPath = Join-Path $projectRoot "build\app\outputs\bundle\release\app-release.aab"
        if (Test-Path $aabPath) {
            Remove-Item $aabPath -Force -ErrorAction SilentlyContinue
        }

        Write-Host ""
        Write-Host "Building Release Android App Bundle (AAB)..." -ForegroundColor Green

        if ($arch -eq "2") {
            flutter build appbundle --release --target-platform android-arm64
        } else {
            flutter build appbundle --release
        }

        if ($LASTEXITCODE -ne 0) {
            Write-Host ""
            Write-Host "=================================================" -ForegroundColor Red
            Write-Host "[ERROR] Release build failed with exit code $LASTEXITCODE" -ForegroundColor Red
            Write-Host "=================================================" -ForegroundColor Red
            Pause
            exit $LASTEXITCODE
        }

        if (Test-Path $aabPath) {
            $builtArtifactPath = $aabPath
            $fileInfo = Get-Item $aabPath
            $sizeMb = [math]::Round($fileInfo.Length / 1MB, 2)
            Write-Host ""
            Write-Host "=================================================" -ForegroundColor Green
            Write-Host "BUILD SUCCEEDED!" -ForegroundColor Green
            Write-Host "Release Artifact : $aabPath" -ForegroundColor White
            Write-Host "File Size        : $sizeMb MB" -ForegroundColor White
            if ($env:TIMETABLE_NEW_FULL_VERSION) {
                Write-Host "Artifact Version : $env:TIMETABLE_NEW_FULL_VERSION" -ForegroundColor Yellow
            }
            Write-Host "Status           : Ready for Google Play Console upload." -ForegroundColor Green
            Write-Host "=================================================" -ForegroundColor Green
        } else {
            Write-Host ""
            Write-Host "[ERROR] Expected artifact not found at $aabPath" -ForegroundColor Red
            Pause
            exit 1
        }
    }
    elseif ($buildMode -eq "2")
    {
        Write-Host ""
        Write-Host "Building Debug APK..." -ForegroundColor Yellow
        flutter build apk --debug

        if ($LASTEXITCODE -ne 0) {
            Write-Host ""
            Write-Host "=================================================" -ForegroundColor Red
            Write-Host "[ERROR] Debug build failed with exit code $LASTEXITCODE" -ForegroundColor Red
            Write-Host "=================================================" -ForegroundColor Red
            Pause
            exit $LASTEXITCODE
        }

        $apkPath = Join-Path $projectRoot "build\app\outputs\flutter-apk\app-debug.apk"
        if (Test-Path $apkPath) {
            $builtArtifactPath = $apkPath
            $fileInfo = Get-Item $apkPath
            $sizeMb = [math]::Round($fileInfo.Length / 1MB, 2)
            Write-Host ""
            Write-Host "=================================================" -ForegroundColor Green
            Write-Host "DEBUG BUILD COMPLETED!" -ForegroundColor Green
            Write-Host "Artifact         : $apkPath" -ForegroundColor White
            Write-Host "File Size        : $sizeMb MB" -ForegroundColor White
            if ($env:TIMETABLE_NEW_FULL_VERSION) {
                Write-Host "Artifact Version : $env:TIMETABLE_NEW_FULL_VERSION" -ForegroundColor Yellow
            }
            Write-Host "=================================================" -ForegroundColor Green
        }
    }
    elseif ($buildMode -eq "3")
    {
        Write-Host ""
        Write-Host "Building Release APK..." -ForegroundColor Green
        flutter build apk --release

        if ($LASTEXITCODE -ne 0) {
            Write-Host ""
            Write-Host "=================================================" -ForegroundColor Red
            Write-Host "[ERROR] Release APK build failed with exit code $LASTEXITCODE" -ForegroundColor Red
            Write-Host "=================================================" -ForegroundColor Red
            Pause
            exit $LASTEXITCODE
        }

        $apkPath = Join-Path $projectRoot "build\app\outputs\flutter-apk\app-release.apk"
        if (Test-Path $apkPath) {
            $builtArtifactPath = $apkPath
            $fileInfo = Get-Item $apkPath
            $sizeMb = [math]::Round($fileInfo.Length / 1MB, 2)
            Write-Host ""
            Write-Host "=================================================" -ForegroundColor Green
            Write-Host "RELEASE APK COMPLETED!" -ForegroundColor Green
            Write-Host "Artifact         : $apkPath" -ForegroundColor White
            Write-Host "File Size        : $sizeMb MB" -ForegroundColor White
            if ($env:TIMETABLE_NEW_FULL_VERSION) {
                Write-Host "Artifact Version : $env:TIMETABLE_NEW_FULL_VERSION" -ForegroundColor Yellow
            }
            Write-Host "=================================================" -ForegroundColor Green
        }
    }
}
elseif ($platform -eq "2")
{
    Write-Host ""
    Write-Host "Building iOS Release..." -ForegroundColor Green
    flutter build ios --release
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "=================================================" -ForegroundColor Red
        Write-Host "[ERROR] iOS build failed with exit code $LASTEXITCODE" -ForegroundColor Red
        Write-Host "=================================================" -ForegroundColor Red
        Pause
        exit $LASTEXITCODE
    }
    Write-Host ""
    Write-Host "=================================================" -ForegroundColor Green
    Write-Host "iOS BUILD SUCCEEDED!" -ForegroundColor Green
    Write-Host "=================================================" -ForegroundColor Green
}
elseif ($platform -eq "3")
{
    Write-Host ""
    Write-Host "Building Windows Desktop Release..." -ForegroundColor Green
    flutter build windows --release
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "=================================================" -ForegroundColor Red
        Write-Host "[ERROR] Windows build failed with exit code $LASTEXITCODE" -ForegroundColor Red
        Write-Host "=================================================" -ForegroundColor Red
        Pause
        exit $LASTEXITCODE
    }
    Write-Host ""
    Write-Host "=================================================" -ForegroundColor Green
    Write-Host "WINDOWS BUILD SUCCEEDED!" -ForegroundColor Green
    $winExePath = Join-Path $projectRoot "build\windows\x64\runner\Release\timetable.exe"
    if (Test-Path $winExePath) {
        $builtArtifactPath = $winExePath
        Write-Host "Artifact         : $winExePath" -ForegroundColor White
    }
    Write-Host "=================================================" -ForegroundColor Green
}
elseif ($platform -eq "4")
{
    Write-Host ""
    Write-Host "Building Web Release..." -ForegroundColor Green
    flutter build web --release
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "=================================================" -ForegroundColor Red
        Write-Host "[ERROR] Web build failed with exit code $LASTEXITCODE" -ForegroundColor Red
        Write-Host "=================================================" -ForegroundColor Red
        Pause
        exit $LASTEXITCODE
    }
    Write-Host ""
    Write-Host "=================================================" -ForegroundColor Green
    Write-Host "WEB BUILD SUCCEEDED!" -ForegroundColor Green
    Write-Host "=================================================" -ForegroundColor Green
}

# ==============================================================================
# STEP 5: CI/CD GOOGLE DRIVE RELEASE PIPELINE
# ==============================================================================
if ($builtArtifactPath -and (Test-Path -LiteralPath $builtArtifactPath)) {
    Write-Host ""
    Write-Host "=================================================" -ForegroundColor Cyan
    Write-Host ">>> [CI/CD] Google Drive Release Pipeline" -ForegroundColor Cyan
    Write-Host "=================================================" -ForegroundColor Cyan
    Write-Host "Target Artifact : $builtArtifactPath" -ForegroundColor White

    $runnerScript = Join-Path $PSScriptRoot "run-copy-releae-into-google-drive.ps1"
    if (Test-Path -LiteralPath $runnerScript) {
        try {
            $runnerContent = Get-Content -LiteralPath $runnerScript -Raw -Encoding utf8
            $escapedPath = $builtArtifactPath.Replace('"', '`"')
            $targetLine = "`$File = `"$escapedPath`""
            $updatedContent = [System.Text.RegularExpressions.Regex]::Replace(
                $runnerContent,
                '(?m)^\$File\s*=\s*".*"',
                [System.Text.RegularExpressions.MatchEvaluator]{ return $targetLine }
            )
            Set-Content -LiteralPath $runnerScript -Value $updatedContent -Encoding utf8 -Force
            Write-Host "[CI/CD] Updated `$File in run-copy-releae-into-google-drive.ps1 to:" -ForegroundColor Green
            Write-Host "       $builtArtifactPath" -ForegroundColor Gray
        }
        catch {
            Write-Host "[WARNING] Could not update `$File in run-copy-releae-into-google-drive.ps1: $($_.Exception.Message)" -ForegroundColor Yellow
        }

        Write-Host ""
        Write-Host "Do you want to upload this build to Google Drive now? [Y/N] (Default: Y): " -ForegroundColor Yellow -NoNewline
        $uploadChoice = Read-Host

        if ([string]::IsNullOrWhiteSpace($uploadChoice) -or $uploadChoice -eq "Y" -or $uploadChoice -eq "y") {
            Write-Host ""
            Write-Host ">>> [CI/CD] Starting Google Drive upload runner..." -ForegroundColor Cyan
            & $runnerScript -BuildFilePath $builtArtifactPath
        } else {
            Write-Host "[INFO] Google Drive upload skipped by user." -ForegroundColor Gray
        }
    } else {
        Write-Host "[WARNING] CI/CD runner script not found at: $runnerScript" -ForegroundColor Yellow
    }
}

Write-Host ""
Pause
