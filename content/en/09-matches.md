---
title: "matches: The Whole Engine"
description: "Fold the derivative across the input, ask nullable at the end: the complete matcher in one line."
---

# matches: The Whole Engine

We have both halves: [nullable](./07-nullable.md) asks whether a pattern is happy with an empty input, and [the derivative](./08-derivatives.md) feeds a pattern one character. This chapter snaps them together, and the engine is complete.

## The question

Does the regex `r` match the whole string `s`?

You already know the plan, because the last two chapters were the plan. Take the pattern. Feed it the first character of `s`: the derivative gives back the pattern for the rest. Feed *that* pattern the second character. Keep going, left to right, one derivative per character. When the string runs out, look at the pattern you are holding and ask whether it is happy to stop here, in other words whether it matches the empty string. That is `nullable`. If yes, `r` matched `s`. If no, it did not.

There is no search, no retry, and no "try the other branch": every alternative marched along inside the tree the whole time.

## Red: end-to-end expectations

Commit [d1a0950](https://github.com/ubugeeei-prod/lets-start-functional/commit/d1a0950d782a395e88108ab18a3d95b4878b976e) adds the biggest spec list so far to `regex/tests/src/Spec/Core.idr`. For the first time we are testing against *strings*, not trees:

```idris
||| `matches r s` — the whole engine, end to end: derive once per
||| character, then ask `nullable`. Full-string semantics.
export
matchesSpecs : List Spec
matchesSpecs =
  [ it "a literal matches itself"
      (matches (Lit 'a') "a")
  , it "a literal rejects a different character"
      (not (matches (Lit 'a') "b"))
  , it "Eps matches the empty string"
      (matches Eps "")
  , it "matching is exact: 'a' does not match \"ab\""
      (not (matches (Lit 'a') "ab"))
  , it "a sequence matches its halves in order"
      (matches (Cat (Lit 'a') (Lit 'b')) "ab")
  , it "a sequence cares about order"
      (not (matches (Cat (Lit 'a') (Lit 'b')) "ba"))
  , it "a choice accepts its left branch"
      (matches (Alt (Lit 'a') (Lit 'b')) "a")
  , it "a choice accepts its right branch"
      (matches (Alt (Lit 'a') (Lit 'b')) "b")
  , it "a choice rejects anything else"
      (not (matches (Alt (Lit 'a') (Lit 'b')) "c"))
  , it "a* matches the empty string"
      (matches (Star (Lit 'a')) "")
  , it "a* matches one repetition"
      (matches (Star (Lit 'a')) "a")
  , it "a* matches many repetitions"
      (matches (Star (Lit 'a')) "aaaaaa")
  , it "a* rejects intruders"
      (not (matches (Star (Lit 'a')) "aaba"))
  , it "(ab)* matches whole pairs only"
      (matches (Star (Cat (Lit 'a') (Lit 'b'))) "abab")
  , it "(ab)* rejects a dangling half pair"
      (not (matches (Star (Cat (Lit 'a') (Lit 'b'))) "aba"))
  , it "(a|b)*c — a taste of a real pattern"
      (matches (Cat (Star (Alt (Lit 'a') (Lit 'b'))) (Lit 'c')) "abbac")
  ]
```

One spec deserves a highlight before we run anything: `'a' does not match "ab"`. Our `matches` has **full-string semantics**: the pattern must account for *every* character of the input, start to end. This is unlike the regex functions you may know from Python or JavaScript, which by default *search* for a match anywhere inside the string. Full-match is the cleaner primitive: search can be built on top of it (and will be, in the [public API chapter](./15-public-api.md)), but not the other way around.

The rest of the list is the six constructors flexing in combination: order matters for `Cat`, either branch works for `Alt`, `Star` takes zero, one, or many but rejects intruders and dangling half-pairs. The last spec is our first pattern with all the moving parts at once: `(a|b)*c` against `"abbac"`.

Red, one more time:

```
2/3: Building Spec.Core (src/Spec/Core.idr)
Error: While processing right hand side of matchesSpecs. Undefined name matches.

Spec.Core:116:8--116:15
 116 |       (matches (Cat (Star (Alt (Lit 'a') (Lit 'b'))) (Lit 'c')) "abbac")
              ^^^^^^^
```

## Green: one line

Commit [d8e7c5c](https://github.com/ubugeeei-prod/lets-start-functional/commit/d8e7c5c6f718face87df0d6c11e42b6a54dfc339), in `regex/src/Regex/Core.idr`. Sixteen specs, one line of implementation:

```idris
||| Does `r` match the whole string `s`?
|||
||| The entire matching algorithm is one line: fold `deriv` over the
||| characters, then ask `nullable` about what is left.
|||
||| ```
||| matches r "abc"
|||   = nullable (deriv 'c' (deriv 'b' (deriv 'a' r)))
||| ```
|||
||| Each character is consumed exactly once, left to right. There is
||| no backtracking to blow up on adversarial input — the number of
||| derivative steps is always exactly the length of the string.
||| That is the "linear time" in this book's title.
public export
matches : Regex -> String -> Bool
matches r s = nullable (foldl (flip deriv) r (unpack s))
```

If you have never met `foldl`, that line is dense. Let us unpack it, literally, from the inside out.

**`unpack s`** turns the string into a list of characters: `unpack "abc"` is `['a', 'b', 'c']`. Strings in Idris are a primitive type; `unpack` gives us the list view, which is what recursion-friendly code wants.

**`foldl`** is the functional world's left-to-right accumulation loop. `foldl step start xs` walks down the list `xs`, carrying an accumulated value: it starts with `start`, and for each element `x` computes a new accumulated value `step acc x`. If you know JavaScript, it is exactly `xs.reduce(step, start)`.

Here the accumulated value is *the pattern itself*. We start with `r`, and each character transforms the pattern into its derivative. The accumulator is the evolving pattern: the regex we would still need to match if the string started here.

**`flip deriv`** is a small adapter. `foldl` hands the step function its arguments as `(accumulator, element)`: pattern first, character second. But `deriv` takes the character first: `deriv c r`. `flip` swaps a function's two arguments, so `flip deriv` takes pattern-then-character. That is its whole job: `flip f x y = f y x`.

**`nullable (...)`** asks the final question of whatever pattern survived.

For `"abc"`, the fold expands to exactly the pipeline from the doc comment:

```idris
matches r "abc"
  = nullable (deriv 'c' (deriv 'b' (deriv 'a' r)))
```

Derive by `'a'`, then by `'b'`, then by `'c'`, then ask `nullable`. That is the entire engine. Run it:

```sh
make test
```

```
  ok    true is true
  ...
  ok    a nullable head lets the character reach the tail too
  ok    a literal matches itself
  ok    a literal rejects a different character
  ok    Eps matches the empty string
  ok    matching is exact: 'a' does not match "ab"
  ok    a sequence matches its halves in order
  ok    a sequence cares about order
  ok    a choice accepts its left branch
  ok    a choice accepts its right branch
  ok    a choice rejects anything else
  ok    a* matches the empty string
  ok    a* matches one repetition
  ok    a* matches many repetitions
  ok    a* rejects intruders
  ok    (ab)* matches whole pairs only
  ok    (ab)* rejects a dangling half pair
  ok    (a|b)*c — a taste of a real pattern
43/43 passed
```

## Playing with it

The suite is green, but nothing beats matching things with your own hands. From the `regex/` directory, `make repl` (or `idris2 --repl regex.ipkg`) opens a REPL with the library loaded:

```repl
Main> :module Regex.Core
Imported module Regex.Core
Main> :let r = Cat (Star (Alt (Lit 'a') (Lit 'b'))) (Lit 'c')
Main> matches r "abbac"
True
Main> matches r "c"
True
Main> matches r "abca"
False
Main> matches r ""
False
Main> deriv 'a' (Lit 'a')
Eps
```

`r` is `(a|b)*c` as a tree. `"abbac"` matches; so does plain `"c"` (the star took zero repetitions). `"abca"` fails: after the `c`, the pattern wanted the string to end, and full-string semantics means that dangling `a` kills it. And you can call `deriv` directly to watch a single step of the engine in isolation: patterns in, patterns out, everything inspectable. There is no hidden matcher state to print; the engine simply does not have any.

## Linear, honestly stated

The doc comment claims this is the "linear time" in the book's title. Here is the claim, stated carefully.

For an input of length *n*, `matches` performs **exactly *n* derivative steps**: one per character, no more. Each character is consumed exactly once, the input is never re-read, and there is no backtracking: when a choice appears, `deriv` advances *all* branches inside the tree simultaneously instead of trying one, failing, and rewinding. A backtracking engine's worst case explodes combinatorially on patterns like `(a|a)*` (the pathology behind real-world outages, as teased in [the introduction](./02-regex-engines.md)). Our engine cannot express "go back"; the number of steps is *n* by construction.

Now the honest nuance: the number of steps is linear in the input, but the *cost of each step* depends on the size of the pattern tree. `deriv` walks it, and, as the previous chapter's junk-filled expectation showed, raw derivatives can make the tree *grow*. Taming that growth so each step stays cheap is a real engineering problem, and it is where [smart constructors](./10-smart-constructors.md) come in. The full story, with measurements against a genuine backtracker, is the subject of [The Race](./19-the-race.md).

Two more honest limits, both temporary. `matches` is Boolean: it says yes or no, and does not tell you *where* or *what* matched. And it is full-match only: searching for a pattern somewhere inside a longer string will be built on top of it in the [public API chapter](./15-public-api.md).

## There is no loop keyword in this language

One more look at the line that did all the work:

```idris
matches r s = nullable (foldl (flip deriv) r (unpack s))
```

An engine's matching routine is the most loop-shaped code imaginable: *for each character, update the state*. Idris has no `for` and no `while`, and writing this, we never missed them. `foldl` **is** the loop: a plain function that captures the pattern "walk a list, carry a value" once and correctly, for everyone. `flip` is the kind of trivial glue that makes functions snap together. Both are *higher-order functions* (functions whose arguments are themselves functions), and this one line is the moment they stop being a curiosity from the crash course and become the main loop of a real engine.

That is the functional bargain, and it is the same one the whole book keeps making: represent things as data (`Regex`), write small total functions on that data (`nullable`, `deriv`), and compose them with generic combinators (`foldl`, `flip`) instead of bespoke machinery. Six constructors, six equations, six more, one fold: the result is a regex engine that cannot backtrack even if it wanted to.

> [!NOTE]
> Milestone: as of this chapter you have a *complete, working, linear-time regex matcher*. The data type and the three functions on it (`nullable`, `deriv`, `matches`) total about thirty lines of Idris. Everything from here on (simplification, character classes, sugar, parsing, proofs) makes the engine more pleasant, more expressive, or more trustworthy.

## Summary

- `matches r s` answers "does `r` match *all* of `s`?": fold `deriv` across the characters, then ask `nullable`, in one line of code.
- `unpack` lists the characters, `foldl` carries the evolving pattern through them, `flip` adapts argument order, `nullable` renders the verdict; for `"abc"` the fold is `nullable (deriv 'c' (deriv 'b' (deriv 'a' r)))`.
- Semantics are full-string (`Lit 'a'` does not match `"ab"`) and Boolean; searching inside strings and richer results come with the [public API](./15-public-api.md).
- The step count is exactly the input length: no backtracking, no re-reading. The per-step cost depends on pattern size, the nuance that [Smart Constructors](./10-smart-constructors.md) and [The Race](./19-the-race.md) take up.
- `foldl` and `flip`, both higher-order functions, are the engine's main loop; the language has no loop keyword and none was missed.
- The suite stands at 43/43: sanity, AST, `nullable`, `deriv`, and sixteen end-to-end matches, all green.

The engine works, but the derivative's junk trees are still lurking. Next, [Smart Constructors](./10-smart-constructors.md) teaches the constructors to tidy up as they build.
