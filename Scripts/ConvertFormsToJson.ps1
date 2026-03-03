# Script to convert Forms XML to JSON

# Parameter for input XML file
param(
    [Parameter(Mandatory=$true)]
    [string]$XmlPath
)

# Validate the input file exists
if (-not (Test-Path $XmlPath)) {
    Write-Host "Error: File not found: $XmlPath" -ForegroundColor Red
    exit 1
}

# Generate output path by replacing .xml extension with .json
$outputPath = [System.IO.Path]::ChangeExtension($XmlPath, ".json")

# Load the XML file as text (to avoid namespace issues)
$xmlContent = Get-Content $XmlPath -Raw

# Debug: Show first few characters
Write-Host "File loaded: $XmlPath" -ForegroundColor Yellow
Write-Host "Length: $($xmlContent.Length) characters" -ForegroundColor Yellow

# Extract all <item> blocks using regex (non-greedy match)
$itemPattern = '(?s)<item>.*?</item>'
$itemMatches = [regex]::Matches($xmlContent, $itemPattern)

Write-Host "Found $($itemMatches.Count) item(s)" -ForegroundColor Yellow

# Create array to hold the results
$results = @()

$itemCounter = 0
foreach ($match in $itemMatches) {
    $itemCounter++
    $itemContent = $match.Value
    
    # Look for formName pattern directly in the item content
    # Pattern: s:8:"formName";s:XX:"YYY" where XX is the length and YYY is the form name
    if ($itemContent -match 's:8:"formName";s:(\d+):"([^"]+)"') {
        $nameLength = $matches[1]
        $formName = $matches[2]
        
        Write-Host "Item $itemCounter - Form name: $formName" -ForegroundColor Green
        
        # Extract the notifications section using a position-based approach
        $emailLabels = @()
        
        # Find the start of notifications
        $notifStart = $itemContent.IndexOf('s:13:"notifications"')
        
        if ($notifStart -gt -1) {
            # Find the end - look for the next top-level key or end of the item
            # Common next keys: "behaviors", "integration_conditions", etc.
            $notifEnd = $itemContent.IndexOf('s:9:"behaviors"', $notifStart)
            if ($notifEnd -eq -1) {
                $notifEnd = $itemContent.IndexOf('s:9:"client_id"', $notifStart)
            }
            if ($notifEnd -eq -1) {
                $notifEnd = $itemContent.Length
            }
            
            # Extract the notifications section
            $notificationsSection = $itemContent.Substring($notifStart, $notifEnd - $notifStart)
            
            # Extract labels that come immediately after a slug
            # Pattern: s:4:"slug";s:XX:"notification-XXXX-XXXX";s:5:"label";s:XX:"YYY"
            # This ensures we only get the main notification label, not labels from conditions/routing
            $notificationPattern = 's:4:"slug";s:\d+:"([^"]+)";s:5:"label";s:(\d+):"([^"]+)"'
            $notificationMatches = [regex]::Matches($notificationsSection, $notificationPattern)
            
            foreach ($notifMatch in $notificationMatches) {
                $slug = $notifMatch.Groups[1].Value
                $emailLabel = $notifMatch.Groups[3].Value
                
                # Find the position of this notification in the section
                $notifPos = $notifMatch.Index
                
                # Extract a chunk of text after this notification (roughly the notification block)
                # Look ahead up to 2000 characters or until the next slug
                $lookAheadLength = [Math]::Min(2000, $notificationsSection.Length - $notifPos)
                $notifBlock = $notificationsSection.Substring($notifPos, $lookAheadLength)
                
                # Find the next slug to limit our search area
                $nextSlugMatch = [regex]::Match($notifBlock.Substring(10), 's:4:"slug"')
                if ($nextSlugMatch.Success) {
                    $notifBlock = $notifBlock.Substring(0, $nextSlugMatch.Index + 10)
                }
                
                # Extract subject
                $subject = ""
                if ($notifBlock -match 's:13:"email-subject";s:\d+:"([^"]+)"') {
                    $subject = $matches[1]
                }
                
                # Extract recipients
                $recipients = ""
                if ($notifBlock -match 's:10:"recipients";s:\d+:"([^"]+)"') {
                    $recipients = $matches[1]
                }
                
                # Create an object with Label, Subject, and Recipients properties
                $emailObject = [PSCustomObject]@{
                    Label = $emailLabel
                    Subject = $subject
                    Recipients = $recipients
                }
                
                $emailLabels += $emailObject
                Write-Host "  Email: $emailLabel" -ForegroundColor Cyan
            }
            
            # Remove duplicates based on Label
            $emailLabels = $emailLabels | Sort-Object Label -Unique
        } else {
            Write-Host "  No notifications found" -ForegroundColor Yellow
        }
        
        # Create object for this form
        $formObject = [PSCustomObject]@{
            Name = $formName
            Emails = $emailLabels
        }
        
        $results += $formObject
    }
}

# Convert to JSON
if ($results.Count -gt 0) {
    $jsonOutput = $results | ConvertTo-Json -Depth 10
    
    # Save to file
    $jsonOutput | Out-File -FilePath $outputPath -Encoding UTF8
    
    Write-Host "`nSaved to: $outputPath" -ForegroundColor Cyan
    Write-Host "Total forms extracted: $($results.Count)" -ForegroundColor Yellow
} else {
    Write-Host "`nNo forms found!" -ForegroundColor Red
}
