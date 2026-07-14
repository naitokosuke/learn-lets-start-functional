// Sanity-check the hand-written Idris TextMate grammar: doc comments
// must come out as comments, keywords as keywords, and so on.
import { createHighlighter } from "shiki";
import githubDarkDefault from "shiki/themes/github-dark-default.mjs";
import { readFileSync } from "node:fs";

const grammar = JSON.parse(readFileSync("syntaxes/idris.tmLanguage.json", "utf8"));
const idris = { ...grammar, name: "idris", aliases: ["idris2"] };

const hl = await createHighlighter({
  themes: [githubDarkDefault],
  langs: [idris],
});

const sample = `||| The Brzozowski derivative: \`deriv c r\` is the regex matching
||| exactly the strings \`s\` such that \`r\` matches \`c :: s\`.
module Regex.Core

import Data.List

%default total

public export
deriv : Char -> Regex -> Regex
deriv _ Fail      = Fail
deriv c (Sym s)   = if member c s then Eps else Fail
deriv c (Cat l r) =
  -- the interesting case
  if nullable l
    then alt (cat (deriv c l) r) (deriv c r)
    else cat (deriv c l) r

between : (n : Nat) -> (m : Nat) -> Regex -> Regex
between n m r = cat (exactly n r) (upTo (m \`minus\` n) r)

greet : String
greet = "hello " ++ show 42 ++ pack ['!']
`;

const tokens = hl.codeToTokensBase(sample, { lang: "idris", theme: "github-dark-default" });
for (const line of tokens.slice(0, 12)) {
  console.log(line.map((t) => `${JSON.stringify(t.content)}${t.color}`).join(" "));
}
