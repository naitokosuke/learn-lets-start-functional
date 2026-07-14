// Verify that every fenced code block in content/ja/*.md is byte-identical
// to the corresponding block (by order) in content/en/*.md.
import { readFileSync, readdirSync } from "node:fs";

const blocks = (src) => {
  const out = [];
  const re = /^```[^\n]*\n([\s\S]*?)^```/gm;
  let m;
  while ((m = re.exec(src))) out.push(m[1]);
  return out;
};

let bad = 0;
for (const f of readdirSync("content/ja").filter((f) => f.endsWith(".md"))) {
  if (f === "index.md") continue;
  const en = blocks(readFileSync(`content/en/${f}`, "utf8"));
  const ja = blocks(readFileSync(`content/ja/${f}`, "utf8"));
  if (en.length !== ja.length) {
    console.log(`${f}: block count differs (en=${en.length}, ja=${ja.length})`);
    bad++;
    continue;
  }
  en.forEach((b, i) => {
    if (b !== ja[i]) {
      console.log(`${f}: block #${i + 1} differs`);
      bad++;
    }
  });
}
console.log(bad === 0 ? "all code blocks identical" : `${bad} problem(s)`);
process.exit(bad === 0 ? 0 : 1);
