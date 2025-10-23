# HTS MD Auto Categorizer (English Version - No Korean Comments)
$base = Get-Location
$today = Get-Date -Format "yyyyMMdd_HHmmss"

# Always backup first
$backup = "$base\backup_$today"
New-Item -ItemType Directory -Path $backup | Out-Null
Copy-Item "$base\*.md" $backup  # Backup all .md files before categorizing

# Category keywords (Korean terms for matching, English folder names)
$categories = @{
    "Agriculture" = "농장|계란|토하|BSF|동애등에|순환|식품|레시피|사육"
    "Energy" = "LNG|ESS|수소|에너지|발전|항만|DH|AFPM|Eflow"
    "Finance" = "DAO|RWA|TRR|투자|금융|은행|담보|Labuan|ADGM|BLX"
    "RealEstate" = "호텔|세컨하우스|주거|리조트|PRIDE LAND|온천"
    "Branding" = "앰플|뷰티|Wear|광고|마케팅|유통|올리브영|프랜차이즈"
    "Patent" = "특허|마이닝|발명|IP|FTO|3D"
    "Talent" = "채용|인재|파이프라인|병역|교육|주니어"
    "Other" = "물류|드론|관리|정책|기타"  # For unmatched files
}

# Create folders
foreach ($cat in $categories.Keys) {
    $folder = "$base\$cat"
    if (-not (Test-Path $folder)) { New-Item -ItemType Directory -Path $folder | Out-Null }
}

# Categorize files (move to first matching folder)
$files = Get-ChildItem -Path $base -Filter "*.md" | Sort-Object Name | Where-Object { $_.Name -notlike "*index*" -and $_.Name -notlike "*all-in-one*" -and $_.Name -notlike "organize-*.ps1" }
foreach ($f in $files) {
    $moved = $false
    foreach ($cat in $categories.Keys) {
        if ($f.Name -match $categories[$cat]) {
            Move-Item $f.FullName "$base\$cat\$($f.Name)"
            $moved = $true
            break
        }
    }
    if (-not $moved) {
        Move-Item $f.FullName "$base\Other\$($f.Name)"  # Unmatched to Other
    }
}

# Generate new index.md (with categories)
$index = "$base\index.md"
"# Auto Categorized Index" | Out-File $index -Encoding utf8
foreach ($cat in $categories.Keys) {
    $catFiles = Get-ChildItem "$base\$cat" -Filter "*.md"
    "## $cat" | Out-File $index -Append -Encoding utf8
    foreach ($cf in $catFiles) {
        "- [$($cf.Name)](./$cat/$($cf.Name))" | Out-File $index -Append -Encoding utf8
    }
    "" | Out-File $index -Append -Encoding utf8
}

# Generate new all-in-one.md (categorized)
$all = "$base\all-in-one.md"
"# Combined All (Categorized)" | Out-File $all -Encoding utf8
foreach ($cat in $categories.Keys) {
    $catFiles = Get-ChildItem "$base\$cat" -Filter "*.md"
    "## $cat Section" | Out-File $all -Append -Encoding utf8
    foreach ($cf in $catFiles) {
        "### $($cf.Name)" | Out-File $all -Append -Encoding utf8
        Get-Content "$base\$cat\$($cf.Name)" | Out-File $all -Append -Encoding utf8
        "`n---`n" | Out-File $all -Append -Encoding utf8
    }
}

Write-Host "✅ Categorization Done! Check new index.md and all-in-one.md. Backup: $backup"