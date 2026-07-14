# Let's Start Functional

Learn functional programming by building a **linear-time regular expression engine** in [Idris 2](https://www.idris-lang.org/) — test-first, step by step.

This repository contains:

- **`regex/`** — the regex engine, written in Idris 2 with TDD. No backtracking, no catastrophic blow-ups: matching runs in a single left-to-right pass over the input.
- **`content/`** — the tutorial book (English / 日本語), built with [Vite+](https://voidzero.dev/) and [Ox Content](https://ox-content.void.app/).

## Why?

Functional programming has a reputation for being hard to start. This tutorial takes the opposite route: instead of abstract theory, we build one small, real, useful thing — a regex engine — and let the language features earn their keep one chapter at a time.

- No prior functional programming experience required.
- Every feature starts with a failing test.
- The commit history *is* the tutorial: each step is a small red/green commit you can replay.

## The book

Read it on the site — [English](https://lets-start-functional.void.app/) / [日本語](https://lets-start-functional.void.app/ja/) — or right here on GitHub, in order:

| # | English | 日本語 |
|---|---------|--------|
| 01 | [Why Functional? Why Idris?](content/en/01-why-functional.md) | [なぜ関数型?なぜ Idris?](content/ja/01-why-functional.md) |
| 02 | [What Is a Regex Engine?](content/en/02-regex-engines.md) | [正規表現エンジンとは](content/ja/02-regex-engines.md) |
| 03 | [Setting Up](content/en/03-setup.md) | [環境構築](content/ja/03-setup.md) |
| 04 | [An Idris Crash Course](content/en/04-idris-crash-course.md) | [Idris 速習](content/ja/04-idris-crash-course.md) |
| 05 | [TDD and a Tiny Test Harness](content/en/05-tdd.md) | [TDD と小さなテストハーネス](content/ja/05-tdd.md) |
| 06 | [A Regex Is Data](content/en/06-regex-as-data.md) | [正規表現はデータである](content/ja/06-regex-as-data.md) |
| 07 | [nullable: Matching Nothing](content/en/07-nullable.md) | [nullable:空文字列とのマッチ](content/ja/07-nullable.md) |
| 08 | [The Derivative](content/en/08-derivatives.md) | [微分](content/ja/08-derivatives.md) |
| 09 | [matches: The Whole Engine](content/en/09-matches.md) | [matches:エンジン完成](content/ja/09-matches.md) |
| 10 | [Smart Constructors](content/en/10-smart-constructors.md) | [スマートコンストラクタ](content/ja/10-smart-constructors.md) |
| 11 | [Character Classes](content/en/11-character-classes.md) | [文字クラス](content/ja/11-character-classes.md) |
| 12 | [Sugar Is Just Functions](content/en/12-sugar.md) | [糖衣構文はただの関数](content/ja/12-sugar.md) |
| 13 | [Parser Combinators](content/en/13-parser-combinators.md) | [パーサコンビネータ](content/ja/13-parser-combinators.md) |
| 14 | [Parsing Pattern Syntax](content/en/14-pattern-syntax.md) | [パターン構文をパースする](content/ja/14-pattern-syntax.md) |
| 15 | [A Public API](content/en/15-public-api.md) | [公開 API](content/ja/15-public-api.md) |
| 16 | [Interfaces and Two Monoids](content/en/16-interfaces.md) | [インターフェースと2つのモノイド](content/ja/16-interfaces.md) |
| 17 | [Printing Patterns Back](content/en/17-pretty-printing.md) | [パターンを印字し直す](content/ja/17-pretty-printing.md) |
| 18 | [Tests Become Theorems](content/en/18-proofs.md) | [テストが定理になる](content/ja/18-proofs.md) |
| 19 | [The Race: Linear vs Backtracking](content/en/19-the-race.md) | [対決:線形時間 vs バックトラック](content/ja/19-the-race.md) |
| 20 | [Capstone: A Lexer](content/en/20-lexer.md) | [総仕上げ:レキサ](content/ja/20-lexer.md) |
| 21 | [What's Next](content/en/21-whats-next.md) | [この先へ](content/ja/21-whats-next.md) |

## Getting started

Read the book, or jump straight into the code:

```sh
cd regex
make test    # build the library and run the whole suite
make bench   # race the derivative engine against a backtracker
```

To run the book locally:

```sh
pnpm install
pnpm dev       # English
pnpm dev:ja    # 日本語
```

## Deploying

The book deploys to [Void](https://void.cloud/) from GitHub Actions using OIDC — no long-lived secret. One-time setup:

1. `pnpm exec void init` locally (log in and link/create the project).
2. Set the repository variable `VOID_PROJECT` to the project slug — the [Deploy workflow](./.github/workflows/deploy.yml) switches on automatically from the next push to `main`.

## License

[MIT](./LICENSE)
