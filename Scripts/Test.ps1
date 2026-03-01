$liveSiteUrl = "https://dsaupstate.org"
$siteUrl = "$liveSiteUrl/index.php?rest_route=/wp/v2/posts?per_page=100&_embed"
$user = "wpusername0260"
$appPass = "4pu3 GlbO Tui6 mmVd 1Aro fsfv" # The app password you generated

$base64Auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${user}:${appPass}"))
$headers = @{ 
    Authorization = "Basic $base64Auth"
    Accept        = "application/json"
}

$results = @()

# 1. Fetch the data
$posts = Invoke-RestMethod -Uri $siteUrl -Headers $headers

if ($null -eq $posts -or $posts.Count -eq 0) {
    Write-Host "No posts found or error fetching data." -ForegroundColor Red
    exit
}

Write-Output $posts
exit

foreach ($post in $posts) {
    # 2. Check if a featured image exists in the embedded data
    $featuredImage = $null
    if ($post._embedded.'wp:featuredmedia') {
        $featuredImage = $post._embedded.'wp:featuredmedia'[0].source_url
    }

    # 3. Only add to list if it actually has an image (per your request)
    if ($null -ne $featuredImage) {
        $results += [PSCustomObject]@{
            PostID    = $post.id
            Title     = $post.title.rendered
            Slug      = $post.slug
            Date      = $post.date
            ImageURL  = $featuredImage
            AltText   = $post._embedded.'wp:featuredmedia'[0].alt_text
        }
    }
}

# 4. Export to CSV (or keep in memory for further processing)
$results | Export-Csv -Path "./WordPress_Featured_Images.csv" -NoTypeInformation

Write-Host "Export complete! Found $($results.Count) posts with featured images." -ForegroundColor Green