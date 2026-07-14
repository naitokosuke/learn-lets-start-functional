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
