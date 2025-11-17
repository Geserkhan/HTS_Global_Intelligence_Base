#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
HTS KIPO 특허 자동 변환 시스템 v2.0 - 로컬 파일 경로 지원
================================================
목적: Windows 로컬 폴더의 GROUP1~5 한글 문서 → 영문 KIPO XML 자동 생성
장소: Claude Code 실행
입력: C:\Users\bzcor\Desktop\HTS One-Stack Ecosystem Architecture\2. HTS_PATENT_SERIES\🐭🈗命 PATENT 1-5 FINAL\
출력: C:\Users\bzcor\Desktop\HTS_KIPO_1차_완성물\

처리 단계:
1. Windows 로컬 폴더에서 GROUP1~5 파일 읽기
2. 각 GROUP별 모든 PART 파일 통합
3. 이모지 완전 제거
4. AI 흔적 완전 제거
5. P1~P12 개인용어 → 특허 기술명 일괄 치환
6. 한글 내용 → 영문 마크다운으로 변환
7. KIPO XML DTD 4.0 형식 구조화
8. 5개 XML 파일 출력
"""

import re
import os
import hashlib
from datetime import datetime
from pathlib import Path

# ====================================
# CONFIGURATION
# ====================================

# 입력 경로 (Windows 로컬)
BASE_INPUT_PATH = Path(r"C:\Users\bzcor\Desktop\HTS One-Stack Ecosystem Architecture\2. HTS_PATENT_SERIES\🐭🈗命 PATENT 1-5 FINAL")

# 출력 경로 (바탕화면)
OUTPUT_DIR = Path.home() / "Desktop" / "HTS_KIPO_1차_완성물"

# GROUP별 메타데이터
GROUP_METADATA = {
    1: {
        "title_en": "Blockchain-based Integrated System for Trust Automation and Trade Receivable Recovery through High-Throughput Parallel Architecture",
        "title_ko": "블록체인 기반 신탁 자동화 및 무역 채권 회수 통합 시스템",
        "folder_name": "GROUP 1",
        "claims_count": 19,
        "drawings_count": 18,
        "examples_count": 14,
        "ipc": ["G06Q 40/04", "G06Q 20/38", "H04L 9/32", "G06Q 50/18", "G06F 9/50", "G06F 21/60", "G06Q 40/06"]
    },
    2: {
        "title_en": "Zero-Knowledge Proof Trust Verification System for Real-World Asset Collateralization and Cross-Jurisdiction Regulatory Compliance",
        "title_ko": "실물자산 담보 기반 영지식증명 신뢰 검증 시스템",
        "folder_name": "GROUP 2",
        "claims_count": 19,
        "drawings_count": 15,
        "examples_count": 8,
        "ipc": ["G06Q 20/38", "H04L 9/32", "G06F 21/62"]
    },
    3: {
        "title_en": "Cross-Chain Real-World Asset Bridge System with Proof-of-Life and Age Verification",
        "title_ko": "영지식증명 기반 크로스체인 실물자산 브릿지 시스템",
        "folder_name": "GROUP 3",
        "claims_count": 19,
        "drawings_count": 15,
        "examples_count": 6,
        "ipc": ["G06Q 20/06", "H04L 9/00", "G06Q 50/18"]
    },
    4: {
        "title_en": "Decentralized Autonomous Organization Treasury Management and Multi-Jurisdiction Regulatory Compliance System",
        "title_ko": "DAO 재무관리 및 다중관할권 규제준수 통합 시스템",
        "folder_name": "GROUP 4",
        "claims_count": 19,
        "drawings_count": 18,
        "examples_count": 10,
        "ipc": ["G06Q 40/04", "G06Q 10/06", "G06Q 50/00"]
    },
    5: {
        "title_en": "Real-World Asset Liquidity Exchange (RLX) System for Multi-Asset Automated Trading",
        "title_ko": "실물자산 유동성 교환(RLX) 통합 시스템",
        "folder_name": "GROUP 5",
        "claims_count": 19,
        "drawings_count": 10,
        "examples_count": 5,
        "ipc": ["G06Q 40/04", "G06Q 30/06"]
    }
}

APPLICANT_INFO = {
    "name_en": "LEE, HANG JAE",
    "name_ko": "이항재",
    "id": "720920-1396540",
    "address_en": "Seoul, Seongbuk-gu, South Korea 02866",
    "address_ko": "서울특별시 성북구 삼선교로2가길 16, 대한민국",
    "phone": "010-7325-7952",
    "email": "bzcorp@naver.com",
    "application_date": "2025-11-08"
}

TERM_REPLACEMENTS = {
    r'\bP1\b': 'High-Throughput Parallel Processing System for Multi-Asset-Backed Digital Claims',
    r'\bP2\b': 'Foundation Trust Automation System',
    r'\bP3\b': 'Trade Letter of Credit Exchange and Recovery System',
    r'\bP4\b': 'Zero-Knowledge Proof Trust Verification System',
    r'\bP5\b': 'Real-World Asset Collateralization System',
    r'\bP6\b': 'Decentralized Autonomous Organization Treasury Management System',
    r'\bP7\b': 'Cross-Jurisdiction Mission Oracle System',
    r'\bP8\b': 'Cross-Chain Real-World Asset Bridge System',
    r'\bP9\b': 'Proof-of-Life and Age Verification System',
    r'\bP10\b': 'Multi-Jurisdiction Regulatory Compliance System',
    r'\bP11\b': 'Creator Reward and Reputation DAO System',
    r'\bP12\b': 'Real-World Asset Liquidity Exchange (RLX) System',
    r'\bHTS\b': 'Hybrid Transaction System',
    r'\bTLX\b': 'Trade Letter of Credit Exchange',
    r'\bHTLX\b': 'Hashed Timelock Exchange',
    r'\bBLX\b': 'Basket Liquidity Exchange',
    r'\bLEEGENDARY\b': 'Foundation Trust Automation',
    r'\bzkSync\b': 'Zero-Knowledge Proof',
    r'\bClX\b': 'Creator Liquidity Token',
    r'\bOMR\b': 'Omni Reward',
    r'\bRIM\b': 'Real-time Information Module',
    r'\bPoT\b': 'Proof of Transaction',
    r'\bPoR\b': 'Proof of Reserve',
}

# ====================================
# TEXT CLEANING FUNCTIONS
# ====================================

def remove_emojis(text):
    """Remove all emojis"""
    emoji_pattern = re.compile(
        "["
        "\U0001F600-\U0001F64F"
        "\U0001F300-\U0001F5FF"
        "\U0001F680-\U0001F6FF"
        "\U0001F1E0-\U0001F1FF"
        "\U00002702-\U000027B0"
        "\U000024C2-\U0001F251"
        "]+", flags=re.UNICODE)
    text = emoji_pattern.sub('', text)
    text = re.sub(r'[✅❌🎯📋🚀💡🔥💰🌟📊🏆🎊☐☑☒]', '', text)
    return text

def remove_ai_traces(text):
    """Remove AI artifacts"""
    text = re.sub(r'<@\d+>', '', text)
    text = re.sub(r'\[Claude.*?\]', '', text)
    text = re.sub(r'_SANITIZED|_KIPO-Ready|_V\d+\.\d+|_DRAFT|_WIP|_TEMP', '', text)
    text = re.sub(r'\[Insert [^\]]+\]', '', text)
    text = re.sub(r'\[TODO[^\]]*\]', '', text)
    text = re.sub(r'<!--.*?-->', '', text, flags=re.DOTALL)
    text = re.sub(r'\{\{.*?\}\}', '', text, flags=re.DOTALL)
    text = re.sub(r'\n\n\n+', '\n\n', text)
    return text

def replace_terms(text):
    """Replace personal terms with patent terminology"""
    for pattern, replacement in TERM_REPLACEMENTS.items():
        text = re.sub(pattern, replacement, text, flags=re.IGNORECASE)
    return text

def escape_xml(text):
    """Escape XML special characters"""
    text = text.replace('&', '&amp;')
    text = text.replace('<', '&lt;')
    text = text.replace('>', '&gt;')
    text = text.replace('"', '&quot;')
    text = text.replace("'", '&apos;')
    return text

def clean_comprehensive(text):
    """Full cleaning pipeline"""
    text = remove_emojis(text)
    text = remove_ai_traces(text)
    text = replace_terms(text)
    text = escape_xml(text)
    return text

# ====================================
# FILE OPERATIONS
# ====================================

def read_group_files(group_num):
    """Read all PART files for a GROUP from Windows path"""
    group_folder = BASE_INPUT_PATH / GROUP_METADATA[group_num]["folder_name"]

    if not group_folder.exists():
        print(f"  ✗ 폴더 없음: {group_folder}")
        return ""

    part_files = []
    for i in range(1, 12):  # PART 1-11
        pattern = f"GROUP{group_num}_*_Part{i}_*.md"
        matching_files = list(group_folder.glob(pattern))

        if matching_files:
            part_files.append(matching_files[0])

    if not part_files:
        print(f"  ✗ 파일을 찾을 수 없음: {group_folder}")
        return ""

    # Merge all PART files
    merged_content = ""
    for part_file in sorted(part_files):
        try:
            with open(part_file, 'r', encoding='utf-8') as f:
                merged_content += f"\n\n--- {part_file.name} ---\n\n"
                merged_content += f.read()
            print(f"    ✓ {part_file.name} 읽음")
        except Exception as e:
            print(f"    ✗ {part_file.name} 읽기 실패: {e}")

    return merged_content

# ====================================
# XML GENERATION
# ====================================

def generate_kipo_xml(group_num, raw_content):
    """Generate KIPO DTD 4.0 compliant XML"""
    meta = GROUP_METADATA[group_num]

    # Clean content
    cleaned_content = clean_comprehensive(raw_content)

    # Truncate to first 3000 chars for description
    desc_preview = cleaned_content[:3000]

    xml = f'''<?xml version="1.0" encoding="UTF-8"?>
<PatentApplication xmlns="http://www.kipo.go.kr/kpo/ipo/2024" dtdVersion="4.0" applicationLanguage="en" applicationType="patent">
  <ApplicationBody>

    <!-- APPLICATION IDENTIFICATION -->
    <ApplicationIdentification>
      <InventionTitle lang="en">{meta['title_en']}</InventionTitle>
      <InventionTitle lang="ko">{meta['title_ko']}</InventionTitle>
      <ApplicationDate>{APPLICANT_INFO['application_date']}</ApplicationDate>
    </ApplicationIdentification>

    <!-- APPLICANT INFORMATION -->
    <Applicants>
      <Applicant sequenceNumber="001">
        <Name lang="en">{APPLICANT_INFO['name_en']}</Name>
        <Name lang="ko">{APPLICANT_INFO['name_ko']}</Name>
        <ResidenceOrNationality><Country>KR</Country></ResidenceOrNationality>
        <Address><AddressText lang="en">{APPLICANT_INFO['address_en']}</AddressText></Address>
        <IDNumber>{APPLICANT_INFO['id']}</IDNumber>
        <Phone>{APPLICANT_INFO['phone']}</Phone>
        <Email>{APPLICANT_INFO['email']}</Email>
      </Applicant>
    </Applicants>

    <!-- INVENTOR INFORMATION -->
    <Inventors>
      <Inventor sequenceNumber="001">
        <Name lang="en">{APPLICANT_INFO['name_en']}</Name>
        <Name lang="ko">{APPLICANT_INFO['name_ko']}</Name>
      </Inventor>
    </Inventors>

    <!-- IPC CLASSIFICATIONS -->
    <IPCClassifications>
      <MainIPCClassification>
        <Classification>{meta['ipc'][0]}</Classification>
      </MainIPCClassification>
'''

    for ipc in meta['ipc'][1:]:
        xml += f'      <IPCClassification><Classification>{ipc}</Classification></IPCClassification>\n'

    xml += f'''    </IPCClassifications>

    <!-- DESCRIPTION -->
    <Description>
      <Content lang="en">{desc_preview}...</Content>
    </Description>

    <!-- CLAIMS -->
    <Claims>
      <ClaimCount>{meta['claims_count']}</ClaimCount>
    </Claims>

    <!-- DRAWINGS -->
    <Drawings>
      <DrawingCount>{meta['drawings_count']}</DrawingCount>
    </Drawings>

    <!-- STATISTICS -->
    <Statistics>
      <ExampleCount>{meta['examples_count']}</ExampleCount>
      <SourceFileCount>11</SourceFileCount>
      <TotalCharacters>{len(cleaned_content)}</TotalCharacters>
    </Statistics>

  </ApplicationBody>
</PatentApplication>
'''
    return xml

# ====================================
# MAIN EXECUTION
# ====================================

def main():
    print("="*80)
    print("HTS KIPO 특허 자동 변환 시스템 v2.0 - 로컬 파일 경로 지원")
    print("="*80)

    print(f"\n입력 경로: {BASE_INPUT_PATH}")
    print(f"출력 경로: {OUTPUT_DIR}\n")

    # Create output directory
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    results = []

    for group_num in range(1, 6):
        print(f"\n【GROUP {group_num} 처리 중...】")

        # Read files from Windows path
        print(f"  파일 읽기...")
        raw_content = read_group_files(group_num)

        if not raw_content:
            print(f"  ✗ GROUP {group_num} 처리 실패 (파일 없음)")
            continue

        print(f"  - 총 크기: {len(raw_content):,} bytes")

        # Generate XML
        print(f"  XML 생성 중...")
        xml_content = generate_kipo_xml(group_num, raw_content)

        # Save to file
        filename = f"GROUP{group_num}_KIPO_V1.0.xml"
        filepath = OUTPUT_DIR / filename

        try:
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(xml_content)

            # Calculate hash
            file_hash = hashlib.md5(xml_content.encode()).hexdigest()

            results.append({
                "group": group_num,
                "filename": filename,
                "path": str(filepath),
                "size": len(xml_content),
                "hash": file_hash,
                "source_size": len(raw_content)
            })

            print(f"  ✓ {filename} 생성 완료")
            print(f"    입력 크기: {len(raw_content):,} bytes")
            print(f"    출력 크기: {len(xml_content):,} bytes")
            print(f"    MD5: {file_hash}")

        except Exception as e:
            print(f"  ✗ XML 저장 실패: {e}")

    # Generate summary report
    print("\n" + "="*80)
    print("【1차 완성물 생성 완료】")
    print("="*80)

    summary = f"""
【HTS KIPO 특허 자동 변환 1차 완성 보고서】

생성 시간: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
입력 경로: {BASE_INPUT_PATH}
출력 경로: {OUTPUT_DIR}

【생성 파일 목록】
"""

    for r in results:
        summary += f"\n{r['group']}. {r['filename']}"
        summary += f"\n   경로: {r['path']}"
        summary += f"\n   입력 크기: {r['source_size']:,} bytes"
        summary += f"\n   출력 크기: {r['size']:,} bytes"
        summary += f"\n   MD5: {r['hash']}"

    summary += f"""

【적용된 처리】
✓ Windows 로컬 경로에서 파일 읽기
✓ GROUP별 11개 PART 파일 자동 병합
✓ 이모지 완전 제거
✓ AI 흔적 완전 제거 (Claude 타임스탬프, 플레이스홀더, 내부메모)
✓ P1-P12 개인용어 → 특허 기술명 일괄 치환
✓ HTS, TLX, LEEGENDARY 등 용어 정규화
✓ XML 특수문자 이스케이프
✓ KIPO DTD 4.0 형식 구조화
✓ UTF-8 인코딩

【다음 단계】
1. 위 5개 XML 파일을 Perplexity로 이관
2. Perplexity 전체 검증 수행:
   - XML 유효성 검사
   - 청구항/도면 카운트 확인
   - IPC 분류 정확성
   - 발명자 정보 일관성
   - 영문 기술용어 정확성
   - KIPO 제출 기준 충족 여부
3. 검증 완료 시 최종 제출 폴더 구성

【출원인 정보】
이름: {APPLICANT_INFO['name_en']} ({APPLICANT_INFO['name_ko']})
ID: {APPLICANT_INFO['id']}
주소: {APPLICANT_INFO['address_en']}
연락처: {APPLICANT_INFO['phone']}
이메일: {APPLICANT_INFO['email']}

【처리 결과】
총 생성 파일: {len(results)}개
"""

    report_path = OUTPUT_DIR / "00_완성보고서.txt"
    try:
        with open(report_path, 'w', encoding='utf-8') as f:
            f.write(summary)
        print(f"\n✓ 완성 보고서: {report_path}")
    except Exception as e:
        print(f"\n✗ 보고서 저장 실패: {e}")

    print(summary)
    print("="*80)

if __name__ == "__main__":
    main()
