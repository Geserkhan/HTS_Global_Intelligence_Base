# CLAUDE.md - AI Assistant Guide for HTS Global Intelligence Base

> **Last Updated:** 2025-11-18
> **Version:** 1.0
> **Maintainer:** 항TGK
> **Purpose:** Comprehensive guide for AI assistants working with the HTS Global Intelligence Base repository

---

## 📋 Table of Contents

1. [Repository Overview](#repository-overview)
2. [Directory Structure](#directory-structure)
3. [Documentation Conventions](#documentation-conventions)
4. [AI Collaboration Patterns](#ai-collaboration-patterns)
5. [File Naming Conventions](#file-naming-conventions)
6. [Development Workflow](#development-workflow)
7. [Git Branch Strategy](#git-branch-strategy)
8. [Key Entry Points](#key-entry-points)
9. [Metadata Standards](#metadata-standards)
10. [Best Practices for AI Assistants](#best-practices-for-ai-assistants)

---

## 🎯 Repository Overview

**HTS Global Intelligence Base** is an AI-readable knowledge repository that serves as the central hub for:

- **HTS DAO** - Decentralized Autonomous Organization structure
- **TRR (Trade Recovery Right)** - Core financial instrument and protocol
- **ADGM Legal Framework** - Abu Dhabi Global Market regulatory compliance
- **LABUAN DMH Bank** - Digital Merchant Bank infrastructure
- **BLXWT Reward System** - BLX World Trade tokenomics and rewards
- **Business Plans Archive** - Historical and current strategic documents
- **Meta Bridge AI Integration** - AI collaboration and automation systems

### Primary Languages
- **Korean** - Primary business and strategic documentation
- **English** - Technical specifications and international legal documents
- **Mixed** - Many documents use both languages strategically

### Target AI Models
- GPT-5 (OpenAI)
- Claude (Anthropic)
- Perplexity
- Gemini (Google)
- Grok

---

## 📂 Directory Structure

The repository follows a numbered, hierarchical organization designed for AI navigation:

```
HTS_Global_Intelligence_Base/
│
├── 01_HTS_DAO_TRR_MASTER/          # Core TRR system and DAO structure
│   ├── _index.md                    # Directory index (READ FIRST)
│   ├── README.md                    # Overview
│   ├── P1_TRR_System_Patent_Spec.md.md
│   ├── P2_BLXWT_NonRedeemable_Token_Patent_Spec.md.md
│   ├── P3_DAO_TRR_Pool_Patent_Spec.md.md
│   ├── P4_Corporate_Segregation_Ecosystem_Patent_Spec.md.md
│   └── HTS_DAO_TRR_Whitepaper_v2.md.md
│
├── 02_ADGM_Legal_Core/              # ADGM regulatory compliance
│   ├── _index.md
│   ├── fsra_*.md                    # FSRA regulatory documents
│   ├── blx-*.md                     # BLX-related legal documents
│   └── dmhb-*.md                    # DMH Bank documents
│
├── 03_LABUAN_DMH_BANK/              # Labuan Digital Merchant Bank
│   ├── _index.md
│   ├── DMH_BANK_LICENSE_UPDATED.md.md
│   └── dmhb_dlt_foundation_bp.md
│
├── 04_BLXWT_REWARD_SYSTEM/          # BLX World Trade rewards
│   ├── _index.md
│   └── blx-reward-korea-bp.md
│
├── 05_Archive/                      # Historical documents
│   └── BusinessPlans/
│       ├── index.md
│       ├── all-in-one.md            # Consolidated business plans
│       ├── Finance/                 # ~13 financial strategy docs
│       ├── Energy/                  # ~10 energy sector docs
│       ├── Patent/                  # Patent strategy documents
│       ├── RealEstate/              # Real estate plans
│       ├── Talent/                  # HR and recruitment
│       ├── Agriculture/             # Agricultural projects
│       ├── Branding/                # Marketing strategies
│       └── Other/                   # Miscellaneous
│
├── 99_Appendices/                   # Supporting materials
│   ├── _index.md
│   ├── HTS_DAO_TRR_Master_v2.md.md
│   └── DTRR-BORDERLINE-LEGENDARY-V3.1-Part*.md
│
├── Meta_Bridge_AI_Integration/      # AI collaboration framework
│   └── _index.md
│
├── .github/workflows/               # CI/CD workflows
│   ├── archive-agriculture.yml
│   └── archive-finance.yml
│
├── ai-meta.yaml                     # AI metadata configuration
├── README.md                        # Repository map
├── MERGE_GUIDE.md                   # Repository merge instructions
└── CLAUDE.md                        # This file
```

### Directory Numbering System

Directories use a prefix numbering system to indicate priority and reading order:
- `01_` - Core/Foundation (highest priority)
- `02_` - Legal/Regulatory
- `03_` - Banking/Financial Infrastructure
- `04_` - Reward Systems
- `05_` - Archives
- `99_` - Appendices/Supporting materials

---

## 📝 Documentation Conventions

### Index Files (`_index.md`)

**CRITICAL:** Every major directory contains an `_index.md` file that must be read FIRST before exploring other files in that directory.

Index files follow this structure:
```markdown
# [Directory Name] Index

Brief description of the directory's purpose

## 📘 주요 문서 목록 (Document List)
| 파일명 | 설명 | 상태 |
|---------|------|------|
| filename.md | Description | ✅/🔄 |

## 🔍 구조 개요 (Structure Overview)
- Key point 1
- Key point 2

## 🤖 AI 탐색 순서 (AI Navigation Order)
1. Document 1
2. Document 2
...
```

### Status Indicators

Documents use emoji indicators for status:
- ✅ **완료** (Completed) - Document is finalized
- 🔄 **진행중** (In Progress) - Document is being updated
- ⚠️ **검토 필요** (Needs Review) - Document needs attention
- ✓ **Archived** - Historical document (prefix in filename)

### File Naming Patterns

1. **Patent Specifications:** `P[N]_[Topic]_Patent_Spec.md.md`
   - Example: `P1_TRR_System_Patent_Spec.md.md`

2. **Business Plans:** `[prefix]-[topic]-[version].md`
   - Example: `fsra_blx_core_bp_v2_2.md`

3. **Archived Documents:** `✓ [description].md`
   - Example: `✓ 특허마이닝 전략 설계.md`

4. **Index Files:** `_index.md` (underscore prefix for priority sorting)

5. **Versioned Documents:** Suffix with version numbers
   - Example: `HTS_DAO_TRR_Whitepaper_v2.md.md`

### Double .md Extension

**Note:** Some files use `.md.md` double extension. This appears to be an artifact from file migrations. Both single and double extensions are valid in this repository.

---

## 🤖 AI Collaboration Patterns

### Recommended Reading Order

When analyzing this repository, AI assistants should follow this sequence:

1. **Root Level**
   - `README.md` - Repository map and overview
   - `ai-meta.yaml` - Metadata configuration
   - `CLAUDE.md` - This guide

2. **Core Documentation** (in order)
   - `01_HTS_DAO_TRR_MASTER/_index.md`
   - `02_ADGM_Legal_Core/_index.md`
   - `03_LABUAN_DMH_BANK/_index.md`
   - `04_BLXWT_REWARD_SYSTEM/_index.md`
   - `Meta_Bridge_AI_Integration/_index.md`

3. **Deep Dive** (as needed)
   - Follow the "AI 탐색 순서" in each `_index.md`
   - Read specific documents based on task requirements

4. **Archives** (reference only)
   - `05_Archive/BusinessPlans/index.md`
   - Specific archived documents as needed

### AI Role Assignments

Different AI models are used for specialized tasks:

- **GPT-5:** Complex analysis, strategic planning, technical writing
- **Claude:** Code generation, document editing, regulatory compliance
- **Perplexity:** Research, fact-checking, external information
- **Gemini:** Visualization, data analysis, multilingual processing
- **Grok:** Operational optimization, real-time processing

### Meta Bridge Integration

The `Meta_Bridge_AI_Integration/` directory contains:
- AI collaboration protocols
- Metadata standards (YAML format)
- Auto-indexing scripts
- LLM integration guides

Refer to these files when:
- Setting up automated workflows
- Defining document relationships
- Creating new index files
- Establishing AI collaboration patterns

---

## 🏷️ File Naming Conventions

### General Rules

1. **Use descriptive names** in Korean or English
2. **Prefix with category** when applicable (e.g., `fsra_`, `blx_`, `dmhb_`)
3. **Include version numbers** for versioned documents (e.g., `_v2_2`)
4. **Date prefixes** for chronological archives (e.g., `8.12`, `9.04`)
5. **Status markers** for completed items (e.g., `✓`)

### Specific Patterns

**Regulatory Documents:**
```
fsra_[entity]_[type]_v[version].md
Example: fsra_blx_core_bp_v2_2.md
```

**Patent Documents:**
```
P[number]_[Topic]_Patent_Spec.md.md
Example: P1_TRR_System_Patent_Spec.md.md
```

**Business Plans:**
```
[entity]-[topic]-[context].md
Example: blx-reward-korea-bp.md
```

**Archived Plans:**
```
✓ [date] [description].md
Example: ✓ 8.25 특허 출원과 제작.md
```

**Index Files:**
```
_index.md (always with underscore prefix)
```

---

## ⚙️ Development Workflow

### Repository Management

This repository is primarily **documentation-focused** with the following workflows:

1. **Document Creation/Update**
   - Create or modify markdown files
   - Update relevant `_index.md` files
   - Commit with descriptive messages

2. **Archive Management**
   - Move completed documents to `05_Archive/BusinessPlans/[Category]/`
   - Prefix with `✓` to indicate archived status
   - Update index references

3. **AI Integration**
   - Update `ai-meta.yaml` when adding new sections
   - Maintain `_index.md` files for AI navigation
   - Document AI collaboration patterns in Meta_Bridge

### Commit Message Conventions

Based on recent commits, the repository uses descriptive commit messages in English:

```
✅ Good Examples:
- "Create index for AI integration documentation"
- "Revise BLXWT Reward System index content"
- "Add ai-meta.yaml configuration file"

❌ Avoid:
- "Update files"
- "Fix"
- Generic "Add files via upload"
```

**Recommended Format:**
```
[Action] [Component/Section] [Brief Description]

Examples:
- Create ADGM regulatory compliance framework
- Update TRR whitepaper with v3.0 specifications
- Revise Business Plans Archive index structure
- Add patent specification for DAO TRR Pool
```

---

## 🌿 Git Branch Strategy

### Branch Naming Convention

The repository uses a specific branch naming pattern for AI-assisted development:

```
claude/[description]-[session-id]
```

**Examples:**
- `claude/claude-md-mi46qf8350toezhz-01NPbE4jodbKV2pfS2rvAtUP`
- `claude/rwa-automation-system-01XvB4k3RDDEeZQu17tPTrzt`

### Branch Requirements

**CRITICAL:** When pushing to this repository:

1. **Branch prefix MUST be `claude/`**
2. **Branch suffix MUST match the session ID**
3. **Failure to follow this pattern results in 403 HTTP errors**

### Working with Branches

```bash
# Check current branch
git branch

# Create new branch (AI session)
git checkout -b claude/[task-description]-[session-id]

# Push with upstream tracking
git push -u origin claude/[branch-name]

# Retry on network errors (up to 4 times with exponential backoff)
# 2s, 4s, 8s, 16s delays
```

### Main Branch

- The repository does not have a traditional `main` or `master` branch listed
- Development happens on `claude/` prefixed feature branches
- Each AI session gets its own branch for traceability

---

## 🔑 Key Entry Points

### For Understanding the System

1. **Start Here:**
   - `/README.md` - Repository overview and map

2. **Core Concepts:**
   - `/01_HTS_DAO_TRR_MASTER/HTS_DAO_TRR_Whitepaper_v2.md.md` - System philosophy
   - `/01_HTS_DAO_TRR_MASTER/P1_TRR_System_Patent_Spec.md.md` - Technical foundation

3. **Legal Framework:**
   - `/02_ADGM_Legal_Core/fsra_blx_core_bp_v2_2.md` - FSRA compliance
   - `/02_ADGM_Legal_Core/_index.md` - Legal structure overview

4. **Implementation:**
   - `/03_LABUAN_DMH_BANK/_index.md` - Banking infrastructure
   - `/04_BLXWT_REWARD_SYSTEM/_index.md` - Token economics

### For AI Integration

1. **AI Configuration:**
   - `/ai-meta.yaml` - Metadata standards and structure
   - `/Meta_Bridge_AI_Integration/_index.md` - AI collaboration guide

2. **Workflow Automation:**
   - `/.github/workflows/` - GitHub Actions workflows

### For Historical Context

1. **Business Strategy:**
   - `/05_Archive/BusinessPlans/index.md` - Archive overview
   - `/05_Archive/BusinessPlans/all-in-one.md` - Consolidated plans (4.4MB)

2. **Evolution:**
   - `/99_Appendices/DTRR-BORDERLINE-LEGENDARY-V3.1-Part*.md` - System evolution
   - `/99_Appendices/HTS_DAO_TRR_Master_v2.md.md` - Previous versions

---

## 📊 Metadata Standards

### ai-meta.yaml Structure

The repository uses a standardized metadata file at the root:

```yaml
project: HTS_Global_Intelligence_Base
version: 1.0
maintainer: 항TGK
ai_readable: true
encoding: UTF-8

structure:
  - HTS_DAO_TRR_Master
  - ADGM_Legal_Core
  - LABUAN_DMH_BANK
  - BLXWT_Reward_System
  - Archive/Business_Plans
  - Meta_Bridge_AI_Integration

priority_read_order:
  - README.md
  - HTS_DAO_TRR_Master/_index.md
  - ADGM_Legal_Core/_index.md
  - LABUAN_DMH_BANK/_index.md
  - Archive/Business_Plans/_index.md

metadata_fields:
  - version
  - description
  - author
  - filetype
  - ai_priority

license: "Private - HTS DAO (2025)"
```

### Document Front Matter

Individual documents may include YAML front matter:

```yaml
---
category: "Category Name"
summary: "Brief description"
related_core:
  - Related_Section_1
  - Related_Section_2
tags: ["tag1", "tag2", "tag3"]
updated: "YYYY-MM-DD"
author: "Author Name"
---
```

**Example:** See `/MERGE_GUIDE.md` for implementation

---

## ✨ Best Practices for AI Assistants

### 1. Document Reading Strategy

**DO:**
- ✅ Always read `_index.md` files first
- ✅ Follow the "AI 탐색 순서" (AI Navigation Order) provided in each index
- ✅ Start with root README.md for context
- ✅ Check ai-meta.yaml for structural metadata
- ✅ Respect the numbered directory priority (01_, 02_, etc.)

**DON'T:**
- ❌ Skip index files and dive directly into subdocuments
- ❌ Ignore the language context (Korean vs English)
- ❌ Read archived documents before current versions
- ❌ Assume file structure without checking indexes

### 2. Document Modification

**DO:**
- ✅ Update relevant `_index.md` when adding/removing documents
- ✅ Maintain consistent formatting and emoji usage
- ✅ Follow existing naming conventions
- ✅ Update version numbers when revising documents
- ✅ Add YAML front matter for new documents
- ✅ Preserve Korean text and special characters (UTF-8)

**DON'T:**
- ❌ Create documents without updating indexes
- ❌ Change naming conventions without documenting
- ❌ Remove version history
- ❌ Corrupt Korean characters (check UTF-8 encoding)

### 3. Git Operations

**DO:**
- ✅ Use descriptive commit messages in English
- ✅ Follow the `claude/[description]-[session-id]` branch pattern
- ✅ Push with `-u` flag: `git push -u origin [branch]`
- ✅ Implement retry logic for network errors (4 retries, exponential backoff)
- ✅ Verify branch name includes session ID before pushing

**DON'T:**
- ❌ Push to branches without `claude/` prefix
- ❌ Use generic commit messages like "Update"
- ❌ Force push without explicit user permission
- ❌ Ignore push failures (check branch naming)

### 4. Multilingual Handling

**Korean Text:**
- Preserve Korean characters exactly as written
- Respect mixed Korean/English documents
- Understand that Korean sections often contain business strategy
- English sections typically contain technical/legal content

**Translation Notes:**
- Key terms are often bilingual: "회수권 (Trade Recovery Right)"
- Don't auto-translate without understanding context
- Maintain original language in file names

### 5. AI Collaboration

**When working with this repository:**

1. **Identify Task Type:**
   - Analysis → Read TRR Master and relevant sections
   - Legal → Focus on ADGM Legal Core
   - Implementation → Check Labuan DMH Bank
   - Strategy → Review Business Plans Archive

2. **Use Appropriate Reading Depth:**
   - Quick Reference → Index files only
   - Moderate → Index + top 3 priority docs
   - Deep Dive → Full section with appendices

3. **Cross-Reference:**
   - TRR concepts appear across multiple sections
   - Legal compliance ties ADGM ↔ Labuan ↔ BLXWT
   - Business plans provide historical context

4. **Document Dependencies:**
   - Patents reference whitepapers
   - Regulatory docs reference patent specs
   - Reward systems reference DAO structure

### 6. Common Tasks

**Creating New Documents:**
```markdown
1. Create document in appropriate directory
2. Add front matter (YAML)
3. Update _index.md with:
   - File name
   - Description
   - Status (✅/🔄/⚠️)
4. Update AI navigation order if high priority
5. Commit with clear message
```

**Archiving Documents:**
```markdown
1. Move to 05_Archive/BusinessPlans/[Category]/
2. Prefix filename with ✓
3. Update old location's _index.md (remove entry)
4. Update archive index.md (add entry)
5. Commit: "Archive [document] to [category]"
```

**Updating Indexes:**
```markdown
1. Read existing _index.md
2. Maintain table structure
3. Update status indicators
4. Keep AI navigation order current
5. Preserve emoji and Korean text
6. Commit: "Update [section] index with [changes]"
```

### 7. Error Handling

**Common Issues:**

| Issue | Cause | Solution |
|-------|-------|----------|
| 403 on push | Branch name doesn't match pattern | Use `claude/[desc]-[session-id]` |
| Corrupted Korean text | Encoding issue | Ensure UTF-8 encoding |
| Missing context | Skipped index files | Read `_index.md` first |
| Outdated information | Reading archived docs | Check current sections first |
| Broken references | Moved/renamed files | Update all index references |

### 8. Quality Checklist

Before committing changes, verify:

- [ ] All `_index.md` files are updated
- [ ] Commit message is descriptive
- [ ] Branch name follows `claude/` pattern with session ID
- [ ] Korean text is properly encoded (UTF-8)
- [ ] File naming follows conventions
- [ ] Status indicators are current (✅/🔄/⚠️)
- [ ] Cross-references are valid
- [ ] AI navigation order makes sense
- [ ] No sensitive information is exposed
- [ ] Version numbers are incremented if applicable

---

## 🔍 Troubleshooting

### Document Not Found

1. Check `_index.md` for current location
2. Search in `99_Appendices/` for older versions
3. Check `05_Archive/` for archived documents
4. Review git history: `git log --all -- [filename]`

### Understanding Complex Relationships

1. Start with `01_HTS_DAO_TRR_MASTER/HTS_DAO_TRR_Whitepaper_v2.md.md`
2. Use `99_Appendices/DTRR-BORDERLINE-LEGENDARY-V3.1-Part*.md` for deep technical context
3. Cross-reference with `02_ADGM_Legal_Core/` for legal framework
4. See implementation in `03_LABUAN_DMH_BANK/` and `04_BLXWT_REWARD_SYSTEM/`

### Merge Conflicts

- Refer to `/MERGE_GUIDE.md` for repository merge strategies
- This guide specifically addresses merging HTS_Project_BusinessPlans content

---

## 📞 Support and Updates

### Maintainer Contact
- **Name:** 항TGK (Geserkhan)
- **Repository:** https://github.com/Geserkhan/HTS_Global_Intelligence_Base

### Related Repositories
- **HTS_Project_BusinessPlans:** https://github.com/Geserkhan/HTS_Project_BusinessPlans
  - Contains expanded business plan archive
  - See `/MERGE_GUIDE.md` for integration instructions

### Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-11-18 | Initial CLAUDE.md creation with comprehensive guide |

### Contributing

When updating this guide:
1. Increment version number
2. Update "Last Updated" date
3. Add entry to Version History table
4. Commit: "Update CLAUDE.md to v[X.Y] - [brief changes]"

---

## 🎓 Learning Path for New AI Assistants

### Beginner (First Session)
1. Read this CLAUDE.md in full
2. Review `/README.md`
3. Scan all `_index.md` files
4. Understand directory structure
5. Practice reading one document from each section

### Intermediate (Understanding the System)
1. Read `01_HTS_DAO_TRR_MASTER/HTS_DAO_TRR_Whitepaper_v2.md.md`
2. Review all 4 patent specifications (P1-P4)
3. Understand ADGM regulatory framework
4. Study BLXWT tokenomics
5. Connect the dots between sections

### Advanced (Contributing)
1. Update documentation
2. Create new indexes
3. Archive old documents
4. Improve AI navigation
5. Enhance metadata
6. Optimize workflows

---

## 🚀 Quick Reference

### Essential Commands

```bash
# Navigation
cd /home/user/HTS_Global_Intelligence_Base
find . -name "_index.md"
ls -la [directory]

# Git Operations
git status
git branch
git checkout -b claude/[task]-[session-id]
git add .
git commit -m "[Action] [Component] [Description]"
git push -u origin claude/[branch-name]

# Search
grep -r "keyword" --include="*.md"
find . -name "*keyword*.md"
```

### Key Paths

```
Root: /home/user/HTS_Global_Intelligence_Base
Core: /01_HTS_DAO_TRR_MASTER/
Legal: /02_ADGM_Legal_Core/
Bank: /03_LABUAN_DMH_BANK/
Rewards: /04_BLXWT_REWARD_SYSTEM/
Archive: /05_Archive/BusinessPlans/
Meta: /ai-meta.yaml
```

### Status Emojis

```
✅ Completed/Current
🔄 In Progress
⚠️ Needs Review
✓ Archived (in filename)
```

---

## 📄 License

**Private Use Only - © HTS DAO 2025**

This repository and all its contents are proprietary and confidential. AI assistants should:
- Treat all information as confidential
- Not share content outside the session
- Respect intellectual property
- Follow data handling protocols

---

**End of CLAUDE.md**

*For updates or questions about this guide, refer to the repository maintainer or check the latest version in the main branch.*
