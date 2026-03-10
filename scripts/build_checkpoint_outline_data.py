import csv
import re
from collections import defaultdict
from pathlib import Path


BASE_DIR = Path(__file__).resolve().parents[1]
INPUT_CSV = BASE_DIR / "data" / "CHECKPOINT_DOMAIN_260202.csv"
OUTPUT_CSV = BASE_DIR / "data" / "CHECKPOINT_OUTLINE_260202.csv"

COL_DOMAIN = "\ub3c4\uba54\uc778"
COL_OUTLINE = "\ubaa9\ucc28"
COL_COUNT = "\uc9c8\ubb38\uc218"
COL_MAIN = "\ub300\ud45c\uc9c8\ubb38"
COL_EX1 = "\uc9c8\ubb38\uc608\uc2dc1"
COL_EX2 = "\uc9c8\ubb38\uc608\uc2dc2"
COL_EX3 = "\uc9c8\ubb38\uc608\uc2dc3"
FALLBACK_TITLE = "\uae30\ud0c0 \ubb38\uc758"
INPUT_DOMAIN = "Domain_\ucd5c\uc885"


def normalize_text(text: str) -> str:
    if not text:
        return ""
    text = re.sub(r"[\"'`]+", " ", text)
    text = re.sub(r"\s+", " ", text)
    return text.strip()


def cleanup_subject(text: str) -> str:
    text = normalize_text(text)
    text = re.sub(
        r"(\uc77c \ub54c|\ud560 \ub54c|\uc2dc|\uc2dc\uc5d0|\uacbd\uc6b0|\uac74)$",
        "",
        text,
    )
    text = re.sub(
        r"(\uc740|\ub294|\uc774|\uac00|\uc744|\ub97c|\ub3c4|\ub9cc|\uc640|\uacfc|\uc73c\ub85c|\ub85c)$",
        "",
        text,
    )
    return text.strip(" ?.,:")


PATTERNS = [
    (
        re.compile(
            r"^(?P<subject>.+?)\s*(\uccad\uad6c\s*)?(\uc2dc\s*)?(\ud544\uc694\ud55c|\uad6c\ube44|\uc900\ube44).*(\uc11c\ub958|\ubcd1\uc6d0 ?\uc11c\ub958).*$"
        ),
        "\uad6c\ube44\uc11c\ub958",
    ),
    (
        re.compile(r"^(?P<subject>.+?)\s*(\uccad\uad6c\uad8c|\uccad\uad6c\uad8c\uc790).*$"),
        "\uccad\uad6c\uad8c",
    ),
    (
        re.compile(
            r"^(?P<subject>.+?)\s*(\uc720\ud6a8|\uc18c\uba78\uc2dc\ud6a8|\uba87 \ub144\uae4c\uc9c0).*$"
        ),
        "\uc720\ud6a8\uae30\uac04",
    ),
    (
        re.compile(r"^(?P<subject>.+?)\s*(\uc138\uae08|\uacfc\uc138|\ube44\uacfc\uc138).*$"),
        "\uc138\uae08",
    ),
    (
        re.compile(r"^(?P<subject>.+?)\s*(\ud55c\ub3c4|\ucd5c\ub300|\uae08\uc561|\uc5bc\ub9c8).*$"),
        "\ud55c\ub3c4",
    ),
    (
        re.compile(r"^(?P<subject>.+?)\s*(\uc778\uc99d|\ubcf8\uc778\uc778\uc99d|\uc778\uc99d\ubc88\ud638).*$"),
        "\uc778\uc99d",
    ),
    (
        re.compile(r"^(?P<subject>.+?)\s*(\ubc29\ubc95|\uc808\ucc28|\uc5b4\ub5bb\uac8c).*$"),
        "\ucc98\ub9ac\ubc29\ubc95",
    ),
    (
        re.compile(r"^(?P<subject>.+?)\s*(\ubcc0\uacbd|\uc815\uc815).*$"),
        "\ubcc0\uacbd",
    ),
    (
        re.compile(r"^(?P<subject>.+?)\s*(\uc2e0\uccad|\uc811\uc218|\ub4f1\ub85d|\ubc1c\uae09).*$"),
        "\uc2e0\uccad/\uc811\uc218",
    ),
    (
        re.compile(r"^(?P<subject>.+?)\s*(\ud574\uc9c0|\ucde8\uc18c).*$"),
        "\ud574\uc9c0/\ucde8\uc18c",
    ),
    (
        re.compile(
            r"^(?P<subject>.+?)\s*(\uac00\ub2a5|\ub418\ub098\uc694|\uac00\ub2a5\ud55c\uac00\uc694|\uac00\ub2a5 \ud558\ub098\uc694).*$"
        ),
        "\uac00\ub2a5 \uc5ec\ubd80",
    ),
]


def get_outline_title(question: str) -> str:
    question = normalize_text(question)
    if not question:
        return FALLBACK_TITLE

    for pattern, label in PATTERNS:
        match = pattern.match(question)
        if not match:
            continue
        subject = cleanup_subject(match.group("subject"))
        if len(subject) >= 2:
            return f"{subject} {label}"

    fallback = re.sub(
        r"(\ubb34\uc5c7\uc778\uac00\uc694|\ubb34\uc5c7\uc778\uac00|\ubad4\uac00\uc694|\uc5b4\ub5bb\uac8c \ub418\ub098\uc694|\uc5b4\ub5bb\uac8c \ud558\ub098\uc694|\uac00\ub2a5\ud55c\uac00\uc694|\ub418\ub098\uc694|\uc788\ub098\uc694|\uc778\uac00\uc694|\uc77c\uae4c\uc694)\s*$",
        "",
        question,
    )
    fallback = cleanup_subject(fallback)
    return fallback if len(fallback) >= 2 else FALLBACK_TITLE


def load_rows(path: Path):
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        return list(reader)


def build_outline_rows(rows):
    grouped = defaultdict(list)

    for row in rows:
        question = normalize_text(row.get("Question", ""))
        domain = normalize_text(row.get(INPUT_DOMAIN, ""))
        if not question or not domain:
            continue
        outline = get_outline_title(question)
        grouped[(domain, outline)].append(question)

    items = []
    for (domain, outline), questions in grouped.items():
        items.append(
            {
                COL_DOMAIN: domain,
                COL_OUTLINE: outline,
                COL_COUNT: len(questions),
                COL_MAIN: questions[0],
                COL_EX1: questions[0] if len(questions) >= 1 else "",
                COL_EX2: questions[1] if len(questions) >= 2 else "",
                COL_EX3: questions[2] if len(questions) >= 3 else "",
            }
        )

    items.sort(key=lambda item: (-item[COL_COUNT], item[COL_DOMAIN], item[COL_OUTLINE]))
    for index, item in enumerate(items, start=1):
        item["No."] = index

    return items


def write_rows(path: Path, rows):
    fieldnames = ["No.", COL_OUTLINE, COL_DOMAIN, COL_COUNT, COL_MAIN, COL_EX1, COL_EX2, COL_EX3]
    with path.open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def main():
    rows = load_rows(INPUT_CSV)
    outline_rows = build_outline_rows(rows)
    write_rows(OUTPUT_CSV, outline_rows)
    print(f"Generated: {OUTPUT_CSV}")
    print(f"Input rows: {len(rows)}")
    print(f"Outline rows: {len(outline_rows)}")


if __name__ == "__main__":
    main()
