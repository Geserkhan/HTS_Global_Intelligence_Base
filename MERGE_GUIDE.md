---
category: "Merge Guide"
summary: "HTS_Project_BusinessPlans 내용을 HTS_Global_Intelligence_Base에 병합 지시서 (고민 내용 → 최신 구조 통합)"
related_core:
  - 05_BusinessPlans_Archive
  - META_BRIDGE
tags: ["Merge", "GitHub", "Integration", "Business Plans"]
updated: "2025-10-23"
author: "게세르 칸"
---

# 🔗 HTS 저장소 병합 지시서

HTS_Project_BusinessPlans (고민 내용: Finance/Energy MD 파일들)의 "많은 내용"을 HTS_Global_Intelligence_Base (최신본: DAO/TRR/ADGM 구조)에 추가합니다. 목표: BusinessPlans를 "자료 아카이브"에서 "중심 허브의 일부"로 업그레이드 (e.g., Finance ~13개 파일을 05_BusinessPlans_Archive 아래 병합).

## 병합 원칙
- **메인 저장소**: HTS_Global_Intelligence_Base (기존 구조 유지).
- **추가 범위**: BusinessPlans의 주요 MD 파일 (Finance, Energy 등 ~50개) — all-in-one.md는 요약으로 통합.
- **효과**: AI 지시 시 "Global_Intelligence_Base 전체 + BusinessPlans Finance 참조" 자동.
- **주의**: 파일 중복 피함 (이름 변경 e.g., finance_dao_bp.md).

## 단계별 병합 가이드 (GitHub 웹으로, 5분)
1. **BusinessPlans 다운로드**: https://github.com/Geserkhan/HTS_Project_BusinessPlans → "Code > Download ZIP" → 바탕화면에 풀기.
2. **주요 파일 선택**: Finance 폴더 (13개 MD), Energy (10개), index.md, all-in-one.md 등 "고민 내용" 중심으로 ~50개 ZIP 압축.
3. **Global_Intelligence_Base에 업로드**:
   - https://github.com/Geserkhan/HTS_Global_Intelligence_Base → "Add file > Upload files".
   - "05_BusinessPlans_Archive" 새 폴더 만들기 (드래그 시 자동).
   - BusinessPlans ZIP 파일/폴더 드래그 → 05_BusinessPlans_Archive 아래 업로드 (e.g., Finance 폴더 전체 드래그).
   - "Commit changes" → 메시지 "Merge BusinessPlans content to 05_Archive".
4. **README 업데이트**: README.md 편집 → Directory Structure 5번에 "(Finance ~13개 추가)" 상세 추가 → Commit.
5. **META_BRIDGE 연결**: META_BRIDGE/01_Structure_Map.md 편집 → 아래 Mermaid 추가:
6. **테스트**: AI 지시: "https://github.com/Geserkhan/HTS_Global_Intelligence_Base의 05_BusinessPlans_Archive Finance 폴더 읽고, TRR 구조 연동 개선안 제안해."

## AI 지시 템플릿 (병합 후 사용)
- GPT/Claude: "Global_Intelligence_Base의 05_Archive Finance와 01_HTS_DAO_TRR_Master 비교, RWA 정합성 검증해."
- Gemini: "병합된 BusinessPlans Energy 섹션 시각화 그래프 만들어줘."

## 문제 해결
- 파일 중복: 이름 변경 (e.g., bp_finance_dao.md).
- 크기 초과: 50개씩 나눠 업로드.
- 백업: 로컬 ZIP 보관.
