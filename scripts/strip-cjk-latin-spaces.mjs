// Remove manual ASCII spaces between CJK and Latin/digits in Japanese
// prose. Visual spacing is the renderer's job (CSS text-autospace).
// Fenced code blocks and inline-code contents are left untouched.
import { readFileSync, writeFileSync, readdirSync } from "node:fs";

const CJK =
  "[\\u3000-\\u303F\\u3040-\\u30FF\\u4E00-\\u9FFF\\uFF01-\\uFF60\\u3400-\\u4DBF]";
const LATIN = "[A-Za-z0-9`*_([\"']";
const LATIN_END = "[A-Za-z0-9`*_)\\]\"'.,!?:;%]";

const despaceText = (text) =>
  text
    .replace(new RegExp(`(${CJK}) +(${LATIN})`, "g"), "$1$2")
    .replace(new RegExp(`(${LATIN_END}) +(${CJK})`, "g"), "$1$2");

// Apply outside inline-code spans: split on backtick runs, transform
// only the even segments (outside code), keep code segments intact.
// Inline code counts as Latin for its neighbors: `deriv` の -> `deriv`の.
const cjkTail = new RegExp(`(${CJK}) +$`);
const cjkHead = new RegExp(`^ +(${CJK})`);
const despaceLine = (line) => {
  const parts = line.split(/(`[^`]*`)/);
  for (let i = 0; i < parts.length; i += 2) parts[i] = despaceText(parts[i]);
  for (let i = 1; i < parts.length; i += 2) {
    parts[i - 1] = parts[i - 1].replace(cjkTail, "$1");
    if (i + 1 < parts.length) parts[i + 1] = parts[i + 1].replace(cjkHead, "$1");
  }
  return parts.join("");
};

// Optional CLI args restrict the run to specific files (basenames).
const only = process.argv.slice(2);
let changed = 0;
for (const f of readdirSync("content/ja").filter(
  (f) => f.endsWith(".md") && (only.length === 0 || only.includes(f)),
)) {
  const path = `content/ja/${f}`;
  const lines = readFileSync(path, "utf8").split("\n");
  let inFence = false;
  const out = lines.map((line) => {
    if (/^```/.test(line)) {
      inFence = !inFence;
      return line;
    }
    if (inFence) return line;
    // Frontmatter keys keep their "key: " separator (YAML needs it).
    const fm = line.match(/^(\w+): (.*)$/);
    const next = fm
      ? `${fm[1]}: ${despaceLine(fm[2])}`
      : despaceLine(line);
    if (next !== line) changed++;
    return next;
  });
  writeFileSync(path, out.join("\n"));
}
console.log(`${changed} lines despaced`);
