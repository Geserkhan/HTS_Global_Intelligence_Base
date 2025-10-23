@echo off
REM ======================================
REM HTS Global Intelligence Base README Creator
REM ======================================

set ROOT=%CD%

echo Creating README.md in %ROOT%

if exist "%ROOT%\README.md" (
    echo README.md already exists! Overwriting...
    del "%ROOT%\README.md"
)

(
echo # ?? HTS Global Intelligence Base
    
echo �� �������丮�� HTS DAO, TRR, ADGM, LABUAN, BLXWT, ESG Reward ��
echo �Լ��� ĭ���� ���� �������Ź��ͽ� ���°踦 ���������� ������ ���� ������Դϴ�.
echo.
echo ---
echo.
echo ## ?? Directory Structure
echo 1. [HTS DAO TRR Master](01_HTS_DAO_TRR_MASTER/_index.md)
echo 2. [ADGM Legal Core](02_ADGM_Legal_Core/_index.md)
echo 3. [LABUAN DMH BANK](03_LABUAN_DMH_BANK/_index.md)
echo 4. [BLXWT Reward System](04_BLXWT_REWARD_SYSTEM/_index.md)
echo 5. [Business Plans Archive](05_BusinessPlans_Archive.md) ? GitHub ���� �����ȹ��
echo 6. [Appendices](99_Appendices/_index.md)
echo 7. [Meta Bridge (AI Integration)](META_BRIDGE/)
echo.
echo ---
echo.
echo ## ?? AI Collaboration Notes
echo ^> GPT: TRR ���� �� FSRA ���ռ� ����
echo ^> Claude: ADGM ���� ���� ���� �� ���� �ʿ�
echo ^> Gemini: ESG ^& Welfare ������ �ð�ȭ
echo ^> Perplexity: �ֽ� ���̼��� ���� �߰�
echo ^> Grok: � �Ŵ��� �� ���μ��� ����ȭ
echo.
echo ---
echo.
echo ## ?? Next Step
echo 1. �� ������ ���� ���� ���ε� ^(.md or .docx^)
echo 2. _index.md�� ���� ��ϰ� ���� �߰�
echo 3. GitHub�� Push �� ��� AI�� ���� �����ϰ� ����
echo.
echo Business Plans Archive: https://github.com/Geserkhan/HTS_Project_BusinessPlans
) > "%ROOT%\README.md"

echo Done! README.md created with Business Plans link.
pause