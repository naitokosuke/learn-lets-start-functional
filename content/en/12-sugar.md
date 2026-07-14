---
title: Sugar Is Just Functions
description: Add +, ?, {n,m} and string literals without touching the engine — each one is a small function that compiles down to the six core constructors.
---

# Sugar Is Just Functions

Every regex flavor offers `+`, `?` and `{n,m}`, and our AST has none of them. This chapter adds them all without touching the engine — because none of them are new features.

## No new matching power

Ask what `a+` means: "one or more `a`s". But that is exactly "`a`, followed by zero or more `a`s" — `a·a*`. And `a?` — "zero or one" — is exactly the choice `a|ε`. And `a{3}` is `a·a·a`. Every one of these convenience forms can be *defined* in terms of the six constructors we already have. They add notation, not power.

This suggests a deliberately functional way to grow a feature set: keep the core language minimal, and make everything else a definition. The engine — `nullable`, `deriv`, `matches` — will never learn that `plus` exists, and never has to. A feature that is a function needs no new cases anywhere, no changes to the matcher, and no new proofs later when we start proving things. This is the same design that keeps mathematics manageable: a handful of axioms, and everything else is theorems.

## Red: specs for the convenience layer

A new spec file, `regex/tests/src/Spec/Sugar.idr`. The specs come in two kinds: some check *behavior* (does `a+` reject the empty string?), and some check the *definition itself* — `plus r` should literally be the tree `Cat r (Star r)`:

```idris
||| Specs for `Regex.Sugar` — the convenience layer.
|||
||| `+`, `?`, `{n,m}` and string literals add no new matching power:
||| they are ordinary functions that *compile down* to the six core
||| constructors. Sugar is cheap when it is just functions.
module Spec.Sugar

import Harness
import Regex.Core
import Regex.Set
import Regex.Sugar

export
sugarSpecs : List Spec
sugarSpecs =
  [ -- plus: one or more
    shouldBe "plus r is literally r followed by r*"
      (plus (lit 'a')) (Cat (lit 'a') (Star (lit 'a')))
  , it "a+ needs at least one a"
      (not (matches (plus (lit 'a')) ""))
  , it "a+ matches one or many"
      (matches (plus (lit 'a')) "a" && matches (plus (lit 'a')) "aaaa")

    -- opt: zero or one
  , shouldBe "opt r is literally a choice between r and Eps"
      (opt (lit 'a')) (Alt (lit 'a') Eps)
  , it "a? matches zero or one a, never two"
      (matches (opt (lit 'a')) ""
        && matches (opt (lit 'a')) "a"
        && not (matches (opt (lit 'a')) "aa"))

    -- literal: a whole string, character by character
  , it "literal matches exactly its own string"
      (matches (literal "abc") "abc" && not (matches (literal "abc") "abd"))
  , shouldBe "the empty literal is Eps"
      (literal "") Eps
```

Counted repetition next — `{n}`, `{n,}` and `{n,m}` as functions named after what they mean:

```idris
    -- counted repetition
  , it "exactly 3 means three, no more, no fewer"
      (matches (exactly 3 (lit 'a')) "aaa"
        && not (matches (exactly 3 (lit 'a')) "aa")
        && not (matches (exactly 3 (lit 'a')) "aaaa"))
  , it "atLeast 2 rejects one but accepts many"
      (not (matches (atLeast 2 (lit 'a')) "a")
        && matches (atLeast 2 (lit 'a')) "aa"
        && matches (atLeast 2 (lit 'a')) "aaaaaa")
  , it "between 2 4 accepts two through four"
      (not (matches (between 2 4 (lit 'a')) "a")
        && matches (between 2 4 (lit 'a')) "aa"
        && matches (between 2 4 (lit 'a')) "aaa"
        && matches (between 2 4 (lit 'a')) "aaaa"
        && not (matches (between 2 4 (lit 'a')) "aaaaa"))
```

And the star of the file: a real pattern, assembled from everything this chapter and the [last one](./11-character-classes.md) built. A `where` block keeps it readable:

```idris
    -- sugar composes with everything else
  , it "\\d{4}-\\d{2}-\\d{2} matches a date"
      (matches datePattern "2026-07-14")
  , it "the date pattern rejects a malformed date"
      (not (matches datePattern "2026-7-14"))
  ]
  where
    datePattern : Regex
    datePattern =
      cat (exactly 4 (Sym digit))
        (cat (lit '-')
          (cat (exactly 2 (Sym digit))
            (cat (lit '-') (exactly 2 (Sym digit)))))
```

That is `\d{4}-\d{2}-\d{2}`, written as function calls. Clunky to type, admittedly — a parser for the real notation is exactly where this book is headed — but notice that it is built entirely out of parts that already exist and parts this chapter is about to define.

```sh
make test
```

```
Error: Module Regex.Sugar not found

Spec.Sugar:11:1--11:19
 07 |
 08 | import Harness
 09 | import Regex.Core
 10 | import Regex.Set
 11 | import Regex.Sugar
      ^^^^^^^^^^^^^^^^^^
```

Red. This is commit [fd88430](https://github.com/ubugeeei-prod/lets-start-functional/commit/fd884309997293e9d23d216b2f43448eca8f9385).

## Green: a module of definitions

`regex/src/Regex/Sugar.idr` opens with the design statement, then delivers the one-liners:

```idris
||| The convenience layer: `+`, `?`, `{n,m}` and string literals.
|||
||| None of these add matching power — each one is a small function
||| that builds on the six core constructors. This is a deliberately
||| functional way to design a feature: keep the core minimal, and
||| let everything else be *definitions*, not new machinery.
module Regex.Sugar

import Regex.Core
import Regex.Set

%default total

||| One or more repetitions: `r+` is `r` followed by `r*`.
public export
plus : Regex -> Regex
plus r = cat r (star r)

||| Zero or one: `r?` is a choice between `r` and the empty string.
public export
opt : Regex -> Regex
opt r = alt r Eps
```

Each definition is its own specification read aloud. Note they build with the smart constructors `cat`, `alt`, `star` — sugar gets the simplification algebra from [Smart Constructors](./10-smart-constructors.md) for free.

### String literals: a fold builds the tree

```idris
||| Match a whole string, character by character.
|||
||| A right fold turns `"abc"` into `a · (b · (c · ε))` — the same
||| shape you would have written by hand.
public export
literal : String -> Regex
literal s = foldr (cat . lit) Eps (unpack s)
```

Watch `foldr` work. It replaces every list cons with `cat . lit` and the final nil with `Eps`:

```
unpack "abc"        =  'a' :: ('b' :: ('c' :: []))
literal "abc"       =  cat (lit 'a')
                          (cat (lit 'b')
                             (cat (lit 'c') Eps))
```

The list's own structure *is* the regex's structure; the fold just renames the joints. This is the recurring trick of folds — you rarely write "loop over the string building up a tree", you say what cons and nil should become. And the empty-string case needs no special handling: `foldr` over `[]` is just the seed, `Eps`, which is exactly what "match the empty string" should compile to. The spec `shouldBe "the empty literal is Eps"` passes by construction.

### Counted repetition: numbers are data too

```idris
||| Exactly `n` repetitions: `r{n}`.
|||
||| Recursion on a `Nat` is pattern matching like any other:
||| zero repetitions match the empty string, and `S k` repetitions
||| are one `r` followed by `k` more.
public export
exactly : Nat -> Regex -> Regex
exactly Z     _ = Eps
exactly (S k) r = cat r (exactly k r)
```

Remember from the [crash course](./04-idris-crash-course.md) that `Nat` is an ordinary data type: `Z` (zero) or `S k` (successor of `k`). So we can pattern match on a *number* exactly the way we pattern match on a `Regex`: zero repetitions is `Eps`; `S k` repetitions is one `r` followed by `k` more. No loop counter, no mutation — the number unfolds into the tree, and the totality checker is satisfied because each recursive call is on a strictly smaller `Nat`.

`atLeast` falls out immediately:

```idris
||| At least `n` repetitions: `r{n,}` is `n` copies, then `r*`.
public export
atLeast : Nat -> Regex -> Regex
atLeast n r = cat (exactly n r) (star r)
```

### upTo: the nesting matters

The last piece of `{n,m}` is "up to `k` *optional* repetitions", and it has a subtlety worth slowing down for:

```idris
||| Up to `n` optional repetitions.
|||
||| The nesting matters: `upTo 2 r` is `(r (r)?)?`, so each extra
||| repetition is only allowed after the previous one appeared.
upTo : Nat -> Regex -> Regex
upTo Z     _ = Eps
upTo (S k) r = opt (cat r (upTo k r))
```

The tempting wrong answer is "`k` optional copies in a row": `r? r? … r?`. For plain matching that happens to accept the same strings — but it is the wrong *shape*. It says each repetition is independent, when the truth of `{n,m}` is that the third repetition only makes sense if the second one happened. `upTo` nests instead: `upTo 2 r` is `(r (r)?)?` — an optional group containing `r` followed by *another* optional group. You can only get in to the inner repetition through the outer one. The structure of the data mirrors the dependency between the repetitions, which is exactly what you want when tools other than the matcher (a pretty-printer, say) start reading these trees.

Note also that `upTo` has no `public export` — it is a private helper. `between` is the public face:

```idris
||| Between `n` and `m` repetitions: `r{n,m}` is `n` required copies
||| followed by `m - n` optional ones. (If `m < n`, natural-number
||| subtraction truncates to zero and this means exactly `n`.)
public export
between : (n : Nat) -> (m : Nat) -> Regex -> Regex
between n m r = cat (exactly n r) (upTo (m `minus` n) r)
```

`minus` on `Nat` cannot go below zero — there is no negative `Nat` to go to — so a nonsense request like `between 4 2` quietly truncates to `exactly 4`. Documenting that in the doc comment is the honest move. (Idris's types are expressive enough to *forbid* such calls outright — demand a proof that `n <= m` as an argument — but truncation is a fine, total answer, and this book picks its battles.)

```sh
make test
```

```
  ...
  ok    plus r is literally r followed by r*
  ok    a+ needs at least one a
  ok    a+ matches one or many
  ok    opt r is literally a choice between r and Eps
  ok    a? matches zero or one a, never two
  ok    literal matches exactly its own string
  ok    the empty literal is Eps
  ok    exactly 3 means three, no more, no fewer
  ok    atLeast 2 rejects one but accepts many
  ok    between 2 4 accepts two through four
  ok    \d{4}-\d{2}-\d{2} matches a date
  ok    the date pattern rejects a malformed date
87/87 passed
```

This is commit [1fe9416](https://github.com/ubugeeei-prod/lets-start-functional/commit/1fe941690555c604723d0b381e6e759a568ca42d).

## What the language just did for us

Count what this chapter did *not* require: no change to `Regex`, no new case in `nullable` or `deriv`, no change to `matches`, no new interface. Six new functions, sixty lines with comments, and the engine's feature list roughly doubled. That is what "sugar is just functions" buys.

There is a quiet guarantee hiding in this design, too. Because `plus`, `opt` and friends *only* produce trees made of the six core constructors, every property we ever establish about the core — including the machine-checked proofs coming in [Tests Become Theorems](./18-proofs.md) — automatically covers all the sugar. Features that are definitions inherit correctness from what they are defined on.

> [!TIP]
> When you design your own libraries, this pattern is worth stealing: find the smallest core that everything else can be *defined* in terms of, and grow the friendly surface as plain functions over it. The core stays testable and provable; the surface stays cheap.

## Summary

- `+`, `?`, `{n}`, `{n,}`, `{n,m}` and string literals add notation, not matching power — each is a plain function compiling down to the six core constructors.
- `literal` is a `foldr` that renames a list's joints: `"abc"` becomes `a · (b · (c · ε))`, and the empty string becomes `Eps` for free.
- `exactly` recurses on a `Nat` — numbers are data, so counting is pattern matching.
- `upTo` nests its options — `(r (r)?)?` — so each extra repetition depends on the previous one; `between n m` is `n` required copies then `m - n` optional ones, with truncating `Nat` subtraction.
- The engine never learned any of this happened, which is exactly the point.

The date pattern was still painful to write as function calls — next we build the tool that will let users write `\d{4}-\d{2}-\d{2}` directly, starting with [Parser Combinators](./13-parser-combinators.md).
