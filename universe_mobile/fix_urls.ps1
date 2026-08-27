$files = Get-ChildItem -Path "lib" -Recurse -Filter *.dart

foreach ($file in $files) {
    $content = Get-Content $file.FullName -Raw
    if ($content -match [regex]::Escape("http://localhost:3000")) {
        $newContent = $content -replace [regex]::Escape("http://localhost:3000"), '${ApiConfig.baseUrl}'
        if ($newContent -notmatch "import 'package:universe_mobile/config/api_config.dart';") {
            $newContent = "import 'package:universe_mobile/config/api_config.dart';`n" + $newContent
        }
        Set-Content -Path $file.FullName -Value $newContent -NoNewline
        Write-Host "Updated: $($file.FullName)"
    }
}

Write-Host "Done."