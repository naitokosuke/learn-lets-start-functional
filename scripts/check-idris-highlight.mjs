import { createHighlighter } from "shiki";
import haskell from "shiki/langs/haskell.mjs";

const idris = { ...haskell[0], name: "idris", aliases: ["idris2"] };

const hl = await createHighlighter({
  themes: [
    {
      name: "lsf-mono",
      type: "dark",
      colors: {},
      settings: [{ settings: { background: "#101010", foreground: "#d6d6d6" } }],
    },
  ],
  langs: ["bash", idris],
});

const html = hl.codeToHtml("nullable : Regex -> Bool\nnullable Fail = False", {
  lang: "idris",
  theme: "lsf-mono",
});
console.log(html.slice(0, 300));
