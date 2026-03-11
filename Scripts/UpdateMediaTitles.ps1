param(
    [bool]$IsStaging = $false,
    [switch]$WhatIf
)

# --- Configuration (aligned with ExportPages.ps1) ---
$liveSiteUrl = "https://dsaupstate.org"
$stagingSiteUrl = "https://c9s.3d3.myftpupload.com"

$liveDatabase = "DSAU.Website"
$stagingDatabase = "DSAU.Website.Staging"

$siteUrl = if ($IsStaging) { $stagingSiteUrl } else { $liveSiteUrl }
$wpUrl = "$siteUrl/index.php?rest_route=/wp/v2"
$user = "wpusername0260"
$appPass = "4pu3 GlbO Tui6 mmVd 1Aro fsfv"

$sqlServer = ".,1433"
$database = if ($IsStaging) { $stagingDatabase } else { $liveDatabase }

# --- Authentication ---
$base64Auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${user}:${appPass}"))
$headers = @{
    Authorization = "Basic $base64Auth"
    Accept        = "application/json"
}

# --- Main ---
$deployment = if ($IsStaging) { "Staging" } else { "Live" }
Write-Host "UpdateMediaTitles [$deployment]" -ForegroundColor Cyan
if ($WhatIf) { Write-Host "WhatIf: no API updates will be performed." -ForegroundColor Yellow }
Write-Host ""

# 1. Read NewMediaTitle from SQL (MediaID = WordPress media ID)
Write-Host "Reading dbo.NewMediaTitle..." -ForegroundColor Cyan
try {
    $rows = Invoke-Sqlcmd -ServerInstance $sqlServer -TrustServerCertificate -Database $database `
        -Query "SELECT MediaID, NewTitle FROM dbo.NewMediaTitle" -MaxCharLength ([int]::MaxValue)
} catch {
    Write-Error "Failed to read NewMediaTitle: $_"
    exit 1
}

$rows = @($rows)
if ($rows.Count -eq 0) {
    Write-Host "No rows in NewMediaTitle. Exiting." -ForegroundColor Yellow
    exit 0
}

$toProcess = $rows | Where-Object {
    $title = if ($_.NewTitle) { $_.NewTitle.ToString().Trim() } else { "" }
    $null -ne $_.MediaID -and -not [string]::IsNullOrWhiteSpace($title)
}

$skipped = $rows.Count - $toProcess.Count
if ($skipped -gt 0) {
    Write-Host "Skipped $skipped row(s) with null/invalid MediaID or empty NewTitle." -ForegroundColor Yellow
}
if ($toProcess.Count -eq 0) {
    Write-Host "No rows to process. Exiting." -ForegroundColor Yellow
    exit 0
}

Write-Host "Processing $($toProcess.Count) row(s)." -ForegroundColor Cyan
Write-Host ""

# 2. Update each media title via REST API
$updated = 0
$errors = 0

foreach ($row in $toProcess) {
    $mediaId = [int]$row.MediaID
    $newTitle = $row.NewTitle.ToString().Trim()

    if ($WhatIf) {
        Write-Host "WhatIf: would set media $mediaId title to: $newTitle" -ForegroundColor Gray
        $updated++
        continue
    }

    try {
        $body = @{ title = $newTitle } | ConvertTo-Json
        $uri = "$wpUrl/media/$mediaId"
        Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -Body $body -ContentType "application/json" | Out-Null
        Write-Host "Updated media $mediaId : $newTitle" -ForegroundColor Green
        $updated++
    } catch {
        Write-Warning "Failed to update media $mediaId : $_"
        $errors++
    }
}

Write-Host ""
Write-Host "Done. Updated: $updated, Errors: $errors" -ForegroundColor Cyan
