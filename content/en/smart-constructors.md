---
title: Smart Constructors
description: Teach the engine a little regex algebra so derivatives stay small instead of accumulating junk.
---

# Smart Constructors

The engine works, but its derivatives are littered with junk like `Cat Fail (Star (Lit 'a'))`. In this chapter we teach the constructors a little algebra, and the junk stops existing.

## The junk we swept under the rug

Back in [The Derivative](./derivatives.md), one of our own specs pinned down this expectation:

```idris
  , shouldBe "a nullable head lets the character reach the tail too"
      (deriv 'b' (Cat (Star (Lit 'a')) (Lit 'b')))
      (Alt (Cat (Cat Fail (Star (Lit 'a'))) (Lit 'b')) Eps)
```

Look at that expected value. We derived `a*b` by `'b'`, and the honest answer is "the empty string" — the `b` has been consumed, nothing remains. But the tree we got says it in the most roundabout way possible: *either* a branch that starts with `Fail` (and therefore can never match anything), *or* `Eps`.

The engine still gives the right verdicts, because `nullable` patiently walks the whole thing. But every call to `deriv` builds a bigger tree than the one before, and dead branches never get pruned. Match a long string and the derivative snowballs. The theory says linear time; the trees say otherwise.

## A little regex algebra

The fix is not clever. It is a handful of facts you can check in your head:

- `Fail` is *absorbing* for sequencing: nothing followed by anything is still nothing. `Cat Fail r` and `Cat r Fail` both match the empty set.
- `Eps` is the *identity* for sequencing: the empty string followed by `r` is just `r`.
- `Fail` is the *identity* for choice: an impossible branch can be dropped. `Alt Fail r` is just `r`.
- The star of nothing — or of the empty string — can only ever produce the empty string: `Star Fail` and `Star Eps` are both `Eps`.
- A double star collapses: `Star (Star r)` matches exactly what `Star r` does.

If that reads like arithmetic — zero times anything is zero, one times `r` is `r` — that is no accident. Regexes form an algebra, with `Fail` playing zero and `Eps` playing one.

So far our code builds trees with the raw constructors `Cat`, `Alt`, `Star`, which record exactly what they were given, junk and all. The functional move is to build the trees through ordinary lowercase functions — `cat`, `alt`, `star` — that produce the same shapes but apply the algebra *while building*. A function that plays the role of a constructor, but is allowed to think first, is called a **smart constructor**.

## Red: specs for cat, alt, star

The algebra above translates line by line into specs. This goes at the end of `regex/tests/src/Spec/Core.idr`:

```idris
||| Smart constructors: `cat`, `alt` and `star` build the same six
||| shapes, but simplify the obvious algebra on the way —
||| so derivatives stay small instead of accumulating junk.
export
smartSpecs : List Spec
smartSpecs =
  [ shouldBe "Fail swallows a sequence from the left"
      (cat Fail (Lit 'a')) Fail
  , shouldBe "Fail swallows a sequence from the right"
      (cat (Lit 'a') Fail) Fail
  , shouldBe "sequencing with the empty string is a no-op (left)"
      (cat Eps (Lit 'a')) (Lit 'a')
  , shouldBe "sequencing with the empty string is a no-op (right)"
      (cat (Lit 'a') Eps) (Lit 'a')
  , shouldBe "anything else still nests as Cat"
      (cat (Lit 'a') (Lit 'b')) (Cat (Lit 'a') (Lit 'b'))
  , shouldBe "a choice against Fail picks the live branch (left)"
      (alt Fail (Lit 'a')) (Lit 'a')
  , shouldBe "a choice against Fail picks the live branch (right)"
      (alt (Lit 'a') Fail) (Lit 'a')
  , shouldBe "identical branches collapse"
      (alt (Lit 'a') (Lit 'a')) (Lit 'a')
  , shouldBe "anything else still nests as Alt"
      (alt (Lit 'a') (Lit 'b')) (Alt (Lit 'a') (Lit 'b'))
  , shouldBe "the star of Fail can only match the empty string"
      (star Fail) Eps
  , shouldBe "the star of Eps is just Eps"
      (star Eps) Eps
  , shouldBe "a double star collapses to a single one"
      (star (Star (Lit 'a'))) (Star (Lit 'a'))
  , shouldBe "anything else still wraps in Star"
      (star (Lit 'a')) (Star (Lit 'a'))
  ]
```

Note the "anything else" cases: a smart constructor must still be a constructor. When no algebra applies, `cat` builds a plain `Cat`, nothing more.

Add `++ smartSpecs` to the pile in `Main.idr` and run it:

```sh
make test
```

```
Error: While processing right hand side of smartSpecs. Undefined name star.

Spec.Core:111:8--111:12
 107 |       (star Eps) Eps
 108 |   , shouldBe "a double star collapses to a single one"
 109 |       (star (Star (Lit 'a'))) (Star (Lit 'a'))
 110 |   , shouldBe "anything else still wraps in Star"
 111 |       (star (Lit 'a')) (Star (Lit 'a'))
              ^^^^
Did you mean: Star?
```

Red — the functions do not exist yet. (And yes, compiler: we did *not* mean `Star`. That is rather the point.)

This is commit [dc19adf](https://github.com/ubugeeei-prod/lets-start-functional/commit/dc19adfdc758475c87dce8f5613bb820fad1fe28).

## Green: three functions, one pattern match each

Each fact from the algebra becomes one equation in `regex/src/Regex/Core.idr`:

```idris
||| Sequence two regexes — but simplify the obvious cases.
|||
||| These "smart constructors" use two bits of regex algebra:
|||
||| - `Fail` is *absorbing*: nothing followed by anything is nothing.
||| - `Eps` is the *identity*: the empty string followed by `r` is `r`.
|||
||| Why bother? `deriv` builds new regexes out of old ones, and
||| without simplification the results grow junk like
||| `Alt (Cat Fail r) Eps` at every step. Simplifying while building
||| keeps every derivative small — which is what makes the engine
||| fast in practice, not just in theory.
public export
cat : Regex -> Regex -> Regex
cat Fail _   = Fail
cat _   Fail = Fail
cat Eps r    = r
cat r   Eps  = r
cat l   r    = Cat l r

||| Choose between two regexes — but simplify the obvious cases.
|||
||| `Fail` is the identity of choice (an impossible branch can be
||| dropped), and choosing between two identical regexes is no
||| choice at all.
public export
alt : Regex -> Regex -> Regex
alt Fail r    = r
alt l    Fail = l
alt l    r    = if l == r then l else Alt l r

||| Repeat a regex — but simplify the obvious cases.
|||
||| Repeating the impossible (or the empty string) zero-or-more
||| times can only ever produce the empty string, and a double star
||| adds nothing a single star does not.
public export
star : Regex -> Regex
star Fail       = Eps
star Eps        = Eps
star (Star r)   = Star r
star r          = Star r
```

Because Idris tries clauses top to bottom, the special cases come first and the "anything else" clause catches the rest. The algebra is not hidden in an optimizer somewhere — it *is* the function.

One thing bit us on the way to green: `alt` uses `==`, so the `Eq Regex` implementation (and `Show`, which we moved along with it) had to be declared *above* `alt` in the file. Idris reads a module top to bottom, and a name must be defined before it is used. Coming from languages that hoist declarations, this feels strict; the payoff is that you can always read an Idris module linearly and never meet a name you have not already seen.

```sh
make test
```

```
  ok    true is true
  ...
  ok    a double star collapses to a single one
  ok    anything else still wraps in Star
  ...
56/56 passed
```

This is commit [56bc36b](https://github.com/ubugeeei-prod/lets-start-functional/commit/56bc36b6c01f7f8ab2ce5aeb381424eec4d46e19).

> [!WARNING]
> Look closely at `alt`: the check `l == r` only collapses branches that are *exactly* the same tree. `Alt a (Alt b a)` keeps its duplicate `a`, because no two branches being compared are equal at the top. This shallow check is good enough for now — but remember it. In [The Race](./the-race.md), a benchmark will blow up in our faces precisely here, and `alt` will have to grow up.

## Red again: the tests still document the junk

We have smart constructors, but nothing uses them yet. `deriv` still builds with raw `Cat`, `Alt`, `Star` — and our derivative specs still *expect* the junk. Here is the uncomfortable truth about tests: they are documentation, and right now they document the mess as if it were the desired behavior.

So the next red step is not new code — it is rewriting the expectations to describe the output we actually want. The star case, before and after:

```idris
  , shouldBe "a star unrolls one repetition and keeps going"
      (deriv 'a' (Star (Lit 'a')))
      (Cat Eps (Star (Lit 'a')))
```

```idris
  , shouldBe "a star unrolls one repetition, with no Eps junk in front"
      (deriv 'a' (Star (Lit 'a')))
      (Star (Lit 'a'))
```

And the nullable-head case — the noisy tree from the top of this chapter collapses all the way down to `Eps`:

```idris
  , shouldBe "a nullable head lets the character reach the tail too"
      (deriv 'b' (Cat (Star (Lit 'a')) (Lit 'b')))
      (Alt (Cat (Cat Fail (Star (Lit 'a'))) (Lit 'b')) Eps)
```

```idris
  , shouldBe "a nullable head lets the character reach the tail — cleanly"
      (deriv 'b' (Cat (Star (Lit 'a')) (Lit 'b')))
      Eps
```

Updating the expectations *first* keeps us honest: if we changed `deriv` and the specs in one motion, we would never see proof that the change did anything.

```sh
make test
```

```
  ...
  FAIL  a choice derives both branches — and drops the dead one
        expected Eps, got Alt Eps Fail
  FAIL  a star unrolls one repetition, with no Eps junk in front
        expected Star (Lit 'a'), got Cat Eps (Star (Lit 'a'))
  FAIL  a sequence derives its head first, simplified
        expected Lit 'b', got Cat Eps (Lit 'b')
  FAIL  a nullable head lets the character reach the tail — cleanly
        expected Eps, got Alt (Cat (Cat Fail (Star (Lit 'a'))) (Lit 'b')) Eps
  ...
52/56 passed
```

Properly red — and the failure report reads like a to-do list. This is commit [1c1a681](https://github.com/ubugeeei-prod/lets-start-functional/commit/1c1a6815ce8d2be4ddb707030217a54af453f49d).

## Green: deriv builds with the smart constructors

The fix is one line per case: wherever `deriv` built with an uppercase constructor, build with the lowercase function instead.

```idris
public export
deriv : Char -> Regex -> Regex
deriv _ Fail      = Fail
deriv _ Eps       = Fail
deriv c (Lit x)   = if c == x then Eps else Fail
deriv c (Cat l r) =
  if nullable l
    then alt (cat (deriv c l) r) (deriv c r)
    else cat (deriv c l) r
deriv c (Alt l r) = alt (deriv c l) (deriv c r)
deriv c (Star r)  = cat (deriv c r) (Star r)
```

The recursion is untouched. The maths of the derivative is exactly what it was; only the *construction* of the answer got smarter. Junk is no longer cleaned up — it is never created.

```sh
make test
```

```
  ...
  ok    a choice derives both branches — and drops the dead one
  ok    a star unrolls one repetition, with no Eps junk in front
  ok    a sequence derives its head first, simplified
  ok    a nullable head lets the character reach the tail — cleanly
  ...
56/56 passed
```

This is commit [cbf210f](https://github.com/ubugeeei-prod/lets-start-functional/commit/cbf210fa33c0691715751cfe04407bd23ed0b8a1).

## What the language just did for us

Notice what a smart constructor is *not*: it is not a new language feature, not a macro, not a compiler pass. `cat` is a function of type `Regex -> Regex -> Regex` — the same type as `Cat`. Because constructors in Idris are just functions that happen to be capitalized, swapping one for the other is frictionless. Data stayed dumb; the intelligence lives in ordinary functions, where we can test it one equation at a time.

And notice what the second red/green pair taught us about tests. A spec that says `deriv` returns `Alt (Cat (Cat Fail ...) ...) Eps` is not wrong, exactly — the engine did return that. But specs are promises to the reader, and that spec promised junk. When behavior *should* change, changing the spec is the first move, watching it fail is the proof, and the implementation change comes last.

## Summary

- Derivatives were correct but bloated: dead `Fail` branches and useless `Eps` prefixes grew with every step.
- Regexes have an algebra — `Fail` is zero, `Eps` is one — and a handful of identities simplify most junk.
- Smart constructors (`cat`, `alt`, `star`) are ordinary functions that build the same trees while applying the algebra; when no rule fires, they fall back to the raw constructor.
- Idris cares about declaration order: `alt` uses `==`, so `Eq Regex` had to be defined above it.
- Rewriting the deriv specs first (red) before switching `deriv` to smart constructors (green) kept the tests honest — they document behavior, including behavior we want to change.
- `alt`'s equality check is shallow; that debt comes due in [The Race](./the-race.md).

Next, the engine learns to match more than one character at a time — `.`, `[a-z]`, `\d` — in [Character Classes](./character-classes.md).
