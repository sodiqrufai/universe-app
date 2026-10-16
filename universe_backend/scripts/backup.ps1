# Backs up the UniVerse Supabase database (schema + data) into a dated folder.
# Needs: Docker Desktop running + the Supabase CLI.
# Usage:  .\scripts\backup.ps1 -DbUrl "postgresql://postgres.xxxx:PASSWORD@aws-0-xx.pooler.supabase.com:5432/postgres"
param(
  [Parameter(Mandatory = $true)][string]$DbUrl
)
$ErrorActionPreference = 'Stop'

if (-not (Get-Command supabase -ErrorAction SilentlyContinue)) {
  throw "The Supabase CLI was not found. Install it first (you already use it for 'supabase db push')."
}

$stamp  = Get-Date -Format 'yyyy-MM-dd_HHmm'
$folder = Join-Path $PSScriptRoot "..\backups\$stamp"
New-Item -ItemType Directory -Force -Path $folder | Out-Null

Write-Host "Dumping schema..." -ForegroundColor Cyan
supabase db dump --db-url $DbUrl -f (Join-Path $folder 'schema.sql')
if ($LASTEXITCODE -ne 0) { throw "Schema dump failed. Is Docker Desktop running, and is the connection string right?" }

Write-Host "Dumping data..." -ForegroundColor Cyan
supabase db dump --db-url $DbUrl -f (Join-Path $folder 'data.sql') --data-only --use-copy
if ($LASTEXITCODE -ne 0) { throw "Data dump failed." }

foreach ($f in 'schema.sql', 'data.sql') {
  $size = (Get-Item (Join-Path $folder $f)).Length
  if ($size -lt 200) { throw "$f looks empty ($size bytes). Do not trust this backup." }
  Write-Host ("  {0}: {1:N0} KB" -f $f, ($size / 1KB))
}

Write-Host "`nBackup saved to: $((Resolve-Path $folder).Path)" -ForegroundColor Green
Write-Host "Now copy that folder somewhere safe (NOT GitHub - it contains student data)." -ForegroundColor Yellow
Write-Host "Files (photos, ID documents) are NOT included: see scripts/backup.md, Part 2."
