#!/usr/bin/env bash
# Parse llvm-cov JSON. Default: Sources/Mailbox line coverage.
set -euo pipefail

REPORT="${1:?usage: coverage-pct.sh report.json}"
if [[ ! -f "$REPORT" ]]; then
  echo "missing $REPORT" >&2
  exit 1
fi

node -e '
const fs = require("fs");
const raw = fs.readFileSync(process.argv[1], "utf8");
let covered = 0, count = 0;
function addFile(name, hit, total) {
  const n = String(name || "").replace(/\\/g, "/");
  if (!n.includes("Sources/Mailbox")) return;
  covered += Number(hit || 0);
  count += Number(total || 0);
}
if (raw.trimStart().startsWith("{")) {
  const data = JSON.parse(raw);
  for (const run of data.data || []) {
    for (const fi of run.files || []) {
      const lines = (fi.summary && fi.summary.lines) || {};
      addFile(fi.filename, lines.covered, lines.count);
    }
  }
} else {
  let filename = "";
  let hit = 0;
  let total = 0;
  for (const line of raw.split(/\n/)) {
    if (line.startsWith("SF:")) {
      filename = line.slice(3);
      hit = 0;
      total = 0;
    } else if (line.startsWith("LH:")) {
      hit = Number(line.slice(3));
    } else if (line.startsWith("LF:")) {
      total = Number(line.slice(3));
    } else if (line === "end_of_record") {
      addFile(filename, hit, total);
    }
  }
}
process.stdout.write(String(count === 0 ? 0 : Math.floor((covered * 100) / count)));
' "$REPORT"
