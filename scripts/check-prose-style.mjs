// Count AI-smelling punctuation in PROSE (code fences excluded):
// em-dashes and horizontal bars. Run after any prose edit.
import { readFileSync, readdirSync } from "node:fs";

const stripCode = (src) =>
  src.replace(/^```[^\n]*\n[\s\S]*?^```/gm, "").replace(/`[^`\n]*`/g, "");

let total = 0;
for (const loc of ["en", "ja"]) {
  for (const f of readdirSync(`content/${loc}`).filter((f) => f.endsWith(".md"))) {
    const prose = stripCode(readFileSync(`content/${loc}/${f}`, "utf8"));
    const hits = (prose.match(/—|―|──/g) || []).length;
    if (hits > 0) {
      console.log(`${loc}/${f}: ${hits}`);
      total += hits;
    }
  }
}
console.log(total === 0 ? "prose is dash-free" : `${total} dashes in prose`);
