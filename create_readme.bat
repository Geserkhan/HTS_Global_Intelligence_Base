@echo off
chcp 65001 >nul
REM ======================================
REM HTS Global Intelligence Base README Creator (UTF-8 Safe)
REM ======================================

set ROOT=%CD%

echo Creating README.md in %ROOT%

if exist "%ROOT%\README.md" (
    echo README.md already exists! Overwriting...
    del "%ROOT%\README.md"
)

(
echo # ^ 🧭 HTS Global Intelligence Base
    
echo.
echo 이 리포지토리는 HTS DAO, TRR, ADGM, LABUAN, BLXWT, ESG Reward 등
echo 게세르 칸님의 통합 금융^·거버넌스 생태계를 구조적으로 정리한 지식 저장소입니다.
echo.
echo ---
echo.
echo ## 📚 Directory Structure
echo 1. [HTS DAO TRR Master](01_HTS_DAO_TRR_MASTER/_index.md)
echo 2. [ADGM Legal Core](02_ADGM_Legal_Core/_index.md)
echo 3. [LABUAN DMH BANK](03_LABUAN_DMH_BANK/_index.md)
echo 4. [BLXWT Reward System](04_BLXWT_REWARD_SYSTEM/_index.md)
echo 5. [Business Plans Archive](05_BusinessPlans_Archive.md) — GitHub 연동 사업계획서
echo 6. [Appendices](99_Appendices/_index.md)
echo 7. [Meta Bridge ^(AI Integration^)](META_BRIDGE/)
echo.
echo ---
echo.
echo ## 🤖 AI Collaboration Notes
echo ^> GPT: TRR 구조 및 FSRA 정합성 검증  
echo ^> Claude: ADGM 법인 서류 정리 및 보완 필요  
echo ^> Gemini: ESG ^& Welfare 데이터 시각화  
echo ^> Perplexity: 최신 라이선스 기준 추가  
echo ^> Grok: 운영 매뉴얼 및 프로세스 최적화
echo.
echo ---
echo.
echo ## 🪶 Next Step
echo 1. 각 폴더에 실제 문서 업로드 ^(.md or .docx^)
echo 2. _index.md에 파일 목록과 설명 추가
echo 3. GitHub에 Push → 모든 AI가 접근 가능하게 설정
) > "%ROOT%\README.md"

echo Done! README.md created with Business Plans link.
pause