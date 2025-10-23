# HTS MD 정리기 (간단 버전 - 한글 최소)
$base = Get-Location
$today = Get-Date -Format "yyyyMMdd_HHmmss"

# Backup folder
$backup = "$base\backup_$today"
New-Item -ItemType Directory -Path $backup | Out-Null
Copy-Item "$base\*.md" $backup

# Index.md
$index = "$base\index.md"
"# Auto Index" | Out-File $index -Encoding utf8
$files = Get-ChildItem -Path $base -Filter "*.md" | Sort-Object Name | Where-Object { $_.Name -notlike "index.md" -and $_.Name -notlike "all-in-one.md" -and $_.Name -notlike "organize-md.ps1" }
foreach ($f in $files) {
    "- [$($f.Name)](./$($f.Name))" | Out-File $index -Append -Encoding utf8
}

# All-in-one.md
$all = "$base\all-in-one.md"
"# All Combined" | Out-File $all -Encoding utf8
foreach ($f in $files) {
    "## $($f.Name)" | Out-File $all -Append -Encoding utf8
    Get-Content $f.FullName | Out-File $all -Append -Encoding utf8
    "`n---`n" | Out-File $all -Append -Encoding utf8
}

Write-Host "Done! Check index.md and all-in-one.md"
