<#
.SYNOPSIS
    Uploads a build/release artifact into a daily dated subfolder on Google Drive.

.DESCRIPTION
    Production-grade CI/CD pipeline script to:
    1. Validate parameters and parse out Google Drive folder IDs even from full Web URLs.
    2. Check or create a daily folder ('MMDDYYYY') inside the parent folder destination.
    3. Upload the target build file using Google Drive API v3 via multipart/related binary payload stream.

.PARAMETER BuildFilePath
    Mandatory. Absolute or relative path to the local artifact build file to upload.

.PARAMETER AccessToken
    Mandatory. Valid OAuth 2.0 Bearer access token string with Google Drive write authorization.

.PARAMETER ParentFolderUrlOrId
    Mandatory. The root Google Drive destination folder ID or browser web interface folder URL path.
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, HelpMessage = "Path to the local build artifact to upload")]
    [ValidateNotNullOrEmpty()]
    [string]$BuildFilePath,

    [Parameter(Mandatory = $true, HelpMessage = "OAuth 2.0 Bearer Access Token for Google Drive API")]
    [ValidateNotNullOrEmpty()]
    [string]$AccessToken,

    [Parameter(Mandatory = $true, HelpMessage = "Google Drive Target Folder ID or complete browser Web URL")]
    [ValidateNotNullOrEmpty()]
    [string]$ParentFolderUrlOrId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-FileMimeType {
    param (
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )
    $extension = [System.IO.Path]::GetExtension($FilePath).ToLowerInvariant()
    $mimeTypes = @{
        ".apk"  = "application/vnd.android.package-archive"
        ".aab"  = "application/octet-stream"
        ".ipa"  = "application/octet-stream"
        ".zip"  = "application/zip"
        ".tar"  = "application/x-tar"
        ".gz"   = "application/gzip"
        ".tgz"  = "application/gzip"
        ".7z"   = "application/x-7z-compressed"
        ".exe"  = "application/x-msdownload"
        ".msi"  = "application/x-msi"
        ".json" = "application/json"
        ".xml"  = "application/xml"
        ".txt"  = "text/plain"
        ".log"  = "text/plain"
        ".pdf"  = "application/pdf"
    }

    if ($mimeTypes.ContainsKey($extension)) { return $mimeTypes[$extension] }
    if ($PSVersionTable.PSVersion.Major -ge 5 -and (Test-Path "Registry::HKEY_CLASSES_ROOT\$extension")) {
        try {
            $regValue = (Get-ItemProperty -Path "Registry::HKEY_CLASSES_ROOT\$extension" -Name "Content Type" -ErrorAction SilentlyContinue)."Content Type"
            if (-not [string]::IsNullOrWhiteSpace($regValue)) { return $regValue }
        }
        catch {}
    }
    return "application/octet-stream"
}

try {
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "[CI/CD] Starting Google Drive Artifact Upload Pipeline..." -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan

    # 1. Parse Google Drive Parent ID if full Web URL path is supplied
    $CleanParentFolderId = $ParentFolderUrlOrId.Trim()
    if ($CleanParentFolderId -like "*drive.google.com*") {
        Write-Host "[INFO] Web URL detected. Extracting Google Drive Folder ID string..." -ForegroundColor Gray
        if ($CleanParentFolderId -match 'folders\/([a-zA-Z0-9_-]+)') {
            $CleanParentFolderId = $Matches[1]
        }
        else {
            throw "Failed to extract a valid Google Drive Folder ID from provided URL parameter: '$ParentFolderUrlOrId'"
        }
    }

    # 2. Validate Local File Existence
    if (-not (Test-Path -LiteralPath $BuildFilePath -PathType Leaf)) {
        throw "The specified build file does not exist or is not an active file path: '$BuildFilePath'"
    }

    $resolvedPath = (Resolve-Path -LiteralPath $BuildFilePath).ProviderPath
    $fileInfo = Get-Item -LiteralPath $resolvedPath
    $fileName = $fileInfo.Name
    $fileSizeBytes = $fileInfo.Length
    $fileSizeMB = [math]::Round($fileSizeBytes / 1MB, 2)
    $mimeType = Get-FileMimeType -FilePath $resolvedPath

    Write-Host "[INFO] Local File       : $fileName" -ForegroundColor Gray
    Write-Host "[INFO] Local Path       : $resolvedPath" -ForegroundColor Gray
    Write-Host "[INFO] File Size        : $fileSizeMB MB ($fileSizeBytes bytes)" -ForegroundColor Gray
    Write-Host "[INFO] MIME Type        : $mimeType" -ForegroundColor Gray
    Write-Host "[INFO] Parent Folder ID : $CleanParentFolderId" -ForegroundColor Gray

    # Set authentication structural headers
    $authHeaders = @{
        "Authorization" = "Bearer $AccessToken"
    }

    # 3. Dynamic Daily Folder Evaluation ('MMDDYYYY')
    $dailyFolderName = (Get-Date).ToString("MMddyyyy")
    Write-Host "[INFO] Target Release Subfolder designation: '$dailyFolderName'..." -ForegroundColor Cyan

    $escapedParent = $CleanParentFolderId.Replace("'", "\'")
    $escapedName = $dailyFolderName.Replace("'", "\'")
    $searchQuery = "name = '$escapedName' and '$escapedParent' in parents and mimeType = 'application/vnd.google-apps.folder' and trashed = false"
    $encodedSearchQuery = [System.Uri]::EscapeDataString($searchQuery)
    $searchUri = "https://www.googleapis.com/drive/v3/files?q=$encodedSearchQuery&fields=files(id,name)&spaces=drive"

    Write-Host "[INFO] Querying Google Drive API directory contents..." -ForegroundColor Gray
    $searchResponse = Invoke-RestMethod -Uri $searchUri -Method Get -Headers $authHeaders

    $targetDailyFolderId = $null

    if ($null -ne $searchResponse.files -and $searchResponse.files.Count -gt 0) {
        $targetDailyFolderId = $searchResponse.files[0].id
        Write-Host "[SUCCESS] Target folder '$dailyFolderName' found (ID: $targetDailyFolderId)." -ForegroundColor Green
    }
    else {
        Write-Host "[INFO] Folder '$dailyFolderName' not found in root path. Creating folder now..." -ForegroundColor Yellow

        $folderCreateUri = "https://www.googleapis.com/drive/v3/files?fields=id,name"
        $folderPayload = @{
            name     = $dailyFolderName
            mimeType = "application/vnd.google-apps.folder"
            parents  = @($CleanParentFolderId)
        } | ConvertTo-Json -Compress

        $createResponse = Invoke-RestMethod -Uri $folderCreateUri -Method Post -Headers $authHeaders -Body $folderPayload -ContentType "application/json; charset=utf-8"
        $targetDailyFolderId = $createResponse.id
        Write-Host "[SUCCESS] Created new release folder '$dailyFolderName' (ID: $targetDailyFolderId)." -ForegroundColor Green
    }

    if ([string]::IsNullOrWhiteSpace($targetDailyFolderId)) {
        throw "Failed to locate or instantiate target folder '$dailyFolderName'."
    }

    # 4. Construct Multipart/Related Pipeline Body Payload
    Write-Host "[INFO] Streaming artifact upload to Google Drive cloud server storage..." -ForegroundColor Cyan

    $boundary = [System.Guid]::NewGuid().ToString()
    $crlf = "`r`n"

    $metadataJson = @{
        name    = $fileName
        parents = @($targetDailyFolderId)
    } | ConvertTo-Json -Compress

    $metaPart = "--$boundary$crlf" +
    "Content-Type: application/json; charset=UTF-8$crlf$crlf" +
    "$metadataJson$crlf" +
    "--$boundary$crlf" +
    "Content-Type: $mimeType$crlf$crlf"

    $footerPart = "$crlf--$boundary--$crlf"

    $metaBytes = [System.Text.Encoding]::UTF8.GetBytes($metaPart)
    $fileBytes = [System.IO.File]::ReadAllBytes($resolvedPath)
    $footerBytes = [System.Text.Encoding]::UTF8.GetBytes($footerPart)

    $memoryStream = New-Object System.IO.MemoryStream
    $memoryStream.Write($metaBytes, 0, $metaBytes.Length)
    $memoryStream.Write($fileBytes, 0, $fileBytes.Length)
    $memoryStream.Write($footerBytes, 0, $footerBytes.Length)
    $uploadBodyBytes = $memoryStream.ToArray()
    $memoryStream.Dispose()

    $uploadUri = "https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart&fields=id,name,size,mimeType,webViewLink"
    $uploadContentType = "multipart/related; boundary=$boundary"

    # 5. REST Call Submission Execution
    $uploadResponse = Invoke-RestMethod -Uri $uploadUri -Method Post -Headers $authHeaders -ContentType $uploadContentType -Body $uploadBodyBytes

    Write-Host "==========================================================" -ForegroundColor Green
    Write-Host "[SUCCESS] Release deployment executed completely!" -ForegroundColor Green
    Write-Host "  - File Object Name : $($uploadResponse.name)" -ForegroundColor Green
    Write-Host "  - Generated File ID: $($uploadResponse.id)" -ForegroundColor Green
    if ($uploadResponse.webViewLink) {
        Write-Host "  - Browser Web Link : $($uploadResponse.webViewLink)" -ForegroundColor Green
    }
    Write-Host "==========================================================" -ForegroundColor Green

    exit 0
}
catch {
    $errorMessage = $_.Exception.Message
    if ($_.PSObject.Properties['ErrorDetails'] -and $_.ErrorDetails -and $_.ErrorDetails.Message) {
        $errorMessage = "$errorMessage - Details: $($_.ErrorDetails.Message)"
    }
    elseif ($_.Exception -is [System.Net.WebException] -and $_.Exception.Response) {
        try {
            $stream = $_.Exception.Response.GetResponseStream()
            if ($null -ne $stream) {
                $reader = New-Object System.IO.StreamReader($stream)
                $body = $reader.ReadToEnd()
                $reader.Dispose()
                if (-not [string]::IsNullOrWhiteSpace($body)) {
                    $errorMessage = "$errorMessage - Response Context: $body"
                }
            }
        }
        catch { }
    }

    Write-Error "[FATAL] Script Execution Pipeline Step Failed: $errorMessage"
    exit 1
}
