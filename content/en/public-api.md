---
title: A Public API
description: One import, positioned errors as data, and an unanchored search that needs no new machinery — the front door of the library.
---

# A Public API

The engine is done; now we design its front door. This chapter is less about new algorithms and more about a question every library faces: what should users see, and what should stay behind the curtain?

## What a user should need

As of the [last chapter](./pattern-syntax.md), using our library takes four imports (`Regex.Core`, `Regex.Set`, `Regex.Sugar`, `Regex.Syntax`), knowledge of which module owns which name, and a `compile` that answers malformed patterns with a bare `Nothing` — no hint of what went wrong or where. Fine for us; rude to guests.

The wish list for a front door:

- **One import.** `import Regex` and everything a user needs is in scope.
- **Errors that say where.** Not `Nothing`, and not a prose string either — a *value* carrying the position, so an editor could underline the exact character.
- **The searches people expect.** Whole-string `match`, and unanchored `contains` — because most users asking "does this contain a year?" do not want to write `.*` themselves.
- **A one-call convenience** for scripts: pattern string in, verdict out.

## Red: specs against the front door

`regex/tests/src/Spec/Api.idr`, verbatim:

```idris
||| Specs for the `Regex` module — the front door of the library.
|||
||| Users should need exactly one import. `compile` returns a
||| position-carrying error instead of a bare `Nothing`, and
||| `contains` gives the unanchored search everyone expects.
module Spec.Api

import Data.Either
import Harness
import Regex

||| Compile a pattern we trust, then apply a check to it.
withPattern : String -> (Regex -> Bool) -> Bool
withPattern pat check =
  case compile pat of
    Right r => check r
    Left _  => False

export
apiSpecs : List Spec
apiSpecs =
  [ it "compile accepts a well-formed pattern"
      (isRight (compile "(colou?r|gr[ae]y)"))
  , shouldBe "compile reports the position where parsing gave up"
      (compile "ab)")
      (Left (MkCompileError 2 "unexpected character"))
  , shouldBe "an unterminated class fails at its opening bracket"
      (compile "[oops")
      (Left (MkCompileError 0 "unexpected character"))
  , it "match is whole-string"
      (withPattern "\\d+" (\r => match r "123" && not (match r "a123")))
  , it "contains searches anywhere in the input"
      (withPattern "\\d{4}" (\r => contains r "born in 1991, maybe"))
  , it "contains still rejects when nothing matches"
      (withPattern "\\d{4}" (\r => not (contains r "no year here")))
  , shouldBe "test compiles and searches in one call"
      (test "wor\\w+" "hello world") (Right True)
  , shouldBe "test reports non-matches as Right False"
      (test "xyz" "hello world") (Right False)
  , shouldBe "test propagates compile errors"
      (test "[oops" "anything")
      (Left (MkCompileError 0 "unexpected character"))
  ]
```

The specs commit us to `Either CompileError Regex` — `Right` for success, `Left` for a structured error. And look closely at the two error expectations: `"ab)"` fails at position 2, the stray parenthesis. `"[oops"` fails at position 0 — the *opening* bracket, because the whole class is what never made sense. Those two numbers are about to fall out of the design almost for free.

```sh
make test
```

```
Error: Module Regex not found

Spec.Api:10:1--10:13
 06 | module Spec.Api
 07 |
 08 | import Data.Either
 09 | import Harness
 10 | import Regex
      ^^^^^^^^^^^^
```

Red. This is commit [225458c](https://github.com/ubugeeei-prod/lets-start-functional/commit/225458c6dedb442374bf7cc32c79c8e3f12889b2).

## Green: the Regex module

The new `regex/src/Regex.idr` opens by deciding what users see:

```idris
||| The front door of the library.
|||
||| ```idris example
||| case compile "(colou?r|gr[ae]y)" of
|||   Right r  => contains r "a grey wall"   -- True
|||   Left err => ...
||| ```
|||
||| `import Regex` brings in the AST, the character sets and the
||| sugar (via `import public`), plus the functions below. The
||| parser internals stay behind the curtain.
module Regex

import public Regex.Core
import public Regex.Set
import public Regex.Sugar

import Regex.Parse
import Regex.Syntax

%default total
```

Two kinds of import, and the difference *is* the API design. A plain `import` makes a module's names visible *here*, inside `Regex.idr` — and nowhere else. `import public` goes further: it re-exports, so anyone who writes `import Regex` also gets everything those modules export, as if they had imported them themselves. So `Regex.Core`, `Regex.Set` and `Regex.Sugar` — the AST, the sets, the sugar, the things users build with — travel with the one import. `Regex.Parse` and `Regex.Syntax` are plain imports: we use them below, but `satisfy`, `classItem` and friends do not leak into our users' namespaces. The public surface is declared in five lines of imports.

### Errors are data

```idris
||| What went wrong while compiling a pattern, and where.
public export
record CompileError where
  constructor MkCompileError
  ||| Zero-based index into the pattern string.
  position : Nat
  message  : String

export
Show CompileError where
  show e = e.message ++ " at position " ++ show e.position

export
Eq CompileError where
  e1 == e2 = e1.position == e2.position && e1.message == e2.message
```

The temptation is to make errors strings — `"unexpected ) at position 2"` — because strings are easy to print. But a string is where information goes to die: an editor that wants to underline position 2 would have to *parse our error message*. A record keeps position and message as separate fields; `Show` is just one way to render it, not the thing itself. Errors are data first, prose second.

### The position trick

Now, how do we know *where* a pattern went wrong? Here is the pleasant surprise: we already do. One small export added to `Regex.Syntax`:

```idris
||| The whole grammar as a single parser, for callers that want to
||| run it themselves (the `Regex` module does, to report positions).
public export
patternParser : Parser Regex
patternParser = alternation
```

And the front-door `compile` runs it with `runParser` instead of `parse`, so it can inspect the leftovers:

```idris
||| Compile a pattern, or say where it went wrong.
|||
||| The underlying parser never dies halfway — it simply stops
||| consuming. So "how far did it get" is exactly "where the
||| pattern stopped making sense", and that is the position we
||| report.
export
covering
compile : String -> Either CompileError Regex
compile s =
  case runParser patternParser (unpack s) of
    Just (r, [])   => Right r
    Just (_, rest) =>
      Left (MkCompileError (length (unpack s) `minus` length rest)
                           "unexpected character")
    Nothing        => Left (MkCompileError 0 "malformed pattern")
```

Because our combinators backtrack fully, the grammar's top rule never crashes midway — when it hits something it cannot make sense of, it simply *stops consuming* and returns what it has, leftovers attached. That turns error location into arithmetic: the parser consumed `length input - length leftover` characters, so that difference is precisely the index where the pattern stopped making sense. No error-tracking machinery threaded through the combinators, no position counter in the parser state. The information was in the leftovers all along; we just had to stop throwing it away.

Check it against the specs. For `"ab)"`, the parser consumes `ab`, refuses the `)`, leaves `")"`: 3 − 1 = position 2. For `"[oops"`, the class parser needs its closing `]`, fails, and backtracking unwinds to before the `[` — nothing is consumed at all: 5 − 5 = position 0, the opening bracket. Both expectations, one subtraction. (The `Nothing` branch is belt and braces: a sequence of zero atoms is `Eps`, so the top rule as written always succeeds — but `case` must be exhaustive, and honest code handles the case rather than asserting it away. Note also the explicit `covering` on `compile`: it calls the parser, and the parser's honesty about totality travels with it.)

### The rest of the surface

```idris
||| Does the regex match the *whole* input? A synonym for
||| `Regex.Core.matches`, under the name users expect.
export
match : Regex -> String -> Bool
match = matches
```

A one-line renaming, and still worth having: an API is a vocabulary, and `match` is the word users will guess first.

```idris
||| Does the regex match *somewhere inside* the input?
|||
||| No new machinery: searching for `r` is matching `.*r.*` against
||| the whole string.
export
contains : Regex -> String -> Bool
contains r = matches (cat dotStar (cat r dotStar))
  where
    dotStar : Regex
    dotStar = star (Sym anyChar)
```

Unanchored search sounds like a new engine feature — surely we need to slide the pattern along the input, trying every start position? We do not. "Contains an `r`-match" is *exactly* "the whole string matches `.*r.*`": anything, then the pattern, then anything. `dotStar` is `star (Sym anyChar)`, built from parts we have had for chapters. The feature is a definition — the [sugar chapter's](./sugar.md) design lesson, still paying out at the API level.

```idris
||| Compile and search in one call — for the quick, one-shot cases.
export
covering
test : (pattern : String) -> (input : String) -> Either CompileError Bool
test pattern input = map (\r => contains r input) (compile pattern)
```

`test` composes the two halves — and look at *how*. `compile pattern` is an `Either CompileError Regex`, and `Either e` is a `Functor`, just like `Parser` was: its `map` transforms the `Right` value and passes any `Left` through untouched. So `map (\r => contains r input)` reads: if compilation succeeded, run the search on the regex; if it failed, the error propagates unchanged. The spec `test "[oops" "anything"` gets its `Left (MkCompileError 0 ...)` without a single `case` in sight. Interfaces you learn once keep showing up where you did not plan for them.

```sh
make test
```

```
  ...
  ok    compile accepts a well-formed pattern
  ok    compile reports the position where parsing gave up
  ok    an unterminated class fails at its opening bracket
  ok    match is whole-string
  ok    contains searches anywhere in the input
  ok    contains still rejects when nothing matches
  ok    test compiles and searches in one call
  ok    test reports non-matches as Right False
  ok    test propagates compile errors
130/130 passed
```

This is commit [36533d1](https://github.com/ubugeeei-prod/lets-start-functional/commit/36533d12bbf392e6973789e96ecd124d8cd295ef).

## What we designed, not just what we wrote

Almost nothing in this chapter is an algorithm. It is a set of decisions:

- **The boundary is explicit.** `import public` versus `import` draws the line between the user's vocabulary and our plumbing. If we rewrite the parser someday, no user code can possibly notice — they never had access to its internals.
- **Errors are values.** A record with a `position` field can feed an editor, a REPL, a language server. A formatted string can only feed `putStrLn`. We implemented `Show` for the humans and kept the structure for everyone else.
- **Positions came from design, not effort.** Because failure in our combinators is "stop and return leftovers" rather than "throw", the error position was recoverable by subtraction. Simple semantics compound: decisions made two chapters ago handed us this chapter's headline feature.
- **Features stayed definitions.** `contains` is `.*r.*`. `test` is a `map`. `match` is a rename. The core did not move.

## Summary

- `import Regex` is now the whole story for users: `import public` re-exports the AST, sets and sugar; the parser modules stay private plumbing.
- `CompileError` is a record — position plus message — because errors are data for tools first and prose for humans second.
- The position trick: a backtracking parser never dies halfway, it stops consuming; `length input - length leftover` *is* the error position. `"ab)"` fails at 2, `"[oops"` at 0.
- `match` renames `matches`; `contains r` is just `.*r.*` — unanchored search with zero new engine code.
- `test` maps over `Either`, which is a `Functor` like `Parser` was — compile errors propagate through `map` with no `case` needed.

The engine now has a front door — and we have used `Show`, `Eq`, `Functor` and friends often enough that it is time to meet the machinery properly, in [Interfaces and Two Monoids](./interfaces.md).
