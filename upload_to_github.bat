@echo off
REM ======================================
REM HTS Global Intelligence Base GitHub Uploader
REM ======================================

set ROOT=%CD%
echo Uploading HTS_Global_Intelligence_Base to GitHub from %ROOT%

REM 1. .gitignore ���� (��� ����)
if not exist "%ROOT%\.gitignore" (
    echo # Ignore backups and temp files > "%ROOT%\.gitignore"
    echo backup_* >> "%ROOT%\.gitignore"
    echo *.bat >> "%ROOT%\.gitignore"
    echo.
)

REM 2. Git �ʱ�ȭ (�̹� ������ ��ŵ)
if not exist "%ROOT%\.git" (
    git init
    git add .
    git commit -m "Initial HTS Global Intelligence Base commit"
)

REM 3. GitHub ����� ���� & Ǫ�� (�������� �α��� ����)
echo Opening GitHub for repository creation...
gh repo create HTS-Global-Intelligence-Base --public --source=. --remote=origin --push -y

REM ���� gh CLI�� ������, �Ʒ� ���� ��� ��� (VS Code �͹̳ο���)
REM git remote add origin https://github.com/Geserkhan/HTS-Global-Intelligence-Base.git
REM git branch -M main
REM git push -u origin main

echo Done! Check https://github.com/Geserkhan/HTS-Global-Intelligence-Base
pause