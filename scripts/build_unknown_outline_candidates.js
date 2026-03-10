const fs = require("fs");
const path = require("path");

const [, , inputArg, outputArg, outputDetailArg] = process.argv;

const baseDir = path.resolve(__dirname, "..");
const inputCsv = path.resolve(baseDir, inputArg || "data/CHECKPOINT_OUTLINE_SOURCE_260202.csv");
const checkpointCsv = path.resolve(baseDir, "data/CHECKPOINT_202508.csv");
const outputCsv = path.resolve(baseDir, outputArg || "data/CHECKPOINT_UNKNOWN_OUTLINE_CANDIDATES_260202.csv");
const outputDetailCsv = path.resolve(baseDir, outputDetailArg || "data/CHECKPOINT_UNKNOWN_OUTLINE_SOURCE_260202.csv");

function normalizeText(text) {
  if (!text) return "";
  return String(text).replace(/["'`]+/g, " ").replace(/\s+/g, " ").trim();
}

function normalizeKey(text) {
  return normalizeText(text).replace(/[^\p{L}\p{N}]/gu, "").toUpperCase();
}

function tokenize(text) {
  return normalizeText(text)
    .split(/[\s,()/&+-]+/u)
    .map((token) => token.trim())
    .filter((token) => token.length >= 2);
}

function parseCsv(content) {
  const rows = [];
  let row = [];
  let field = "";
  let inQuotes = false;

  for (let i = 0; i < content.length; i += 1) {
    const ch = content[i];
    const next = content[i + 1];

    if (ch === '"') {
      if (inQuotes && next === '"') {
        field += '"';
        i += 1;
      } else {
        inQuotes = !inQuotes;
      }
      continue;
    }

    if (!inQuotes && ch === ",") {
      row.push(field);
      field = "";
      continue;
    }

    if (!inQuotes && (ch === "\n" || ch === "\r")) {
      if (ch === "\r" && next === "\n") i += 1;
      row.push(field);
      rows.push(row);
      row = [];
      field = "";
      continue;
    }

    field += ch;
  }

  if (field.length > 0 || row.length > 0) {
    row.push(field);
    rows.push(row);
  }

  return rows;
}

function readCsvObjects(filePath) {
  const raw = fs.readFileSync(filePath, "utf8").replace(/^\uFEFF/, "");
  const rows = parseCsv(raw).filter((row) => row.some((cell) => normalizeText(cell)));
  const headers = rows[0].map((header) => normalizeText(header));
  return rows.slice(1).map((row) => {
    const obj = {};
    headers.forEach((header, index) => {
      obj[header] = row[index] ?? "";
    });
    return obj;
  });
}

function readCheckpointTitles(filePath) {
  const raw = fs.readFileSync(filePath, "utf8").replace(/^\uFEFF/, "");
  const rows = parseCsv(raw).slice(2);
  return rows
    .map((row) => ({
      title: normalizeText(row[1]),
      domain: normalizeText(row[2]),
    }))
    .filter((row) => row.title && row.domain)
    .map((row) => ({
      ...row,
      titleKey: normalizeKey(row.title),
      tokens: tokenize(row.title),
    }));
}

function writeCsv(filePath, headers, rows) {
  const escape = (value) => {
    const text = value == null ? "" : String(value);
    if (/[",\r\n]/.test(text)) return `"${text.replace(/"/g, '""')}"`;
    return text;
  };

  const lines = [
    headers.join(","),
    ...rows.map((row) => headers.map((header) => escape(row[header])).join(",")),
  ];
  fs.writeFileSync(filePath, `\uFEFF${lines.join("\r\n")}\r\n`, "utf8");
}

const checkpoints = readCheckpointTitles(checkpointCsv);
const titlesByDomain = new Map();
for (const item of checkpoints) {
  if (!titlesByDomain.has(item.domain)) titlesByDomain.set(item.domain, []);
  titlesByDomain.get(item.domain).push(item);
}

const aliasBoosts = {
  "제지급": [
    ["만기보험금", "중도인출"],
    ["중도보험금", "중도인출"],
    ["지급계좌", "송금계좌등록"],
    ["반환계좌", "송금계좌등록"],
    ["제지급", "송금계좌등록"],
  ],
  "계약정보": [
    ["부활", "자동부활"],
    ["실효", "자동부활"],
    ["연체", "자동부활"],
    ["미납", "자동부활"],
    ["건강플러스", "비 흡연 할인 특약"],
    ["건강할인", "비 흡연 할인 특약"],
    ["지수연동", "EIUL 지수 기간 연장"],
  ],
  "명의변경": [
    ["지정대리청구인", "명의변경(계약자/수익자 변경)"],
    ["수익자", "명의변경(계약자/수익자 변경)"],
    ["계약자", "명의변경(계약자/수익자 변경)"],
  ],
  "보험료납입": [
    ["즉시이체", "즉시출금"],
    ["RTB", "즉시출금"],
    ["미납", "일시납입중지 신청"],
    ["실효", "일시납입중지 신청"],
  ],
  "연금": [
    ["연금개시", "(면대면채널)연금신청"],
    ["연금지급", "(면대면채널)연금신청"],
    ["연금계약변경", "연금정정 (연금계약변경)"],
  ],
  "증명서 안내장": [
    ["소득세액공제", "소득공제 납입 증명서 발급"],
    ["소득공제", "소득공제 납입 증명서 발급"],
    ["해지환급금산출내역서", "해지영수증 발급"],
    ["연금지급내역서", "잔액증명서 발급"],
  ],
};

function scoreCandidate(question, domain, candidate) {
  const q = normalizeText(question);
  const qKey = normalizeKey(q);
  let score = 0;

  if (candidate.domain === domain) score += 100;
  if (qKey.includes(candidate.titleKey)) score += 200;

  for (const token of candidate.tokens) {
    if (q.includes(token)) score += 12;
  }

  const boosts = aliasBoosts[domain] || [];
  for (const [keyword, title] of boosts) {
    if (q.includes(keyword) && candidate.title === title) score += 40;
  }

  if (candidate.title.includes("연금") && q.includes("연금")) score += 5;
  if (candidate.title.includes("해지") && q.includes("해지")) score += 5;
  if (candidate.title.includes("대출") && q.includes("대출")) score += 5;
  if (candidate.title.includes("보험금") && q.includes("보험금")) score += 5;

  return score;
}

function pickExistingTitle(question, domain) {
  const sameDomain = titlesByDomain.get(domain) || [];
  const candidates = sameDomain.length > 0 ? sameDomain : checkpoints;

  let best = null;
  for (const candidate of candidates) {
    const score = scoreCandidate(question, domain, candidate);
    if (!best || score > best.score) {
      best = { title: candidate.title, checkpointDomain: candidate.domain, score };
    }
  }

  return best || { title: "", checkpointDomain: "", score: 0 };
}

const inputRows = readCsvObjects(inputCsv);
const unknownRows = inputRows.filter((row) => normalizeText(row["매핑상태"]) === "UNKNOWN");

const detailRows = unknownRows.map((row, index) => {
  const question = normalizeText(row.Question);
  const domain = normalizeText(row["Domain_최종"]);
  const picked = pickExistingTitle(question, domain);
  return {
    "No.": index + 1,
    "Question": question,
    "Domain_최종": domain,
    "기존목차후보": picked.title,
    "후보목차도메인": picked.checkpointDomain,
    "점수": picked.score,
  };
});

const grouped = new Map();
for (const row of detailRows) {
  const key = `${row["Domain_최종"]}\n${row["기존목차후보"]}`;
  if (!grouped.has(key)) grouped.set(key, []);
  grouped.get(key).push(row);
}

const summaryRows = Array.from(grouped.values())
  .map((group) => ({
    "No.": 0,
    "기존목차후보": group[0]["기존목차후보"],
    "원본도메인": group[0]["Domain_최종"],
    "후보목차도메인": group[0]["후보목차도메인"],
    "질문수": group.length,
    "대표질문": group[0].Question,
    "질문예시1": group[0]?.Question || "",
    "질문예시2": group[1]?.Question || "",
    "질문예시3": group[2]?.Question || "",
  }))
  .sort((a, b) => {
    if (b["질문수"] !== a["질문수"]) return b["질문수"] - a["질문수"];
    if (a["원본도메인"] !== b["원본도메인"]) return a["원본도메인"].localeCompare(b["원본도메인"], "ko");
    return a["기존목차후보"].localeCompare(b["기존목차후보"], "ko");
  })
  .map((row, index) => ({ ...row, "No.": index + 1 }));

writeCsv(outputDetailCsv, ["No.", "Question", "Domain_최종", "기존목차후보", "후보목차도메인", "점수"], detailRows);
writeCsv(outputCsv, ["No.", "기존목차후보", "원본도메인", "후보목차도메인", "질문수", "대표질문", "질문예시1", "질문예시2", "질문예시3"], summaryRows);

console.log(`Generated: ${outputCsv}`);
console.log(`Generated: ${outputDetailCsv}`);
console.log(`Unknown input rows: ${detailRows.length}`);
console.log(`Candidate groups: ${summaryRows.length}`);
