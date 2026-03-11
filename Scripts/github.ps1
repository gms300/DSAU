param(
    [switch] $pull,
    [switch] $push
)

function GetDefaultGitHubUser {
    if ($env:GITHUB_USER) { 
        Write-Host "Has GITHUB_USER $($env:GITHUB_USER)"-ForegroundColor Yellow
        return $env:GITHUB_USER
    }

    $url = git remote get-url origin 2>$null
    if ($url -match 'github\.com[/:]([^/]+)/') {
        Write-Host "Has GitHub User $($Matches[1])" -ForegroundColor Yellow
        return $Matches[1]
    }

    Write-Host "No GitHub User found" -ForegroundColor Red
    return $null
}

function EnsureRemoteUsesGitHubUser {
    Write-Host "Ensuring remote uses GitHub User" -ForegroundColor Yellow
    $user = GetDefaultGitHubUser

    if (-not $user) { 
        Write-Host "No GitHub User found" -ForegroundColor Red
        return
    }
    
    Write-Host "GitHub User found $user" -ForegroundColor Yellow
    $url = git remote get-url origin
    if ($url -match '^https://(?:[^@]+@)?github\.com/(.+)$') {
        $path = $Matches[1]
        $newUrl = "https://${user}@github.com/$path"
        if ($url -ne $newUrl) {
            git remote set-url origin $newUrl
        }
    }
}

function PullFromGithub {
    $HasLocalChanges = git status --short
                    
    if ($HasLocalChanges) {
        Write-Host "Stashing local changes."-ForegroundColor White -BackgroundColor Blue
        git stash save
    }

    git pull | Out-Host

    if ($HasLocalChanges) {
        Write-Host "Retrieving stashed local changes."-ForegroundColor White -BackgroundColor Blue
        git stash pop
    }
}

function PushToGithub {
    git add --all
    $HasLocalChanges = git status --short
                    
    if ($HasLocalChanges) {
        [string] $msg = Get-Date -Format "dddd, yyyy-MM-dd hh:mm tt"

        Write-Host ""
        Write-Host ""
        Write-Host "Committing new changes as ""$msg""" -ForegroundColor Yellow
        Write-Host ""
        git add .
        git commit -m $msg
    }

    $HasUncommittedChanges = git log origin/main..main
    if ($HasUncommittedChanges) {
        Write-Host ""
        Write-Host ""
        Write-Host "Pushing changes" -ForegroundColor Yellow
        Write-Host ""
        git push
    }
}

EnsureRemoteUsesGitHubUser

if ($pull) {
    PullFromGithub
}

if ($push) {
    PushToGithub
}