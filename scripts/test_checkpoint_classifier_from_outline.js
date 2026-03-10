const fs = require("fs");
const path = require("path");

const [, , inputArg, outputArg, modelArg, maxRowsArg, maxContentRowsArg] = process.argv;

const baseDir = path.resolve(__dirname, "..");
const inputCsv = path.resolve(baseDir, inputArg || "data/CHECKPOINT_OUTLINE_SOURCE_260202.csv");
const outputCsv = path.resolve(baseDir, outputArg || "data/CHECKPOINT_CLASSIFIER_TEST_RESULTS_260202.csv");
const promptPath = path.resolve(baseDir, "data/checkpoint_prompt.json");
const mappingCsvPath = path.resolve(baseDir, "data/Domain_Code_Table.csv");
const talkJsonlPath = path.resolve(baseDir, "data/checkpoint_talk_data.jsonl");
const model = modelArg || process.env.OPENAI_MODEL || "gpt-4.1-mini";
const maxRows = Number(maxRowsArg || 0);
const maxContentRows = Number(maxContentRowsArg || 120);

const D_CUSTOMER = "\uACE0\uAC1D\uC815\uBCF4";
const D_CONTRACT = "\uACC4\uC57D\uC815\uBCF4";
const D_PAYMENT = "\uBCF4\uD5D8\uB8CC\uB0A9\uC785";
const H_DOMAIN = "Domain_\uCD5C\uC885";
const H_TITLE = "\uBAA9\uCC28";
const H_TITLE_NAME = "\uBAA9\uCC28\uBA85";
const H_TOPIC_CODE = "\uBAA9\uCC28\uCF54\uB4DC";
const H_DOMAIN_CODE = "\uB3C4\uBA54\uC778\uCF54\uB4DC";

function normalizeText(text) {
  if (!text) return "";
  return String(text).replace(/^["'`]+|["'`]+$/g, "").replace(/\s+/g, " ").trim();
}

function toLine(text) {
  return normalizeText(String(text || "").replace(/\r\n|\r|\n/g, " "));
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

function loadPromptTemplate(filePath) {
  const obj = JSON.parse(fs.readFileSync(filePath, "utf8").replace(/^\uFEFF/, ""));
  if (obj.prompt) return String(obj.prompt);
  if (obj.prompt_lines) return obj.prompt_lines.join("\n");
  throw new Error(`Prompt file must contain 'prompt' or 'prompt_lines': ${filePath}`);
}

function domainTextForName(domainName) {
  switch (domainName) {
    case D_CUSTOMER:
      return "DOM001, DOM002, DOM003";
    case D_CONTRACT:
      return "DOM002, DOM001, DOM003";
    case D_PAYMENT:
      return "DOM003, DOM002, DOM001";
    default:
      return "";
  }
}

function getDomainCandidates(domainText) {
  return Array.from(domainText.toUpperCase().matchAll(/DOM\d{3}/g)).map((m) => m[0]);
}

async function callClassifier(renderedPrompt) {
  const apiKey = process.env.OPENAI_API_KEY;
  if (!apiKey) throw new Error("OPENAI_API_KEY is not set.");

  const baseUrl = (process.env.OPENAI_BASE_URL || "https://api.openai.com/v1").replace(/\/$/, "");
  const response = await fetch(`${baseUrl}/responses`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model,
      temperature: 0,
      input: [
        {
          role: "user",
          content: [
            {
              type: "input_text",
              text: renderedPrompt,
            },
          ],
        },
      ],
    }),
  });

  if (!response.ok) {
    throw new Error(`HTTP ${response.status}: ${await response.text()}`);
  }

  const payload = await response.json();
  let outputText = payload.output_text || "";
  if (!outputText && Array.isArray(payload.output)) {
    for (const item of payload.output) {
      for (const content of item.content || []) {
        if (content.type === "output_text" && content.text) {
          outputText = content.text;
          break;
        }
      }
      if (outputText) break;
    }
  }

  if (!outputText) throw new Error("No output text returned from API.");
  return JSON.parse(outputText);
}

async function main() {
  const promptTemplate = loadPromptTemplate(promptPath);
  const mapping = readCsvObjects(mappingCsvPath);
  const talkRows = fs
    .readFileSync(talkJsonlPath, "utf8")
    .split(/\r?\n/)
    .filter((line) => line.trim())
    .map((line) => JSON.parse(line.replace(/^\uFEFF/, "")));

  const mapByTitle = new Map();
  for (const row of mapping) {
    const title = toLine(row[H_TITLE_NAME] || row.checkpoint_name);
    if (title) mapByTitle.set(title, row);
  }

  let inputRows = readCsvObjects(inputCsv)
    .filter((row) => [D_CUSTOMER, D_CONTRACT, D_PAYMENT].includes(toLine(row[H_DOMAIN])))
    .filter((row) => mapByTitle.has(toLine(row[H_TITLE])));

  if (maxRows > 0) {
    inputRows = inputRows.slice(0, maxRows);
  }

  const results = [];

  for (let i = 0; i < inputRows.length; i += 1) {
    const row = inputRows[i];
    const question = toLine(row.Question);
    const expectedTitle = toLine(row[H_TITLE]);
    const expectedMeta = mapByTitle.get(expectedTitle);
    const domainText = domainTextForName(toLine(row[H_DOMAIN]));
    const domainCandidates = getDomainCandidates(domainText);

    const mappingFiltered = mapping.filter((item) => {
      const code = item[H_DOMAIN_CODE] || item.domain_code;
      return domainCandidates.length === 0 || domainCandidates.includes(code);
    });

    const checkpointData = mappingFiltered
      .map((item) => {
        const checkpointCode = item[H_TOPIC_CODE] || item.checkpoint_code;
        const checkpointName = item[H_TITLE_NAME] || item.checkpoint_name;
        const domainCode = item[H_DOMAIN_CODE] || item.domain_code;
        return `checkpoint_code=${checkpointCode}, checkpoint_name=${checkpointName}, domain_code=${domainCode}`;
      })
      .join("\n");

    const talkFiltered = talkRows.filter((item) => domainCandidates.length === 0 || domainCandidates.includes(item.domain_code));
    const checkpointContentData = talkFiltered
      .filter((item) => !/^\s*$/.test(item.checkpoint || ""))
      .slice(0, maxContentRows)
      .map((item) => `checkpoint_code=${item.topic_code}, checkpoint=${toLine(item.checkpoint)}`)
      .join("\n");

    const checkpointTalkData = talkFiltered
      .filter((item) => !/^\s*$/.test(item.talk || ""))
      .slice(0, maxContentRows)
      .map((item) => `checkpoint=${toLine(item.checkpoint)}, talk=${toLine(item.talk)}`)
      .join("\n");

    const rendered = promptTemplate
      .replace("{{USER_QUESTION}}", question)
      .replace("{{LLM_ANSWER}}", "")
      .replace("{{DOMAIN_TEXT}}", domainText)
      .replace("{{CHECKPOINT_DATA}}", checkpointData)
      .replace("{{CHECKPOINT_CONTENT_DATA}}", checkpointContentData)
      .replace("{{CHECKPOINT_TALK_DATA}}", checkpointTalkData);

    let predictedDomainCode = "ERROR";
    let predictedTopicCode = "ERROR";
    let result = "ERROR";
    let error = "";

    try {
      const parsed = await callClassifier(rendered);
      predictedDomainCode = String(parsed.domain_code || "");
      predictedTopicCode = String(parsed.topic_code || "");
      const expectedTopicCode = String(expectedMeta[H_TOPIC_CODE] || expectedMeta.checkpoint_code || "");
      result = predictedTopicCode === expectedTopicCode ? "PASS" : "FAIL";
    } catch (err) {
      error = err.message;
    }

    results.push({
      "No.": row["No."],
      Question: question,
      [H_DOMAIN]: row[H_DOMAIN],
      ExpectedTitle: expectedTitle,
      ExpectedDomainCode: expectedMeta[H_DOMAIN_CODE] || expectedMeta.domain_code || "",
      ExpectedTopicCode: expectedMeta[H_TOPIC_CODE] || expectedMeta.checkpoint_code || "",
      PredictedDomainCode: predictedDomainCode,
      PredictedTopicCode: predictedTopicCode,
      Result: result,
      Error: error,
    });

    console.log(`[${i + 1}/${inputRows.length}] ${result} - ${question}`);
  }

  writeCsv(
    outputCsv,
    ["No.", "Question", H_DOMAIN, "ExpectedTitle", "ExpectedDomainCode", "ExpectedTopicCode", "PredictedDomainCode", "PredictedTopicCode", "Result", "Error"],
    results
  );

  const pass = results.filter((row) => row.Result === "PASS").length;
  const fail = results.filter((row) => row.Result === "FAIL").length;
  const error = results.filter((row) => row.Result === "ERROR").length;

  console.log(`Saved: ${outputCsv}`);
  console.log(`Total: ${results.length}`);
  console.log(`PASS: ${pass}`);
  console.log(`FAIL: ${fail}`);
  console.log(`ERROR: ${error}`);
}

main().catch((err) => {
  console.error(err.message);
  process.exit(1);
});
