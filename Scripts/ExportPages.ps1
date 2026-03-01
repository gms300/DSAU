param(
    [bool]$isStaging = $false
)

# --- Configuration ---
$liveSiteUrl = "https://dsaupstate.org"
$stagingSiteUrl = "https://c9s.3d3.myftpupload.com"

$liveDatabase = "DSAU.Website"
$stagingDatabase = "DSAU.Website.Staging"

$siteUrl = if ($isStaging) { $stagingSiteUrl } else { $liveSiteUrl }
$wpUrl = "$siteUrl/index.php?rest_route=/wp/v2"
$user = "wpusername0260"
$appPass = "4pu3 GlbO Tui6 mmVd 1Aro fsfv" # The app password you generated

$sqlServer = ".,1433"
$database = if ($isStaging) { $stagingDatabase } else { $liveDatabase }
$Page_Table = "Page"
$Media_Table = "Media"
$MediaLink_Table = "MediaLink"

# --- Authentication Setup ---
$base64Auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${user}:${appPass}"))
$headers = @{ 
    Authorization = "Basic $base64Auth"
    Accept = "application/json"
}

# --- Fetch Data ---
function Get-WPData($Endpoint) {
    $Deployment = if ($isStaging) { "Staging" } else { "Live" }

    $results = @()
    $pageCount = 100
    $page = 1
    $fetching = $true

    while ($fetching) {
        try {
            $url = "$($wpUrl)/$Endpoint&per_page=$pageCount&page=$page"
            $resp = Invoke-RestMethod -Uri $url -Headers $headers
            if ($resp.Count -eq 0) {
                $fetching = $false
            } else {
                $results += $resp
                
                if ($resp.Count -lt $pageCount) {
                    # If we got less than $pageCount items, it's likely the last page
                    $fetching = $false
                } else {
                    $page++
                }
            }
        } catch {
            $fetching = $false

            $errorCode = $null
            try {
                $errorCode = ($_ | ConvertFrom-Json).code
            } catch {
                # If conversion fails, treat as a valid error to report
            }

            if ($errorCode -ne "rest_post_invalid_page_number") {
                Write-Error "Error fetching $Endpoint page $($page): $_"
            }
        }
    }
    
    # Handle both array/object and string responses
    if ($results -is [array] -and $results.Count -eq 1 -and $results[0] -is [string]) {
        $results = ($results[0] | ConvertFrom-Json -AsHashtable)
    }

    Out-File -FilePath ".\Exports\Export_$($Deployment)_$($Endpoint).json" -InputObject ($results | ConvertTo-Json -Depth 20) -Encoding utf8

    return $results
}

Write-Host "Downloading Site Data..." -ForegroundColor Cyan

$endpoints = @{}
$endpointNames = @("types", "pages", "media", "menu-items", "blocks", "templates", "template-parts", "navigation", "edd-downloads", "board-member", "tribe_rsvp_tickets", "tribe_venue", "tribe_organizer", "tribe_events")

foreach ($endpoint in $endpointNames) {
    $endpoints[$endpoint] = Get-WPData $endpoint
    Write-Host "$($endpoints[$endpoint].Count) items downloaded for $endpoint." -ForegroundColor Cyan
}

$wpPages = $endpoints["pages"]
$wpMedia = $endpoints["media"]

# --- Create Media Lookup Table (URL -> ID) ---
# This makes matching instantaneous
$mediaLookup = @{}
foreach ($m in $wpMedia) {
    $cleanUrl = $m.source_url.Replace($siteUrl, "") # Store relative path for better matching
    if (-not $mediaLookup.ContainsKey($cleanUrl)) {
        $mediaLookup.Add($cleanUrl, $m.id)
    }
}

# --- Parse Links via Regex ---
$mediaLinks = @()

$mediaImports = foreach($m in $wpMedia) { 
    [PSCustomObject] @{ 
        ID = $m.id; 
        Name = $m.title.rendered;
        FullName = if ($m.media_details.file) { $m.media_details.file } else { $m.title.rendered }; 
        Description = $m.caption.rendered;
        Slug = $m.slug;
        MediaURL = $m.source_url;
        MimeType = $m.mime_type;
    } 
}

$pageImports = foreach ($p in $wpPages) {
    # 1. Capture the entire <img> or <a> tag to look for both ID and URL
    # This Regex finds tags and extracts the class and the source/href
    $tagRegex = '<(?:img|a)[^>]+(?:class=["''][^"'']*wp-image-(?<id>\d+)[^"'']*["''])?[^>]+(?:src|href)=["''](?<url>[^"'']+)["''][^>]*>'
    $regexMatches = [regex]::Matches($p.content.rendered, $tagRegex)

    foreach ($match in $regexMatches) {
        $foundId = $match.Groups['id'].Value
        $foundUrl = $match.Groups['url'].Value.Replace($siteUrl, "")

        if ($foundId) {
            # PRIORITY 1: Use the ID found in the class attribute
            $mediaLinks += [PSCustomObject] @{
                MediaID = [int]$foundId
                LinkType = "Page Reference"
                LinkID  = $p.id
            }
        }
        elseif ($mediaLookup.ContainsKey($foundUrl)) {
            # PRIORITY 2: Exact URL match
            $mediaLinks += [PSCustomObject] @{
                MediaID = $mediaLookup[$foundUrl]
                LinkType = "Page Reference"
                LinkID  = $p.id
            }
        }
        else {
            # PRIORITY 3: Fallback - Strip dimensions (e.g., -1024x576) and try again
            # This turns '11-1024x576.png' into '11.png'
            $strippedUrl = $foundUrl -replace '-\d+x\d+(?=\.[^.]+$)', ''
            
            if ($mediaLookup.ContainsKey($strippedUrl)) {
                $mediaLinks += [PSCustomObject] @{
                    MediaID = $mediaLookup[$strippedUrl]
                    LinkType = "Page Reference"
                    LinkID  = $p.id
                }
            }
        }
    }

    # Prep Page for Import
    [PSCustomObject] @{
        ID = $p.id;
        Title = $p.title.rendered;
        PageURL = $p.link;
        Slug = $p.slug;
        Content = $p.content.rendered;
        TemplateName = if ($p.template -eq "") { $null } else { $p.template };
    }
}

# --- Fill Media Links from Featured Images ---
foreach ($endpoint in $endpointNames) {
    foreach ($item in $endpoints[$endpoint]) {
        if ($null -ne $item.featured_media -and $item.featured_media -ne 0) {
            $mediaId = $item.featured_media
            $linkType = "$endpoint Featured Image"
            $linkId = $item.id

            # Only add if the media ID exists in our lookup (to avoid orphan links)
            if ($mediaLookup.ContainsValue($mediaId)) {
                $mediaLinks += [PSCustomObject] @{
                    MediaID = $mediaId
                    LinkType = $linkType
                    LinkID  = $linkId
                }
            } else {
                Write-Warning "Featured media ID $mediaId for $endpoint item $linkId not found in media lookup. Skipping link creation."
            }
        }
    }
}

# --- Clear Existing Data ---
Write-Host "Clearing existing data..." -ForegroundColor Magenta
Write-Host

# Delete child records first, then parents
Invoke-Sqlcmd -ServerInstance $sqlServer `
                -TrustServerCertificate `
                -Database $database `
                -Query "DELETE FROM [MediaLink]; DELETE FROM [Page]; DELETE FROM [Media];"

                # --- SQL Bulk Inserts ---
Write-Host "Syncing to SQL..." -ForegroundColor Cyan

# Insert Pages
Write-SqlTableData -ServerInstance $sqlServer `
                    -DatabaseName $database `
                    -TableName $Page_Table `
                    -InputData $pageImports `
                    -SchemaName "dbo" `
                    -Force

# Insert Media
Write-SqlTableData -ServerInstance $sqlServer `
                    -DatabaseName $database `
                    -TableName $Media_Table `
                    -InputData $mediaImports `
                    -SchemaName "dbo" `
                    -Force

# Insert the Media Links
if ($mediaLinks.Count -gt 0) {
    Write-Host "Validating and deduplicating $($mediaLinks.Count) links..." -ForegroundColor Cyan

    # 1. Deduplicate
    # 2. Filter out any rows where MediaID is null (Lookup failed)
    $cleanLinks = $mediaLinks | 
        Select-Object MediaID, LinkType, LinkID -Unique | 
        Where-Object { $_.MediaID -ne $null -and $_.LinkID -ne $null }

    if ($cleanLinks.Count -gt 0) {
        Write-Host "Inserting $($cleanLinks.Count) verified links into MediaLink..." -ForegroundColor Cyan
        
        Write-SqlTableData -ServerInstance $sqlServer `
                            -DatabaseName $database `
                            -TableName $MediaLink_Table `
                            -SchemaName "dbo" `
                            -InputData $cleanLinks `
                            -Force
    } else {
        Write-Warning "No valid internal media links were found to insert."
    }
}

Write-Host
Write-Host "Audit Sync Complete!" -ForegroundColor Green