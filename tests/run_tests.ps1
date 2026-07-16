# Headless test runner for Vibe Coder Tycoon.
# Usage: powershell -ExecutionPolicy Bypass -File tests/run_tests.ps1
# Exit code = number of failed asserts (0 = green).

$ErrorActionPreference = "Stop"

function Find-Godot {
    $cmd = Get-Command godot -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $winget = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages"
    if (Test-Path $winget) {
        $exe = Get-ChildItem -Path $winget -Recurse -Filter "Godot_v*win64.exe" -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notmatch "console" } |
            Sort-Object Name -Descending | Select-Object -First 1
        if ($exe) { return $exe.FullName }
    }
    throw "Godot executable not found (PATH or winget packages)."
}

$godot = Find-Godot
$projectRoot = Split-Path -Parent $PSScriptRoot

Write-Host "Godot: $godot"
Write-Host "Project: $projectRoot"

& $godot --headless --path $projectRoot res://tests/test_runner.tscn
$code = $LASTEXITCODE
if ($code -eq 0) {
    Write-Host "ALL TESTS GREEN" -ForegroundColor Green
} else {
    Write-Host "$code TEST(S) FAILED" -ForegroundColor Red
}
exit $code
