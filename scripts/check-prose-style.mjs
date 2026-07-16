// Style gate for PROSE (code fences and inline code excluded):
//   - no em-dashes / horizontal bars anywhere
//   - Japanese prose uses ，． (never 、。)
// Run after any prose edit.
import { readFileSync, readdirSync } from "node:fs";

const stripCode = (src) =>
  src.replace(/^```[^\n]*\n[\s\S]*?^```/gm, "").replace(/`[^`\n]*`/g, "");

let total = 0;
for (const loc of ["en", "ja"]) {
  for (const f of readdirSync(`content/${loc}`).filter((f) => f.endsWith(".md"))) {
    const prose = stripCode(readFileSync(`content/${loc}/${f}`, "utf8"));
    const dashes = (prose.match(/—|―|──/g) || []).length;
    const kutouten = loc === "ja" ? (prose.match(/、|。/g) || []).length : 0;
    if (dashes + kutouten > 0) {
      console.log(`${loc}/${f}: ${dashes} dashes, ${kutouten} 、。`);
      total += dashes + kutouten;
    }
  }
}
console.log(total === 0 ? "prose style clean" : `${total} style violations`);
