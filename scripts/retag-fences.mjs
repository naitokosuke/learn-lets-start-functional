// Retag untagged code fences in content/**/*.md:
//   - blocks that look like an .ipkg file        -> ```ipkg
//   - blocks containing an Idris REPL prompt     -> ```repl
// Everything else (test output, trees, errors) stays plain.
// Line-based state machine: regexes across fences are too easy to fool.
import { readFileSync, writeFileSync, readdirSync } from "node:fs";

const looksIpkg = (body) =>
  /^package [a-z]/m.test(body) &&
  /^(version|modules|sourcedir|depends|main) /m.test(body);

const looksRepl = (body) => /^[A-Za-z][A-Za-z0-9_.]*> /m.test(body);

let changed = 0;
for (const loc of ["en", "ja"]) {
  for (const f of readdirSync(`content/${loc}`).filter((f) => f.endsWith(".md"))) {
    const path = `content/${loc}/${f}`;
    const lines = readFileSync(path, "utf8").split("\n");
    let inFence = false;
    let openIdx = -1;
    let tag = null;
    for (let i = 0; i < lines.length; i++) {
      const open = !inFence && lines[i].match(/^```(\S*)\s*$/);
      if (open) {
        inFence = true;
        openIdx = i;
        tag = open[1];
      } else if (inFence && /^```\s*$/.test(lines[i])) {
        if (tag === "") {
          const body = lines.slice(openIdx + 1, i).join("\n");
          if (looksIpkg(body)) {
            lines[openIdx] = "```ipkg";
            changed++;
          } else if (looksRepl(body)) {
            lines[openIdx] = "```repl";
            changed++;
          }
        }
        inFence = false;
      }
    }
    writeFileSync(path, lines.join("\n"));
  }
}
console.log(`${changed} fences retagged`);
