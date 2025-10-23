<#
organize-md-advanced.ps1
Windows PowerShell script for HTS .md auto-organization
Features:
 - dry-run mode (no file moves)
 - automatic backup (backup/YYYYMMDD_HHMMSS)
 - category-based sorting (regex keywords)
 - index.md and all-in-one.md generation
 - csv/json index export
 - optional numbering prefix per category
 - logging to organize-log.txt
Usage examples:
 .\organize-md-advanced.ps1 -DryRun
 .\organize-md-advanced.ps1 -Backup
 .\organize-md-advanced.ps1 -NumberFiles
#>

param(
    [switch]$DryRun,       # If set, no file will be moved; actions logged only
    [switch]$Backup,       # If set, create a timestamped backup copy before moving
    [switch]$NumberFiles,  # If set, add numeric prefixes within each category
    [string]$Encoding = "utf8"  # File encoding for outputs
)

# --- Initialization
$base = Get-Location
$now = Get-Date -Format "yyyyMMdd_HHmmss"
$logPath = Join-Path $base "organize-log-$now.txt"

Function Log {
    param($msg)
    $t = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$t] $msg"
    $line | Tee-Object -FilePath $logPath -Append
    Write-Host $line
}

Log "Starting organize-md-advanced.ps1 (DryRun=$DryRun, Backup=$Backup, NumberFiles=$NumberFiles)"

# --- Collect .md files (exclude index/all-in-one)
$allMd = Get-ChildItem -Path $base -Filter "*.md" -File -Recurse |
         Where-Object { $_.FullName -notmatch "index\.md$|all-in-one\.md$|organize-md-advanced\.ps1$" } |
         Sort-Object FullName

if ($allMd.Count -eq 0) {
    Log "No .md files found in $base. Exiting."
    exit 1
}

# --- Optional Backup (copy whole folder)
if ($Backup) {
    $backupFolder = Join-Path $base "backup_$now"
    Log "Creating backup at $backupFolder"
    if (-not $DryRun) {
        New-Item -ItemType Directory -Path $backupFolder | Out-Null
        foreach ($f in $allMd) {
            $rel = $f.FullName.Substring($base.Path.Length).TrimStart('\')
            $dest = Join-Path $backupFolder $rel
            $destDir = Split-Path $dest -Parent
            if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir | Out-Null }
            Copy-Item -Path $f.FullName -Destination $dest
        }
    } else {
        Log "(DryRun) Backup skipped copy step - would create $backupFolder"
    }
}

# --- Category map (adjust regexes if you want)
$categories = @{
    "00_농업-식품" = "farm|동애등에|농장|계림|계란|토하|순환|식품|레시피|사육|BSF|앰플"
    "01_에너지-인프라" = "LNG|ESS|수소|에너지|발전|항만|DH Capacitor|Eflow|AFPM|ESS|수소"
    "02_금융-RWA" = "DAO|RWA|TRR|투자|금융|은행|담보|주식 담보|블랙록|Labuan|ADGM"
    "03_부동산-레지던스" = "호텔|사택|세컨하우스|주거|리조트|PRIDE LAND|부동산|온천"
    "04_브랜딩-유통" = "앰플|뷰티|Wear|광고|마케팅|유통|올리브영|프랜차이즈|ZIPCODE"
    "05_특허-IP" = "특허|마이닝|발명|IP|FTO|발전기|3D 프린팅"
    "06_인재-조직" = "채용|인재|파이프라인|병역|교육|주니어"
    "07_운영-기타" = "물류|드론|시간 단축|관리|관여도|정책자금|기타"
}

# --- Create category folders
foreach ($cat in $categories.Keys) {
    $dest = Join-Path $base $cat
    if (-not (Test-Path $dest)) {
        Log "Creating folder: $dest"
        if (-not $DryRun) { New-Item -ItemType Directory -Path $dest | Out-Null }
    }
}

# --- Move files to categories (first matching category wins)
$unmatched = @()
foreach ($f in $allMd) {
    $matched = $false
    foreach ($cat in $categories.Keys) {
        $pattern = $categories[$cat]
        if ($f.Name -match [regex]::Escape($pattern) -or ($f.Name -match $pattern) -or ($f.BaseName -match $pattern)) {
            $destPath = Join-Path $base $cat $f.Name
            Log "MOVING: $($f.Name) -> $cat"
            if (-not $DryRun) {
                Move-Item -Path $f.FullName -Destination $destPath -Force
            }
            $matched = $true
            break
        }
    }
    if (-not $matched) {
        $unmatched += $f
    }
}

# --- Put unmatched into 07_운영-기타/UNSORTED
if ($unmatched.Count -gt 0) {
    $unsDir = Join-Path $base "07_운영-기타\UNSORTED"
    if (-not (Test-Path $unsDir)) { if (-not $DryRun) { New-Item -ItemType Directory -Path $unsDir | Out-Null } else { Log "(DryRun) Would create $unsDir" } }
    foreach ($u in $unmatched) {
        Log "UNMATCHED -> $($u.Name)"
        if (-not $DryRun) {
            Move-Item -Path $u.FullName -Destination (Join-Path $unsDir $u.Name) -Force
        }
    }
}

# --- Optional: Number files inside each category (prefix 01_,02_ ...)
if ($NumberFiles -and -not $DryRun) {
    foreach ($cat in $categories.Keys) {
        $dir = Join-Path $base $cat
        $filesInCat = Get-ChildItem -Path $dir -Filter "*.md" | Sort-Object Name
        $i = 1
        foreach ($fi in $filesInCat) {
            $prefix = "{0:D3}_" -f $i
            if (-not ($fi.Name -match "^\d{3}_")) {
                $newName = $prefix + $fi.Name
                Log "Renaming $($fi.Name) -> $newName"
                Rename-Item -Path $fi.FullName -NewName $newName
            }
            $i++
        }
    }
} elseif ($NumberFiles -and $DryRun) {
    Log "(DryRun) NumberFiles requested but skipped (dry run)."
}

# --- Generate index.md (markdown), all-in-one.md, index.csv, index.json
$indexMd = Join-Path $base "index.md"
$allOne = Join-Path $base "all-in-one.md"
$csvOut = Join-Path $base "index-$now.csv"
$jsonOut = Join-Path $base "index-$now.json"

if (-not $DryRun) {
    # header
    "# 📚 HTS 사업계획서 자동 인덱스" | Out-File $indexMd -Encoding $Encoding
    "" | Out-File $indexMd -Append -Encoding $Encoding

    "# 📘 HTS 전체 사업계획서 합본" | Out-File $allOne -Encoding $Encoding
    "" | Out-File $allOne -Append -Encoding $Encoding

    $csvHeader = "Category,FileName,RelativePath"
    $csvHeader | Out-File $csvOut -Encoding $Encoding

    $jsonArr = @()
}

foreach ($cat in $categories.Keys) {
    $dir = Join-Path $base $cat
    $filesInCat = @()
    if (Test-Path $dir) {
        $filesInCat = Get-ChildItem -Path $dir -Filter "*.md" | Sort-Object Name
    }
    if (-not $DryRun) {
        "## $cat" | Out-File $indexMd -Append -Encoding $Encoding
    } else {
        Log "(DryRun) Would add section ## $cat to index.md"
    }
    foreach ($fi in $filesInCat) {
        $rel = (Resolve-Path $fi.FullName).Path.Substring($base.Path.Length).TrimStart('\') -replace '\\','/'
        if (-not $DryRun) {
            "- [$($fi.Name)](./$rel)" | Out-File $indexMd -Append -Encoding $Encoding
            "### $($fi.Name)" | Out-File $allOne -Append -Encoding $Encoding
            Get-Content $fi.FullName | Out-File $allOne -Append -Encoding $Encoding
            "`n---`n" | Out-File $allOne -Append -Encoding $Encoding
            "$cat, $($fi.Name), $rel" | Out-File $csvOut -Append -Encoding $Encoding
            $jsonArr += [pscustomobject]@{category=$cat; filename=$fi.Name; path=$rel}
        } else {
            Log "(DryRun) Would add file $($fi.Name) in $cat to index/all-in-one"
        }
    }
    if (-not $DryRun) { "" | Out-File $indexMd -Append -Encoding $Encoding }
}

if (-not $DryRun) {
    $jsonArr | ConvertTo-Json -Depth 5 | Out-File $jsonOut -Encoding $Encoding
    Log "Index files written: index.md, all-in-one.md, $csvOut, $jsonOut"
} else {
    Log "(DryRun) Index generation skipped"
}

Log "Done."