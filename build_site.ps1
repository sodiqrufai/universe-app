# Builds the Flutter web app and assembles the folder you drag onto Netlify:
#   dist/            <- landing page (what new visitors see first)
#   dist/app/        <- the UniVerse web app (opened by "Open UniVerse")
# Run from the repo root (C:\dev\UniVerseApp):   .\build_site.ps1
$ErrorActionPreference = "Stop"
$root = $PSScriptRoot

Push-Location "$root\universe_mobile"
flutter pub get
flutter build web --release --base-href /app/ --pwa-strategy=none
if ($LASTEXITCODE -ne 0) { Pop-Location; throw "flutter build failed" }
Pop-Location

$dist = "$root\dist"
if (Test-Path $dist) { Remove-Item $dist -Recurse -Force }
New-Item -ItemType Directory -Path "$dist\app" | Out-Null
Copy-Item "$root\landing\*" $dist -Recurse
Copy-Item "$root\universe_mobile\build\web\*" "$dist\app" -Recurse

Write-Host ""
Write-Host "Done. Drag this folder onto Netlify:  $dist" -ForegroundColor Green
