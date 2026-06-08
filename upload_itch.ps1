# Upload Vibe Coder Tycoon to itch.io (limbo1572/vibe-coder-tycoon)
# Double-click or: powershell -ExecutionPolicy Bypass -File upload_itch.ps1

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$WebDir = Join-Path $ProjectRoot "build\web"
$Butler = Join-Path $env:LOCALAPPDATA "butler\butler.exe"
$Game = "limbo1572/vibe-coder-tycoon:html"

if (-not (Test-Path $Butler)) {
    Write-Host "Butler not found. Download from https://itch.io/docs/butler/installing.html"
    exit 1
}

if (-not (Test-Path (Join-Path $WebDir "index.html"))) {
    Write-Host "Web build missing. Run Godot export first."
    exit 1
}

$creds = Join-Path $env:USERPROFILE ".config\itch\butler_creds"
if (-not (Test-Path $creds)) {
    Write-Host ""
    Write-Host "=== itch.io login (one time) ==="
    Write-Host "Browser will open. Log in, then paste the redirect URL here if asked."
    Write-Host ""
    & $Butler login
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

Write-Host ""
Write-Host "Uploading to $Game ..."
& $Butler push $WebDir $Game
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ""
Write-Host "Done! Open: https://limbo1572.itch.io/vibe-coder-tycoon"
Write-Host "In Edit page: set upload as 'Played in browser', viewport 1152 x 648, then Save."
