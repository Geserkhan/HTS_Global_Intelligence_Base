import os
import shutil
import glob
import re
from datetime import datetime

# Current folder
base = os.getcwd()
today = datetime.now().strftime("%Y%m%d_%H%M%S")

# Always backup first
backup = os.path.join(base, f"backup_{today}")
os.makedirs(backup, exist_ok=True)
for md_file in glob.glob(os.path.join(base, "*.md")):
    if not any(ex in md_file for ex in ("index.md", "all-in-one.md", "organize-*.py", "backup_")):
        shutil.copy(md_file, backup)
print(f"Backup created: {backup}")

# Category keywords (Korean for matching, English folder names)
categories = {
    "Agriculture": "농장|계란|토하|BSF|동애등에|순환|식품|레시피|사육",
    "Energy": "LNG|ESS|수소|에너지|발전|항만|DH|AFPM|Eflow",
    "Finance": "DAO|RWA|TRR|투자|금융|은행|담보|Labuan|ADGM|BLX",
    "RealEstate": "호텔|세컨하우스|주거|리조트|PRIDE LAND|온천",
    "Branding": "앰플|뷰티|Wear|광고|마케팅|유통|올리브영|프랜차이즈",
    "Patent": "특허|마이닝|발명|IP|FTO|3D",
    "Talent": "채용|인재|파이프라인|병역|교육|주니어",
    "Other": "물류|드론|관리|정책|기타"  # For unmatched
}

# Create folders
for cat in categories:
    folder = os.path.join(base, cat)
    os.makedirs(folder, exist_ok=True)
    print(f"Created folder: {cat}")

# Get files
files = [f for f in glob.glob(os.path.join(base, "*.md")) if not any(ex in os.path.basename(f) for ex in ("index.md", "all-in-one.md", "organize-*.py", "backup_"))]

# Categorize and move
moved_count = 0
for f in files:
    fname = os.path.basename(f)
    moved = False
    for cat, pattern in categories.items():
        if re.search(pattern, fname, re.IGNORECASE):
            shutil.move(f, os.path.join(base, cat, fname))
            print(f"Moved {fname} to {cat}")
            moved = True
            moved_count += 1
            break
    if not moved:
        shutil.move(f, os.path.join(base, "Other", fname))
        print(f"Moved {fname} to Other")
        moved_count += 1

print(f"Total moved files: {moved_count}")

# Generate index.md
with open(os.path.join(base, "index.md"), "w", encoding="utf-8") as idx:
    idx.write("# Auto Categorized Index\n\n")
    for cat in categories:
        cat_path = os.path.join(base, cat)
        cat_files = [os.path.basename(ff) for ff in glob.glob(os.path.join(cat_path, "*.md"))]
        if cat_files:
            idx.write(f"## {cat}\n")
            for cf in sorted(cat_files):
                idx.write(f"- [{cf}](./{cat}/{cf})\n")
            idx.write("\n")

# Generate all-in-one.md
with open(os.path.join(base, "all-in-one.md"), "w", encoding="utf-8") as all_one:
    all_one.write("# Combined All (Categorized)\n\n")
    for cat in categories:
        cat_path = os.path.join(base, cat)
        cat_files = glob.glob(os.path.join(cat_path, "*.md"))
        if cat_files:
            all_one.write(f"## {cat} Section\n\n")
            for cf in sorted(cat_files):
                all_one.write(f"### {os.path.basename(cf)}\n\n")
                with open(cf, "r", encoding="utf-8") as content:
                    all_one.write(content.read() + "\n\n---\n\n")

print("✅ Categorization Done! Check index.md and all-in-one.md. Backup:", backup)