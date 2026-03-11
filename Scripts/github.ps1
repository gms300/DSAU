param(
    [switch] $pull,
    [switch] $push
)

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

if ($pull) {
    PullFromGithub
}

if ($push) {
    PushToGithub
}