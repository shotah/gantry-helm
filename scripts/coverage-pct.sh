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
const data = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
let covered = 0, count = 0;
for (const run of data.data || []) {
  for (const fi of run.files || []) {
    const name = String(fi.filename || "").replace(/\\/g, "/");
    if (!name.includes("Sources/Mailbox")) continue;
    const lines = (fi.summary && fi.summary.lines) || {};
    covered += Number(lines.covered || 0);
    count += Number(lines.count || 0);
  }
}
process.stdout.write(String(count === 0 ? 0 : Math.floor((covered * 100) / count)));
' "$REPORT"
