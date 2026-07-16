---
title: Tests Become Theorems
description: Dependent types turn "r matches s" into a data type, and nullable's correctness into a compile-time fact about every regex at once.
---

# Tests Become Theorems

Every spec in this book so far checks finitely many examples, chosen by us. This chapter checks *all* inputs at once, and the test runner is the type checker.

## The limit of examples

Our `nullable` specs assert that `nullable Eps` is `True`, that `nullable (lit 'a')` is `False`, and so on through a handful of cases. Good tests. But `Regex` is an infinite type; there will always be regexes no spec has met. When we say "`nullable r` is `True` exactly when `r` matches the empty string", we are making a claim about **every** regex, a for-all sentence, and no finite list of examples can pin one of those down.

This is where Idris stops being "a nice functional language" and becomes what it actually is. In a dependently typed language, a for-all sentence can be written as a *type*, and a proof of it is an ordinary *program* with that type. If the program type-checks, the sentence is true for every input, forever. No test data, no coverage gaps.

## Red: the strangest failing test in the book

Commit [f4ee977](https://github.com/ubugeeei-prod/lets-start-functional/commit/f4ee977db100cd755430936586eba1ffb4988166) adds [`regex/tests/src/Spec/Verified.idr`](https://github.com/ubugeeei-prod/lets-start-functional/blob/main/regex/tests/src/Spec/Verified.idr), which is short enough to quote whole:

```idris
||| Specs for `Regex.Verified` — where the tests become theorems.
|||
||| Everything else in this suite checks examples: finitely many
||| inputs, chosen by us. The proofs in `Regex.Verified` check *all*
||| inputs at once, and their test runner is the type checker: if
||| this module's import compiles, the theorems hold.
|||
||| The one runtime spec below is a marker so the suite output
||| mentions the chapter; the real assertions are compile-time.
module Spec.Verified

import Harness
import Regex.Verified

export
verifiedSpecs : List Spec
verifiedSpecs =
  [ it "nullable is provably sound and complete (checked at compile time)"
      True
  ]
```

Yes: the one runtime spec asserts `True`. It is a marker, so the suite output mentions this chapter. The real test is the second line of the module: `import Regex.Verified`. If that import compiles, the theorems hold; and right now it does not, which is this chapter's red:

```
Error: Module Regex.Verified not found
```

A failing *compile* has been a perfectly good red since [TDD and a Tiny Test Harness](./05-tdd.md). This time it is the whole show.

## What "matches" means, as a type

Commit [74617c0](https://github.com/ubugeeei-prod/lets-start-functional/commit/74617c0af8ca625b65dfa2e275110fb030af27e3) adds [`regex/src/Regex/Verified.idr`](https://github.com/ubugeeei-prod/lets-start-functional/blob/main/regex/src/Regex/Verified.idr). Before we can prove `nullable` correct, we need a definition of correct that does not mention `nullable`: an independent statement of what "`r` matches `cs`" *means*.

```idris
||| Evidence that the regex `r` matches the character list `cs`.
|||
||| Read each constructor as a rule of inference. There is no code
||| here — a value of this type is a *derivation*, like the ones you
||| would draw on paper in a theory course.
public export
data Matches : Regex -> List Char -> Type where
  ||| ε matches the empty string.
  MEps   : Matches Eps []
  ||| A set matches any single member. The `member c s = True`
  ||| argument is itself evidence — a proof obligation, not a Bool
  ||| we promise to have checked.
  MSym   : (c : Char) -> member c s = True -> Matches (Sym s) [c]
  ||| If `l` matches `xs` and `r` matches `ys`, the concatenation
  ||| matches `xs ++ ys`. (The lists are bound explicitly so that
  ||| proofs may inspect them — see the erasure aside in the book.)
  MCat   : {xs, ys : List Char} ->
           Matches l xs -> Matches r ys -> Matches (Cat l r) (xs ++ ys)
  ||| A choice matches whatever its left branch matches...
  MAltL  : Matches l xs -> Matches (Alt l r) xs
  ||| ...or whatever its right branch matches. (`l` kept relevant,
  ||| again for the proofs.)
  MAltR  : {l : Regex} -> Matches r xs -> Matches (Alt l r) xs
  ||| A star matches the empty string (zero repetitions)...
  MStarZ : Matches (Star r) []
  ||| ...or one non-empty repetition followed by more star. The
  ||| non-emptiness (`c ::`) is what keeps derivations finite.
  MStarS : Matches r (c :: xs) -> Matches (Star r) ys ->
           Matches (Star r) (c :: (xs ++ ys))

-- Note what is NOT here: no constructor mentions Fail. `Fail`
-- matches nothing precisely because there is no way to build
-- evidence for it.
```

This is a `data` declaration like `Regex` itself, but its type is `Regex -> List Char -> Type`. `Matches r cs` is a *different type for every pair* of regex and input, and a value of that type is **evidence** that this regex matches that input. Read each constructor as a rule of inference: `MEps` is an axiom ("ε matches `[]`, no premises"); `MCat` says "from evidence for `l` on `xs` and evidence for `r` on `ys`, conclude `Cat l r` on `xs ++ ys`". A value like `MCat (MSym 'a' _) (MSym 'b' _)` is a derivation tree, the thing you would draw on a whiteboard in a theory course, except the compiler checks it.

Two details deserve a pause:

- **No constructor mentions `Fail`.** How do you say "matches nothing" in evidence terms? You say nothing. There is simply no way to build a value of type `Matches Fail cs`, for any `cs`: the type is empty, and that emptiness *is* the semantics of `Fail`.
- **`MStarS` requires the first repetition to be non-empty**: its body matches `c :: xs`, never `[]`. Semantically this loses nothing (an empty repetition contributes nothing to a star), but it keeps derivations finite. Without it, `Star Eps` matching `[]` would have infinitely many derivations, each stacking one more useless `MStarS` on top, and induction over derivations would have no floor to stand on.

## Two boolean lemmas

`nullable` computes with `&&` and `||`, so the proofs need two small facts about them:

```idris
||| Boolean fact: if `a && b` came out True, both sides are True.
andBoth : {a, b : Bool} -> a && b = True -> (a = True, b = True)
andBoth {a = True}  {b = True}  Refl = (Refl, Refl)
andBoth {a = True}  {b = False} prf  = absurd prf
andBoth {a = False}             prf  = absurd prf

||| Boolean fact: if `a || b` came out True, one side is True.
orEither : {a, b : Bool} -> a || b = True -> Either (a = True) (b = True)
orEither {a = True}  _   = Left Refl
orEither {a = False} prf = Right prf
```

Look at how these are proved: **by pattern matching on which `Bool` it was**. When `a` and `b` are both `True`, the claim `a && b = True` becomes `True = True`, whose only proof is `Refl`, and the conclusion is two more `Refl`s. When `a` is `True` and `b` is `False`, the premise says `False = True`, which is absurd; `absurd prf` dismisses the case by pointing at the impossible evidence. There is no proof language here, no tactics: just the same case analysis you have written all book, applied to propositions.

## Soundness: when nullable says yes, it is right

```idris
||| **Soundness**: when `nullable r` says True, there really is a
||| derivation of `r` matching the empty string.
|||
||| The proof is induction on `r` — which in Idris is just pattern
||| matching and recursion, the same tools we have used all book.
export
nullableSound : (r : Regex) -> nullable r = True -> Matches r []
nullableSound Fail      prf = absurd prf
nullableSound Eps       _   = MEps
nullableSound (Sym s)   prf = absurd prf
nullableSound (Cat l r) prf =
  let (pl, pr) = andBoth prf
  in MCat (nullableSound l pl) (nullableSound r pr)
nullableSound (Alt l r) prf =
  case orEither prf of
    Left  pl => MAltL (nullableSound l pl)
    Right pr => MAltR (nullableSound r pr)
nullableSound (Star r)  _   = MStarZ
```

Read the type as a sentence: *for every regex `r`, if `nullable r = True`, then there is evidence that `r` matches `[]`*. The function body is the proof, and "induction on `r`" turns out to be technology you already own: pattern matching on each constructor, recursive calls for subterms. In the `Fail` case, the premise claims `nullable Fail = True`, i.e. `False = True`, so `absurd`. In the `Cat` case, split the `&&` with `andBoth` and recurse on both halves; note quietly that `MCat` here matches `[] ++ []`, which the compiler *computes* to `[]`, so no lemma is needed. Because the totality checker accepts this function, the induction is well-founded; a partial function would be a circular argument, and Idris would refuse it.

## An impossible case is one you cannot even state

Completeness needs a list fact first:

```idris
||| List fact: a concatenation is empty only when both halves are.
appendNil : (xs, ys : List a) -> xs ++ ys = [] -> (xs = [], ys = [])
appendNil []        []        _    = (Refl, Refl)
appendNil []        (y :: ys) Refl impossible
appendNil (x :: xs) _         Refl impossible

||| Boolean fact: anything or-ed with True is True.
orTrueRight : (a : Bool) -> a || True = True
orTrueRight True  = Refl
orTrueRight False = Refl
```

The keyword `impossible` is new. It marks a clause that cannot even be *stated*: in the second line, `xs = []` and `ys = y :: ys`, so the premise would need type `y :: ys = []`, and `Refl` can never have that type, because a cons cell and `[]` are different constructors. We are not handling the case and returning something; we are showing the compiler that the case has no well-typed left-hand side at all, and the compiler verifies that claim. It is exhaustiveness checking, extended to cases that logic itself rules out.

## Completeness: when there is a match, nullable says yes

```idris
||| **Completeness**: when there is a derivation of `r` matching
||| the empty string, `nullable r` says True.
|||
||| This time the induction is on the *derivation*. The equation
||| argument `cs = []` lets each case learn what the emptiness of
||| the input tells us about its sub-derivations.
export
nullableComplete : Matches r cs -> cs = [] -> nullable r = True
nullableComplete MEps _ = Refl
nullableComplete (MSym c p) Refl impossible
nullableComplete (MCat {xs} {ys} pl pr) prf =
  let (ex, ey) = appendNil xs ys prf
      nl = nullableComplete pl ex
      nr = nullableComplete pr ey
  in rewrite nl in rewrite nr in Refl
nullableComplete (MAltL pl) prf =
  rewrite nullableComplete pl prf in Refl
nullableComplete (MAltR {l} pr) prf =
  rewrite nullableComplete pr prf in orTrueRight (nullable l)
nullableComplete MStarZ _ = Refl
nullableComplete (MStarS p ps) Refl impossible
```

The induction is now on the *derivation*: we pattern match on the evidence itself. And notice the shape of the statement: not `Matches r [] -> ...` but `Matches r cs -> cs = [] -> ...`. The separate equation argument is a standard proof move: it lets each case *learn* things. In the `MCat` case, the input is `xs ++ ys` and the equation says `xs ++ ys = []`; `appendNil` converts that into `xs = []` and `ys = []`, which is exactly what the two recursive calls need. In the `MSym` case, the input is `[c]`, so the equation would be `[c] = []`: `impossible`. Same for `MStarS`, whose input starts with a cons. This is the non-emptiness condition earning its keep.

`rewrite eq in expr` is the last new tool: it rewrites the goal using an equation. In the `MCat` case the goal is `nullable l && nullable r = True`; rewriting with `nl : nullable l = True` and `nr : nullable r = True` turns it into `True && True = True`, which computes to `True = True`, closed by `Refl`. In `MAltR` the goal becomes `nullable l || True = True`, which does *not* compute away (the `||` is stuck on the unknown `nullable l`), so `orTrueRight` finishes by cases.

## The erasure aside

Why do `MCat` and `MAltR` spell out implicit arguments (`{xs, ys : List Char}`, `{l : Regex}`) when Idris would happily infer them? Because of *erasure*. Idris 2 gives unmentioned constructor implicits quantity `0`: they exist for type checking and are erased before runtime, so you may not pattern match on them. But `nullableComplete (MCat {xs} {ys} pl pr)` *does* inspect `xs` and `ys` (it passes them to `appendNil`), and the `MAltR` case needs `l` for `orTrueRight (nullable l)`. Binding them explicitly in the constructor keeps them relevant, available to proofs. The doc comments on those constructors say exactly this, so future readers know the unusual spelling is load-bearing. Proofs are programs; erasure is the one place the two roles visibly negotiate.

## Derivations you can hold

Evidence types are not only for theorems; you can build concrete derivations by hand:

```idris
||| Evidence that `ab` matches "ab": a concatenation of two
||| one-character derivations. The membership proofs are `Refl`
||| because `member 'a' (single 'a')` *computes* to True.
export
exampleAB : Matches (Cat (lit 'a') (lit 'b')) ['a', 'b']
exampleAB = MCat (MSym 'a' Refl) (MSym 'b' Refl)

||| Evidence that `a*` matches "aa": two repetitions, then zero.
export
exampleStar : Matches (Star (lit 'a')) ['a', 'a']
exampleStar = MStarS (MSym 'a' Refl) (MStarS (MSym 'a' Refl) MStarZ)
```

The lovely detail: `MSym` demands evidence that `member c s = True`, and the evidence is just `Refl`, because `member 'a' (single 'a')` is a closed expression the type checker *runs*, and it computes to `True`. Our ordinary, executable `member` function from [Character Classes](./11-character-classes.md) is doing double duty as part of the logic. Programs and proofs are not two worlds here; the whole point of dependent types is that they are one.

```sh
make test
```

```
  ...
  ok    nullable is provably sound and complete (checked at compile time)
155/155 passed
```

One `ok` line for two theorems about infinitely many regexes. The suite has never said so much while printing so little.

## Honesty about scope

We proved `nullable` sound and complete against `Matches`. We did **not** prove the same for `deriv`. The statement is easy to write (`Matches (deriv c r) cs` holds exactly when `Matches r (c :: cs)` does), but the `Star` and `Cat` cases need induction along a subtler measure than plain structure, and the proof is genuinely harder. That is the boss-level exercise waiting in [What's Next](./21-whats-next.md), and the Owens–Reppy–Turon paper referenced there walks the mathematics. What we have already is not a toy, though: `nullable` is one of the two functions the entire engine rests on, and its correctness is now a compile-time fact.

## Summary

- A for-all claim cannot be established by finitely many examples, but in Idris it can be written as a type, and a proof is an ordinary total program with that type. The type checker is the test runner.
- `Matches : Regex -> List Char -> Type` defines matching as evidence; each constructor is a rule of inference, `Fail` has no rule at all, and `MStarS`'s non-empty repetition keeps derivations finite.
- Proof techniques are the book's usual tools wearing formal hats: induction is pattern matching plus recursion, case dismissal is `absurd` and `impossible`, and `rewrite` plus the fact that functions *compute* handles the rest.
- Constructor implicits are erased (quantity 0) by default; `MCat` and `MAltR` bind theirs explicitly because the proofs need to inspect them.
- `exampleAB` and `exampleStar` are hand-held derivations, with `Refl` membership proofs because `member` computes.
- The suite shows one marker line (`155/155 passed`) while the real assertions ran at compile time, over every regex at once.

Theory has had its say; next we go racing. [The Race: Linear vs Backtracking](./19-the-race.md) finally builds the rival engine this book has been warning you about, and the first run did not go the way we expected.
