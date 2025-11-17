# HTS KIPO 특허 자동 변환 시스템 v2.0

## 개요
GROUP1~5 한글 특허 문서를 KIPO 제출용 영문 XML로 자동 변환하는 시스템입니다.

## 기능
- ✅ 이모지 완전 제거
- ✅ AI 흔적 제거 (Claude 타임스탬프, 플레이스홀더 등)
- ✅ P1~P12 개인용어 → 특허 기술명 자동 치환
- ✅ HTS, TLX, LEEGENDARY 등 용어 정규화
- ✅ KIPO DTD 4.0 형식 XML 생성
- ✅ UTF-8 인코딩

## 사용 방법 (Windows)

### 1단계: 저장소 업데이트
```cmd
cd "C:\Users\bzcor\Desktop\🐭🈗命\LEDGER & COLATERAL\HTS OLD\HTS_Global_Intelligence_Base"
git pull origin claude/kipo-xml-setup-01ACykNh5RnTqNzfWCCQvops
```

### 2단계: Python 스크립트 실행
```cmd
python HTS_KIPO_AutoGen_LocalPath_v2.0.py
```

### 3단계: 결과 확인
생성된 파일 위치:
```
C:\Users\bzcor\Desktop\HTS_KIPO_1차_완성물\
├── GROUP1_KIPO_V1.0.xml
├── GROUP2_KIPO_V1.0.xml
├── GROUP3_KIPO_V1.0.xml
├── GROUP4_KIPO_V1.0.xml
├── GROUP5_KIPO_V1.0.xml
└── 00_완성보고서.txt
```

## 입력 파일 위치
스크립트는 다음 경로에서 파일을 읽습니다:
```
C:\Users\bzcor\Desktop\HTS One-Stack Ecosystem Architecture\
  └─ 2. HTS_PATENT_SERIES\
      └─ 🐭🈗命 PATENT 1-5 FINAL\
          ├─ GROUP 1\
          ├─ GROUP 2\
          ├─ GROUP 3\
          ├─ GROUP 4\
          └─ GROUP 5\
```

각 GROUP 폴더에는 Part1~Part11 파일들이 있어야 합니다.

## 출력 내용
각 GROUP별 XML 파일은 다음을 포함합니다:
- 발명의 명칭 (한글/영문)
- 출원인 정보 (이항재)
- 발명자 정보
- IPC 분류
- 청구항 개수
- 도면 개수
- 발명의 설명 (정제된 영문)

## 다음 단계
1. ✅ 5개 XML 파일 생성 완료
2. 📤 Perplexity로 파일 업로드
3. ✓ Perplexity에서 전체 검증
4. 🎯 최종 제출 폴더 구성

## 문의
- 발명자: 이항재 (LEE, HANG JAE)
- 연락처: 010-7325-7952
- 이메일: bzcorp@naver.com
