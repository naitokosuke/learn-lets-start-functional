import { defineConfig } from "vite-plus";
import { oxContent, defineTheme, defaultTheme } from "@ox-content/vite-plugin";
import haskell from "shiki/langs/haskell.mjs";
import githubDarkDefault from "shiki/themes/github-dark-default.mjs";

// ---------------------------------------------------------------------------
// Locale — the site is built twice: English at "/", Japanese at "/ja/".
// ---------------------------------------------------------------------------

const locale = process.env.DOCS_LOCALE === "ja" ? "ja" : "en";
const isJa = locale === "ja";

// ---------------------------------------------------------------------------
// Table of contents — one definition, two languages.
// ---------------------------------------------------------------------------

interface Chapter {
  slug: string;
  en: string;
  ja: string;
}

interface Part {
  en: string;
  ja: string;
  items: Chapter[];
}

const toc: Part[] = [
  {
    en: "Introduction",
    ja: "はじめに",
    items: [
      { slug: "why-functional", en: "Why Functional? Why Idris?", ja: "なぜ関数型?なぜ Idris?" },
      { slug: "regex-engines", en: "What Is a Regex Engine?", ja: "正規表現エンジンとは" },
      { slug: "setup", en: "Setting Up", ja: "環境構築" },
      { slug: "idris-crash-course", en: "An Idris Crash Course", ja: "Idris 速習" },
      { slug: "tdd", en: "TDD and a Tiny Test Harness", ja: "TDD と小さなテストハーネス" },
    ],
  },
  {
    en: "The Core Engine",
    ja: "コアエンジン",
    items: [
      { slug: "regex-as-data", en: "A Regex Is Data", ja: "正規表現はデータである" },
      { slug: "nullable", en: "nullable: Matching Nothing", ja: "nullable:空文字列とのマッチ" },
      { slug: "derivatives", en: "The Derivative", ja: "微分" },
      { slug: "matches", en: "matches: The Whole Engine", ja: "matches:エンジン完成" },
    ],
  },
  {
    en: "Making It Practical",
    ja: "実用にする",
    items: [
      { slug: "smart-constructors", en: "Smart Constructors", ja: "スマートコンストラクタ" },
      { slug: "character-classes", en: "Character Classes", ja: "文字クラス" },
      { slug: "sugar", en: "Sugar Is Just Functions", ja: "糖衣構文はただの関数" },
      { slug: "parser-combinators", en: "Parser Combinators", ja: "パーサコンビネータ" },
      { slug: "pattern-syntax", en: "Parsing Pattern Syntax", ja: "パターン構文をパースする" },
      { slug: "public-api", en: "A Public API", ja: "公開 API" },
    ],
  },
  {
    en: "Idris Power-Ups",
    ja: "Idris の真価",
    items: [
      { slug: "interfaces", en: "Interfaces and Two Monoids", ja: "インターフェースと2つのモノイド" },
      { slug: "pretty-printing", en: "Printing Patterns Back", ja: "パターンを印字し直す" },
      { slug: "proofs", en: "Tests Become Theorems", ja: "テストが定理になる" },
      { slug: "the-race", en: "The Race: Linear vs Backtracking", ja: "対決:線形時間 vs バックトラック" },
      { slug: "lexer", en: "Capstone: A Lexer", ja: "総仕上げ:レキサ" },
      { slug: "whats-next", en: "What's Next", ja: "この先へ" },
    ],
  },
];

const sidebar = toc.map((part) => ({
  text: part[locale],
  items: part.items.map((ch) => ({
    text: ch[locale],
    link: `/${ch.slug}.md`,
  })),
}));

// ---------------------------------------------------------------------------
// Syntax highlighting — a monochrome theme, plus Idris (the Haskell
// TextMate grammar is close enough to lex Idris 2 sources).
// ---------------------------------------------------------------------------

// The Haskell TextMate grammar is close enough to lex Idris 2 sources.
// (The alias list must not contain the name itself — shiki treats that
// as a circular alias.)
const idris = {
  ...haskell[0],
  name: "idris",
  aliases: ["idris2"],
};

// Real syntax colors for code, on a near-black flat background that
// sits quietly inside the otherwise monochrome design.
const codeTheme = githubDarkDefault;

// ---------------------------------------------------------------------------
// Theme — monochrome, flat, quiet. No shadows, no gradients, no serifs.
// ---------------------------------------------------------------------------

const customCss = `
  * { box-shadow: none !important; text-shadow: none !important; }
  .content a { text-decoration: underline; text-underline-offset: 2px; }
  .content h1, .content h2, .content h3 { letter-spacing: -0.01em; }
  /* the default theme fades code blocks with a top gradient — keep them flat */
  .content pre {
    background: var(--octc-color-code-bg) !important;
    position: relative;
  }
  .code-copy {
    position: absolute;
    top: 8px;
    right: 8px;
    padding: 2px 8px;
    font-family: var(--octc-font-sans);
    font-size: 12px;
    line-height: 1.6;
    color: #9a9a9a;
    background: transparent;
    border: 1px solid #333333;
    border-radius: 0;
    cursor: pointer;
    opacity: 0;
    transition: opacity 0.15s ease, color 0.15s ease;
  }
  .content pre:hover .code-copy,
  .code-copy:focus-visible { opacity: 1; }
  .code-copy:hover { color: #ededed; border-color: #555555; }
  .content blockquote {
    border-left: none;
    padding-left: 0;
    color: var(--octc-color-text-muted);
  }
  .content blockquote.ox-callout {
    border: 1px solid var(--octc-color-border);
    background: var(--octc-color-bg-alt);
    border-radius: 0;
    padding: 0.875rem 1rem;
    color: var(--octc-color-text);
  }
  .toc-link, .toc-link:hover, .toc-link.active {
    border-left: none;
  }
  #lang-switch {
    font-size: 13px;
    color: var(--octc-color-text-muted);
    text-decoration: none;
    padding: 0 8px;
  }
  #lang-switch:hover { color: var(--octc-color-text); }
`;

const langSwitchJs = `
  (function () {
    var link = document.getElementById("lang-switch");
    if (!link) return;
    var path = location.pathname;
    link.href = path.indexOf("/ja/") === 0 ? (path.slice(3) || "/") : "/ja" + path;
  })();
  (function () {
    function addCopyButtons() {
      document.querySelectorAll(".content pre").forEach(function (pre) {
        if (pre.querySelector(".code-copy")) return;
        var btn = document.createElement("button");
        btn.className = "code-copy";
        btn.type = "button";
        btn.textContent = "Copy";
        btn.addEventListener("click", function () {
          var code = pre.querySelector("code");
          var text = (code || pre).innerText.replace(/\\n$/, "");
          navigator.clipboard.writeText(text).then(function () {
            btn.textContent = "Copied";
            setTimeout(function () { btn.textContent = "Copy"; }, 1500);
          });
        });
        pre.appendChild(btn);
      });
    }
    if (document.readyState === "loading") {
      document.addEventListener("DOMContentLoaded", addCopyButtons);
    } else {
      addCopyButtons();
    }
  })();
`;

// ---------------------------------------------------------------------------

export default defineConfig({
  base: isJa ? "/ja/" : "/",
  build: {
    outDir: isJa ? "dist/ja" : "dist",
  },
  plugins: [
    oxContent({
      srcDir: isJa ? "content/ja" : "content/en",
      outDir: isJa ? "dist/ja" : "dist",
      base: isJa ? "/ja/" : "/",
      highlight: true,
      highlightTheme: codeTheme,
      highlightLangs: [idris],
      docs: false,
      search: { enabled: true, hotkey: "/" },
      ssg: {
        siteName: "Let's Start Functional",
        theme: defineTheme({
          extends: defaultTheme,
          entryPage: { mode: "subtle" },
          fonts: {
            sans: 'system-ui, -apple-system, "Segoe UI", "Hiragino Sans", "Noto Sans CJK JP", sans-serif',
            mono: 'ui-monospace, "SF Mono", "Cascadia Mono", Menlo, Consolas, monospace',
          },
          colors: {
            primary: "#111111",
            primaryHover: "#000000",
            background: "#ffffff",
            backgroundAlt: "#f7f7f7",
            text: "#1a1a1a",
            textMuted: "#6e6e6e",
            border: "#e5e5e5",
            codeBackground: "#0d1117",
            codeText: "#e6edf3",
          },
          darkColors: {
            primary: "#ededed",
            primaryHover: "#ffffff",
            background: "#0a0a0a",
            backgroundAlt: "#121212",
            text: "#ededed",
            textMuted: "#8f8f8f",
            border: "#242424",
            codeBackground: "#0d1117",
            codeText: "#e6edf3",
          },
          layout: {
            maxContentWidth: "760px",
          },
          sidebar,
          footer: {
            message: isJa ? "MIT ライセンスで公開" : "Released under the MIT License",
            copyright: "© 2026 ubugeeei",
          },
          socialLinks: {
            github: "https://github.com/ubugeeei-prod/lets-start-functional",
          },
          embed: {
            head: `<link rel="icon" type="image/svg+xml" href="${isJa ? "/ja" : ""}/favicon.svg" />`,
            headerAfter: `<a id="lang-switch" href="${isJa ? "/" : "/ja/"}">${isJa ? "English" : "日本語"}</a>`,
          },
          css: customCss,
          js: langSwitchJs,
        }),
      },
    }),
  ],
});
