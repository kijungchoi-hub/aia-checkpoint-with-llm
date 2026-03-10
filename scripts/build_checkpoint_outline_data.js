const fs = require("fs");
const path = require("path");

const [, , inputArg, checkpointArg, outputArg, outputDetailArg] = process.argv;

const baseDir = path.resolve(__dirname, "..");
const inputCsv = path.resolve(baseDir, inputArg || "data/CHECKPOINT_DOMAIN_260202.csv");
const checkpointCsv = path.resolve(baseDir, checkpointArg || "data/CHECKPOINT_202508.csv");
const outputCsv = path.resolve(baseDir, outputArg || "data/CHECKPOINT_OUTLINE_260202.csv");
const outputDetailCsv = path.resolve(baseDir, outputDetailArg || "data/CHECKPOINT_OUTLINE_SOURCE_260202.csv");

function normalizeText(text) {
  if (!text) return "";
  return String(text).replace(/["'`]+/g, " ").replace(/\s+/g, " ").trim();
}

function normalizeKey(text) {
  return normalizeText(text).replace(/[^\p{L}\p{N}]/gu, "").toUpperCase();
}

function containsAny(text, keywords) {
  return keywords.some((keyword) => text.includes(keyword));
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
    .map((row) => ({ ...row, titleKey: normalizeKey(row.title) }));
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

const checkpointRows = readCheckpointTitles(checkpointCsv);
const titlesByDomain = new Map();
for (const row of checkpointRows) {
  if (!titlesByDomain.has(row.domain)) titlesByDomain.set(row.domain, []);
  titlesByDomain.get(row.domain).push(row);
}

const aliasMapByDomain = {
  "계약정보": {
    [normalizeKey("증권, 약관 재 발행")]: "증권, 약관 재발행",
    [normalizeKey("갱신 불원")]: "갱신불원",
    [normalizeKey("(면대면채널) 연장 정기")]: "(면대면채널)연장 정기",
    [normalizeKey("(면대면채널) 감액 완납")]: "(면대면채널)감액 완납",
    [normalizeKey("(면대면채널) 보험 종목 변경")]: "(면대면채널)보험 종목 변경",
    [normalizeKey("직종(직무)& 운전차종 변경")]: "직종(직무)&운전차종 변경",
    [normalizeKey("실손보험 의료급여")]: "실손보험 의료급여 수급권자 확인",
  },
  "보험료납입": {
    [normalizeKey("계좌변경")]: "계좌 자동이체",
    [normalizeKey("카드변경")]: "카드 자동이체",
    [normalizeKey("(대면 _ 20.09.10 이전) 카드 자동이체")]: "(면대면채널)카드 자동이체",
    [normalizeKey("휴대폰 소액결제 자동이체")]: "휴대폰 소액결제",
    [normalizeKey("PUL/SUL 수시추가 납입")]: "PUL/SUL수시추가 납입",
    [normalizeKey("(면대면채널) VUL 추가 납입")]: "(면대면채널)VUL 추가 납입",
  },
  "대출": {
    [normalizeKey("APL(자동대출납입) 신청")]: "APL(자동대출납입)신청",
  },
  "명의변경": {
    [normalizeKey("명의변경 (계약자/수익자 변경)")]: "명의변경(계약자/수익자 변경)",
  },
  "제지급": {
    [normalizeKey("실손보험료 환급 신청")]: "실손보험료 환급신청",
    [normalizeKey("청약 철회")]: "청약철회",
  },
  "연금": {
    [normalizeKey("연금전환서비스")]: "연금전환 서비스",
    [normalizeKey("(면대면채널) 연금신청")]: "(면대면채널)연금신청",
  },
  "변액 펀드": {
    [normalizeKey("(면대면채널) 펀드변경")]: "(면대면채널)펀드변경",
    [normalizeKey("목표 수익률변경")]: "(면대면채널)펀드변경",
  },
  "신계약 미결": {
    [normalizeKey("재고지 접수/보완")]: "재고지 접수/ 보완",
  },
  "설계사": {
    [normalizeKey("(면대면채널) MP 이관")]: "(면대면채널) MP이관",
  },
};

function findDirectTitleMatch(questionKey, domainTitles, aliasMap) {
  const matches = [];

  for (const titleRow of domainTitles) {
    if (questionKey.includes(titleRow.titleKey)) {
      matches.push({ title: titleRow.title, score: titleRow.titleKey.length });
    }
  }

  for (const [aliasKey, title] of Object.entries(aliasMap || {})) {
    if (questionKey.includes(aliasKey)) {
      matches.push({ title, score: aliasKey.length });
    }
  }

  if (matches.length === 0) return null;
  matches.sort((a, b) => b.score - a.score);
  return matches[0].title;
}

function resolveCheckpointTitle(domain, question, domainTitles, aliasMap) {
  const q = normalizeText(question);
  const qKey = normalizeKey(q);

  if (!domainTitles || domainTitles.length === 0) return "UNKNOWN";
  if (domainTitles.length === 1) return domainTitles[0].title;

  const direct = findDirectTitleMatch(qKey, domainTitles, aliasMap);
  if (direct) return direct;

  switch (domain) {
    case "고객정보":
      return "주소/연락처 변경";
    case "보험금 보장":
      return "보험금청구";
    case "헬스케어서비스":
      return "헬스케어 서비스";
    case "변액 펀드":
      return "(면대면채널)펀드변경";
    case "설계사":
      return "(면대면채널) MP이관";
    case "대출":
      if (containsAny(q, ["APL", "자동대출납입"])) return "APL(자동대출납입)신청";
      return "보험계약대출 신청";
    case "증명서 안내장":
      if (containsAny(q, ["소득공제", "납입 증명", "납입증명"])) return "소득공제 납입 증명서 발급";
      if (containsAny(q, ["해지영수증"])) return "해지영수증 발급";
      if (containsAny(q, ["잔액증명"])) return "잔액증명서 발급";
      if (containsAny(q, ["대출 영수증", "보험계약대출 영수증"])) return "보험계약대출 영수증 발급";
      return "UNKNOWN";
    case "민원":
      if (containsAny(q, ["품질", "청약 후 15일", "품질보증"])) return "품질보증해지";
      return "민원";
    case "계약해지":
      if (containsAny(q, ["취소", "해지취소"])) return "해지취소";
      if (containsAny(q, ["환급금", "얼마", "문의", "유지", "되나요", "가능"])) return "해지문의";
      if (containsAny(q, ["접수", "신청", "해지할", "해지하고", "해약"])) return "해지접수";
      return "해지문의";
    case "제지급":
      if (containsAny(q, ["실손보험료 환급"])) return "실손보험료 환급신청";
      if (containsAny(q, ["송금계좌", "반환계좌", "지급계좌"])) return "송금계좌등록";
      if (containsAny(q, ["자동송금"])) return "자동송금신청";
      if (containsAny(q, ["중도인출"])) return "중도인출";
      if (containsAny(q, ["중도분할"])) return "중도분할금 접수";
      if (containsAny(q, ["청약철회", "청약 철회"])) return "청약철회";
      if (containsAny(q, ["휴면보험금", "재단출연"])) return "재단출연 휴면보험금";
      return "UNKNOWN";
    case "명의변경":
      if (containsAny(q, ["태아", "태아등재"])) return "어린이보험 태아등재";
      if (containsAny(q, ["정정", "오기", "개명", "생년월일", "주민번호", "성별", "영문명"])) return "명의정정";
      if (containsAny(q, ["지정대리청구인", "지정대리인", "재사수익자", "사망수익자", "만기수익자", "수익자"])) {
        return "명의변경(계약자/수익자 변경)";
      }
      if (containsAny(q, ["계약자 변경", "수익자 변경", "명의변경", "계약자변경", "수익자변경"])) {
        return "명의변경(계약자/수익자 변경)";
      }
      return "UNKNOWN";
    case "연금":
      if (containsAny(q, ["연금전환"])) return "연금전환 서비스";
      if (containsAny(q, ["연금정정", "연금계약변경"])) return "연금정정 (연금계약변경)";
      if (containsAny(q, ["연금개시연령", "연금개시가", "연금지급주기", "연금 지급", "연금개시"])) {
        return "연금정정 (연금계약변경)";
      }
      if (containsAny(q, ["연금신청", "연금 신청", "연금 개시", "연금 수령"])) return "(면대면채널)연금신청";
      return "UNKNOWN";
    case "신계약 미결":
      if (containsAny(q, ["재고지", "보완", "추가고지", "고지"])) return "재고지 접수/ 보완";
      return "(통신채널) 신계약 미결";
    case "보험료납입":
      if (containsAny(q, ["휴대폰", "소액결제"])) return "휴대폰 소액결제";
      if (containsAny(q, ["가상계좌"])) return "가상계좌 등록 및 입금";
      if (containsAny(q, ["즉시출금", "즉시이체", "RTB"])) return "즉시출금";
      if (containsAny(q, ["자동이체 해지", "자동이체해지"])) return "자동이체해지";
      if (containsAny(q, ["선납"])) return "선납";
      if (containsAny(q, ["VUL"])) return "(면대면채널)VUL 추가 납입";
      if (containsAny(q, ["PUL/SUL", "수시추가", "수시 추가"])) return "PUL/SUL수시추가 납입";
      if (containsAny(q, ["PUL", "월 추가납입", "월 추가 납입"])) return "PUL 월 추가 납입";
      if (containsAny(q, ["납입중지", "납입 중지"])) {
        if (containsAny(q, ["의무납입기간", "의무 납입기간"])) return "(의무납입기간 경과 건) 납입중지 신청";
        return "일시납입중지 신청";
      }
      if (containsAny(q, ["카드", "신용카드"])) return "카드 자동이체";
      if (containsAny(q, ["계좌", "자동이체", "이체일", "출금일", "출금", "은행"])) return "계좌 자동이체";
      return "UNKNOWN";
    case "계약정보":
      if (containsAny(q, ["증권", "약관", "재발행"])) return "증권, 약관 재발행";
      if (containsAny(q, ["일반부활"])) return "일반부활";
      if (containsAny(q, ["자동부활", "부활", "실효", "미납", "연체"])) return "자동부활";
      if (containsAny(q, ["직종", "직무", "운전차종"])) return "직종(직무)&운전차종 변경";
      if (containsAny(q, ["납입기간"])) return "납입기간변경";
      if (containsAny(q, ["납입주기"])) return "납입주기변경";
      if (containsAny(q, ["감액", "특약삭제", "특약 삭제"])) return "감액/특약삭제";
      if (containsAny(q, ["갱신불원", "갱신 불원"])) return "갱신불원";
      if (containsAny(q, ["의료급여", "수급권자"])) return "실손보험 의료급여 수급권자 확인";
      if (containsAny(q, ["연장정기", "연장 정기"])) return "(면대면채널)연장 정기";
      if (containsAny(q, ["감액완납", "감액 완납"])) return "(면대면채널)감액 완납";
      if (containsAny(q, ["비흡연", "비 흡연", "건강플러스", "건강할인"])) return "비 흡연 할인 특약";
      if (containsAny(q, ["보험 종목", "종목 변경"])) return "(면대면채널)보험 종목 변경";
      if (containsAny(q, ["UL 약정", "약정보험료"])) return "UL 약정보험료";
      if (containsAny(q, ["EIUL", "지수연동"])) return "EIUL 지수 기간 연장";
      if (containsAny(q, ["이율확정", "기간재설정"])) return "이율확정 기간재설정";
      if (containsAny(q, ["VUWL", "종신보험 전환"])) return "VUWL 일시납 종신보험 전환 신청";
      return "UNKNOWN";
    default:
      return "UNKNOWN";
  }
}

const inputRows = readCsvObjects(inputCsv);
const detailRows = [];

for (const [index, row] of inputRows.entries()) {
  const question = normalizeText(row.Question);
  const domain = normalizeText(row["Domain_최종"]);
  const domainTitles = titlesByDomain.get(domain) || [];
  const aliasMap = aliasMapByDomain[domain] || {};
  const title = resolveCheckpointTitle(domain, question, domainTitles, aliasMap);
  const mappedTitle = title === "UNKNOWN" ? "" : title;

  detailRows.push({
    "No.": index + 1,
    "Question": question,
    "Domain_최종": domain,
    "목차": mappedTitle,
    "매핑상태": title === "UNKNOWN" ? "UNKNOWN" : "MATCHED",
  });
}

const summaryMap = new Map();
for (const row of detailRows) {
  if (!row["목차"]) continue;
  const key = `${row["Domain_최종"]}\n${row["목차"]}`;
  if (!summaryMap.has(key)) summaryMap.set(key, []);
  summaryMap.get(key).push(row);
}

const summaryRows = Array.from(summaryMap.values())
  .map((group) => ({
    "No.": 0,
    "목차": group[0]["목차"],
    "도메인": group[0]["Domain_최종"],
    "질문수": group.length,
    "대표질문": group[0].Question,
    "질문예시1": group[0]?.Question || "",
    "질문예시2": group[1]?.Question || "",
    "질문예시3": group[2]?.Question || "",
  }))
  .sort((a, b) => {
    if (b["질문수"] !== a["질문수"]) return b["질문수"] - a["질문수"];
    if (a["도메인"] !== b["도메인"]) return a["도메인"].localeCompare(b["도메인"], "ko");
    return a["목차"].localeCompare(b["목차"], "ko");
  })
  .map((row, index) => ({ ...row, "No.": index + 1 }));

writeCsv(outputDetailCsv, ["No.", "Question", "Domain_최종", "목차", "매핑상태"], detailRows);
writeCsv(outputCsv, ["No.", "목차", "도메인", "질문수", "대표질문", "질문예시1", "질문예시2", "질문예시3"], summaryRows);

const matched = detailRows.filter((row) => row["매핑상태"] === "MATCHED").length;
const unknown = detailRows.length - matched;

console.log(`Generated: ${outputCsv}`);
console.log(`Generated: ${outputDetailCsv}`);
console.log(`Input rows: ${detailRows.length}`);
console.log(`Matched rows: ${matched}`);
console.log(`Unknown rows: ${unknown}`);
