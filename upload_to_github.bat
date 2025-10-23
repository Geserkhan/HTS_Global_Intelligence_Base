@echo off
REM ======================================
REM HTS Global Intelligence Base GitHub Uploader
REM ======================================

set ROOT=%CD%
echo Uploading HTS_Global_Intelligence_Base to GitHub from %ROOT%

REM 1. .gitignore 생성 (백업 무시)
if not exist "%ROOT%\.gitignore" (
    echo # Ignore backups and temp files > "%ROOT%\.gitignore"
    echo backup_* >> "%ROOT%\.gitignore"
    echo *.bat >> "%ROOT%\.gitignore"
    echo.
)

REM 2. Git 초기화 (이미 있으면 스킵)
if not exist "%ROOT%\.git" (
    git init
    git add .
    git commit -m "Initial HTS Global Intelligence Base commit"
)

REM 3. GitHub 저장소 생성 & 푸시 (브라우저로 로그인 유도)
echo Opening GitHub for repository creation...
gh repo create HTS-Global-Intelligence-Base --public --source=. --remote=origin --push -y

REM 만약 gh CLI가 없으면, 아래 수동 명령 사용 (VS Code 터미널에서)
REM git remote add origin https://github.com/Geserkhan/HTS-Global-Intelligence-Base.git
REM git branch -M main
REM git push -u origin main

echo Done! Check https://github.com/Geserkhan/HTS-Global-Intelligence-Base
pause