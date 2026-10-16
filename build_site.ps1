# Builds the Flutter web app and assembles the folder you drag onto Netlify:
#   dist/            <- landing page (what new visitors see first)
#   dist/app/        <- the UniVerse web app (opened by "Open UniVerse")
#
# Run from the repo root (C:\dev\UniVerseApp):
#   .\build_site.ps1 -SiteUrl "https://your-site.netlify.app"
#
# Optional parameters (all safe to leave out):
#   -SiteUrl        Full public address of the site, no trailing slash.
#                   Makes the share-preview image (og:image / twitter:image)
#                   an absolute link, which WhatsApp, Twitter and Facebook
#                   require, and fills in robots.txt and sitemap.xml.
#   -WhatsApp       Support WhatsApp number, digits only, with country code
#                   (e.g. 2348012345678). Without it the WhatsApp links stay hidden.
#   -AnalyticsKey   Your Plausible "site domain" (e.g. universe.ng). Turns on
#                   privacy-friendly analytics (no cookies). Without it, no
#                   analytics script is included at all.
param(
  [string]$SiteUrl = "",
  [string]$WhatsApp = "",
  [string]$AnalyticsKey = ""
)

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot

# ---- Validate parameters -------------------------------------------------
$SiteUrl = $SiteUrl.Trim().TrimEnd('/')
if ($SiteUrl -ne "" -and $SiteUrl -notmatch '^https://[A-Za-z0-9.-]+(:\d+)?(/[A-Za-z0-9._~/-]*)?$') {
  throw "-SiteUrl must look like https://your-site.netlify.app (https, no trailing slash, no spaces)."
}
$WhatsApp = ($WhatsApp -replace '[^\d]', '')
if ($WhatsApp -ne "" -and $WhatsApp -notmatch '^\d{8,15}$') {
  throw "-WhatsApp must be 8-15 digits including country code, e.g. 2348012345678."
}
$AnalyticsKey = $AnalyticsKey.Trim()
if ($AnalyticsKey -ne "" -and $AnalyticsKey -notmatch '^[A-Za-z0-9.-]+$') {
  throw "-AnalyticsKey should be just your site domain, e.g. universe.ng."
}
if ($SiteUrl -eq "") {
  Write-Host "Note: no -SiteUrl given. Share previews (WhatsApp/Twitter) will not show the image and robots.txt/sitemap.xml will be left without a real address." -ForegroundColor Yellow
}

# ---- Build the Flutter web app -------------------------------------------
Push-Location "$root\universe_mobile"
flutter pub get
flutter build web --release --base-href /app/ --pwa-strategy=none
if ($LASTEXITCODE -ne 0) { Pop-Location; throw "flutter build failed" }
Pop-Location

# ---- Assemble dist/ -------------------------------------------------------
$dist = "$root\dist"
if (Test-Path $dist) { Remove-Item $dist -Recurse -Force }
New-Item -ItemType Directory -Path "$dist\app" | Out-Null
Copy-Item "$root\landing\*" $dist -Recurse
Copy-Item "$root\universe_mobile\build\web\*" "$dist\app" -Recurse

# Legal text: the single source of truth is docs/legal/*.md. legal.html reads these
# copies first (and only falls back to the backend if they are missing).
if (Test-Path "$root\docs\legal") {
  New-Item -ItemType Directory -Path "$dist\legal" | Out-Null
  Copy-Item "$root\docs\legal\terms.md", "$root\docs\legal\privacy.md" "$dist\legal"
} else {
  Write-Host "Warning: docs/legal not found; legal.html will use the backend's copy." -ForegroundColor Yellow
}

# ---- Fill in the landing pages ---------------------------------------------
$utf8 = New-Object System.Text.UTF8Encoding($false)

$siteMeta = ""
if ($SiteUrl -ne "") {
  $siteMeta = "<link rel=`"canonical`" href=`"$SiteUrl/`">`n<meta property=`"og:url`" content=`"$SiteUrl/`">"
}
$analytics = ""
if ($AnalyticsKey -ne "") {
  $analytics = "<script defer data-domain=`"$AnalyticsKey`" src=`"https://plausible.io/js/script.js`"></script>"
}

foreach ($name in @("index.html", "legal.html")) {
  $path = Join-Path $dist $name
  $html = [System.IO.File]::ReadAllText($path, $utf8)
  if ($SiteUrl -ne "") {
    $html = $html.Replace('content="assets/og.png"', "content=`"$SiteUrl/assets/og.png`"")
  }
  $html = $html.Replace('<!--SITE_URL_META-->', $siteMeta)
  $html = $html.Replace('<!--ANALYTICS-->', $analytics)
  if ($WhatsApp -ne "") { $html = $html.Replace('%%WHATSAPP%%', $WhatsApp) }
  [System.IO.File]::WriteAllText($path, $html, $utf8)
}

# robots.txt and sitemap.xml need a real address; without one, drop the Sitemap
# line / the sitemap file rather than publishing a broken one.
$robots = Join-Path $dist "robots.txt"
$sitemap = Join-Path $dist "sitemap.xml"
if ($SiteUrl -ne "") {
  foreach ($f in @($robots, $sitemap)) {
    $t = [System.IO.File]::ReadAllText($f, $utf8).Replace('%%SITE_URL%%', $SiteUrl)
    [System.IO.File]::WriteAllText($f, $t, $utf8)
  }
} else {
  [System.IO.File]::WriteAllText($robots, "User-agent: *`nAllow: /`n", $utf8)
  Remove-Item $sitemap -Force
}

Write-Host ""
Write-Host "Done. Drag this folder onto Netlify:  $dist" -ForegroundColor Green
if ($SiteUrl -ne "") { Write-Host "Site address used: $SiteUrl" }
if ($WhatsApp -ne "") { Write-Host "WhatsApp support: https://wa.me/$WhatsApp" }
if ($AnalyticsKey -ne "") { Write-Host "Analytics: Plausible for $AnalyticsKey" } else { Write-Host "Analytics: off" }
