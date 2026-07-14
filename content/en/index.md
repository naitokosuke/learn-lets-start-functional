---
title: Let's Start Functional
description: Learn functional programming by building a linear-time regex engine in Idris 2, test-first.
---

# Let's Start Functional

*Learn functional programming by building a linear-time regular expression engine in Idris 2 — test-first, step by step.*

Functional programming has a reputation: beautiful, powerful, and impossible to start. Monad tutorials that explain burritos. Type theory before "hello world". This book takes the opposite route. We are going to **build one small, real, useful thing** — a regular expression engine — and let every language feature earn its keep along the way.

By the last chapter you will have written, in Idris 2:

- a **complete regex engine** — classes, escapes, counted repetition, the lot — that matches in a **single left-to-right pass**, immune by construction to the catastrophic backtracking that has taken down real services;
- a **parser-combinator library** from scratch, in about a screen of code;
- a **machine-checked proof** that part of your engine is correct — not tested on examples: *proved*, for every input;
- a working **lexer** built on top of your engine, as a capstone.

Every feature starts with a failing test. The commit history of the repository *is* the tutorial — each step is a small red/green commit you can replay.

## Who is this for?

You can program — in JavaScript, Python, Rust, Java, anything — and you are curious about functional programming. **No Haskell, no category theory, no prior Idris knowledge required.** If you have bounced off functional programming before, this book was written for you.

## How to read

The chapters build on each other, so read them in order. Each one follows the same rhythm:

1. a question we cannot answer yet,
2. a failing test that pins the question down,
3. the smallest amount of code that answers it,
4. and a look at what the language just did for us.

Head to [Why Functional? Why Idris?](./01-why-functional.md) to begin.

> [!NOTE]
> All the code lives at [github.com/ubugeeei-prod/lets-start-functional](https://github.com/ubugeeei-prod/lets-start-functional) — the `regex/` directory is the engine, and every chapter's red/green steps are separate commits.
