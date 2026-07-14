---
title: The Derivative
description: Brzozowski's beautiful idea — feed a pattern one character and get back the pattern for the rest of the string.
---

# The Derivative

We can ask a pattern whether it matches the empty string ([nullable](./07-nullable.md)). This chapter adds the other half of the algorithm — and it is the single most beautiful idea in this book. Everything after this is elaboration.

## One question, asked of the pattern

Forget code for a moment. Here is the idea in one sentence:

> If this pattern had to eat the character `c` first, what pattern would be left?

That is the whole thing. We do not feed the *string* to the pattern; we feed the pattern *one character* and get back a new pattern — the pattern that whatever-comes-next must match. This "pattern for the rest" is called the **derivative** of the pattern with respect to `c`.

Notation for this chapter: ε is the empty-string pattern (`Eps`), ∅ is the match-nothing pattern (`Fail`), and we will write "the derivative of `r` by `c`". Let us hand-derive some tiny examples before any Idris.

**The pattern `a`, fed `'a'`.** The pattern wanted exactly one `a`, and it just got one. What remains to match? Nothing — the rest of the input must be empty. The derivative is ε.

**The pattern `a`, fed `'b'`.** The pattern wanted an `a` and got a `b`. This is not a "keep trying" situation; the match is dead, and no continuation of the input can revive it. The derivative is ∅. Notice how the two "nothings" from [the AST chapter](./06-regex-as-data.md) both just earned their keep: ε is a *successful* nothing-left, ∅ is a *failed* no-way-forward.

**The pattern `ab`, fed `'a'`.** The `a` at the front consumes the character, and what remains is everything after it: the derivative is `b`. A sequence derives its head.

**The pattern `a|b`, fed `'a'`.** A choice does not choose — it derives *both* branches and stays a choice. The left branch `a` becomes ε; the right branch `b` becomes ∅. The derivative is ε|∅. As a set of strings, that is just ε — the dead branch contributes nothing — but as a *tree*, the ∅ tags along. Hold that thought; it becomes important later in this chapter.

**The pattern `a*`, fed `'a'`.** Take this one slowly; the star is where the idea shows its teeth. `a*` means zero or more `a`s. If it consumed a character, then the "zero repetitions" option is gone — the star has *committed to at least one repetition*. That first repetition is an `a`, which just ate the character, leaving ε for that repetition — and after any repetition, the star is allowed to keep going. So what remains is: finish the current repetition (ε), then `a*` again. The derivative is ε`a*` — which matches exactly what `a*` matches. That is the right answer: after eating one `a`, the strings `a*` will still accept are... any number of further `a`s.

One repetition unrolled, star still running. No counters, no loops, no state machine — the pattern itself carries the progress of the match.

## Red: pinning the derivative down

From commit [c426464](https://github.com/ubugeeei-prod/lets-start-functional/commit/c42646445a905e9474eb980c07cc0f60fae5d951), in `regex/tests/src/Spec/Core.idr` — every hand-derivation above becomes a spec, starting with the leaves:

```idris
export
derivSpecs : List Spec
derivSpecs =
  [ shouldBe "Fail stays Fail, whatever we feed it"
      (deriv 'a' Fail) Fail
  , shouldBe "Eps has nothing left to give after any character"
      (deriv 'a' Eps) Fail
  , shouldBe "consuming the right literal leaves the empty string"
      (deriv 'a' (Lit 'a')) Eps
  , shouldBe "consuming the wrong literal fails"
      (deriv 'b' (Lit 'a')) Fail
  , shouldBe "a choice derives both branches"
      (deriv 'a' (Alt (Lit 'a') (Lit 'b')))
      (Alt Eps Fail)
  , shouldBe "a star unrolls one repetition and keeps going"
      (deriv 'a' (Star (Lit 'a')))
      (Cat Eps (Star (Lit 'a')))
```

Two of these we did not hand-derive, and both give `Fail`. Deriving `Fail` goes nowhere, naturally. But deriving `Eps` is also `Fail`: a pattern that *demanded* emptiness dies the moment a character shows up — there is no rest-of-the-string in which things work out.

The list closes with two specs about `Cat`, and the final one is the whole reason `nullable` exists:

```idris
  , shouldBe "a sequence derives its head first"
      (deriv 'a' (Cat (Lit 'a') (Lit 'b')))
      (Cat Eps (Lit 'b'))
  , shouldBe "a nullable head lets the character reach the tail too"
      (deriv 'b' (Cat (Star (Lit 'a')) (Lit 'b')))
      (Alt (Cat (Cat Fail (Star (Lit 'a'))) (Lit 'b')) Eps)
  ]
```

Consider `a*b` fed the character `'b'`. Who eats the `b`? Not necessarily the `a*` — because `a*` can match the empty string, it is entirely legal for the star to contribute *nothing* and let the character fall through to the `b` behind it. A nullable head means the character has two possible fates: consumed by the head, or — head standing aside — consumed by the tail. The derivative must keep both doors open, as an `Alt`.

Now squint at that expected value: `Alt (Cat (Cat Fail (Star (Lit 'a'))) (Lit 'b')) Eps`. The left branch starts with `Fail` — it is dead on arrival, pure structural junk (the star tried to eat a `'b'` and failed). The only living part is the lonely `Eps` on the right. The *meaning* is correct; the *tree* is littered with debris. We are writing this expectation deliberately, junk and all, because it is the honest output of the simplest possible implementation. Remember this ugly tree — a later chapter, [Smart Constructors](./10-smart-constructors.md), exists precisely to sweep it clean.

As always, red first:

```
2/3: Building Spec.Core (src/Spec/Core.idr)
Error: While processing right hand side of derivSpecs. Undefined name deriv.

Spec.Core:76:8--76:13
 76 |       (deriv 'b' (Cat (Star (Lit 'a')) (Lit 'b')))
             ^^^^^
```

## Green: eleven lines

Commit [dd4e896](https://github.com/ubugeeei-prod/lets-start-functional/commit/dd4e89670a231de6ba16b53b1a15236fb46180ec), in `regex/src/Regex/Core.idr`:

```idris
||| The Brzozowski derivative: `deriv c r` is the regex matching
||| exactly the strings `s` such that `r` matches `c :: s`.
|||
||| In plain words: "if `r` had to consume the character `c` first,
||| what would be left of it?" Matching a whole string is then just
||| deriving once per character — no backtracking, ever. This is the
||| reason our engine runs in a single left-to-right pass.
|||
||| The two interesting cases:
|||
||| - `Cat l r`: the character must be consumed by `l` — unless `l`
|||   can match the empty string, in which case it may also skip `l`
|||   and be consumed by `r`. That is exactly where `nullable` earns
|||   its keep.
||| - `Star r`: a star that consumes a character has committed to at
|||   least one repetition: derive one `r`, then the star continues.
public export
deriv : Char -> Regex -> Regex
deriv _ Fail      = Fail
deriv _ Eps       = Fail
deriv c (Lit x)   = if c == x then Eps else Fail
deriv c (Cat l r) =
  if nullable l
    then Alt (Cat (deriv c l) r) (deriv c r)
    else Cat (deriv c l) r
deriv c (Alt l r) = Alt (deriv c l) (deriv c r)
deriv c (Star r)  = Cat (deriv c r) (Star r)
```

Like `nullable`, it is one equation per constructor, structural recursion all the way down, and the totality checker signs off without a murmur. Most of the cases are hand-derivations from earlier in the chapter, transcribed. Two deserve a closer look.

**`Cat l r` — where `nullable` earns its keep.** The default story is simple: the head eats the character, the tail waits — `Cat (deriv c l) r`. But if `l` is nullable, there is a second legal story: `l` matches the empty string, steps aside, and the character reaches `r`. The result keeps both stories alive:

```idris
Alt (Cat (deriv c l) r)   -- the head ate the character...
    (deriv c r)           -- ...or the head vanished and the tail ate it
```

This is the moment the previous chapter promised. Without `nullable`, the derivative of a sequence cannot be defined — you would not know whether the character is allowed to reach the tail. One half of the algorithm was built so that this line could exist.

**`Star r` — unroll one repetition.** `Cat (deriv c r) (Star r)`: finish the repetition the character just started, then the star continues, fresh and unconsumed. The star never loops in place; it sheds one repetition into a `Cat` and carries on. Progress lives in the returned tree, not in any counter.

Note also what `Alt` does *not* do: it does not pick a branch. Both alternatives derive in lockstep, dead branches turning to `Fail` and living ones marching on. The pattern explores every alternative *simultaneously*, one character at a time. If you have met NFAs, this may feel familiar — but here there is no machine, no states, no bookkeeping. Just a function from tree to tree.

```sh
make test
```

```
  ok    true is true
  ...
  ok    a choice of two literals is not nullable
  ok    Fail stays Fail, whatever we feed it
  ok    Eps has nothing left to give after any character
  ok    consuming the right literal leaves the empty string
  ok    consuming the wrong literal fails
  ok    a choice derives both branches
  ok    a star unrolls one repetition and keeps going
  ok    a sequence derives its head first
  ok    a nullable head lets the character reach the tail too
27/27 passed
```

> [!NOTE]
> This construction is due to Janusz Brzozowski — "Derivatives of Regular Expressions", *Journal of the ACM*, 1964. It sat half-forgotten for decades while the world built regex engines out of automata and backtrackers, then was rediscovered by functional programmers who noticed that "a function from tree to tree" is exactly the kind of thing their languages are good at. The name *derivative* is borrowed from calculus by analogy — differentiating a pattern by a character, `d r / d c` — and the analogy runs surprisingly deep, but you never need the calculus to use it.

## What the language just did

Step back and look at what we wrote. The Brzozowski derivative is the hardest algorithmic idea in this book — the engine's entire intelligence, the thing that will let us match without ever backtracking. It fit in **eleven lines**, and those lines contain nothing we did not already have: pattern matching, one equation per constructor, structural recursion, an `if`.

That is not because the idea is shallow. It is because the representation is right. Once a regex is a tree of six shapes, "what is left after eating `c`" *has* to be six answers, and each answer is a small rearrangement of subtrees. Plain pattern matching and recursion — the two tools you have been using since the crash course — carried us all the way to the heart of the book. No new machinery was needed, and none will be needed for the payoff either.

## Summary

- The derivative asks: if the pattern had to eat character `c` first, what pattern is left? It maps a tree to a tree.
- Hand-derivable facts became specs: `a` by `'a'` is ε, `a` by `'b'` is ∅, `ab` by `'a'` is `b`, `a|b` by `'a'` is ε|∅, and `a*` by `'a'` unrolls one repetition into ε·`a*`.
- `Cat` is the subtle case: a nullable head may step aside and let the character reach the tail — this is why `nullable` had to come first.
- `Star` never loops: it sheds one repetition into a `Cat` and continues. Match progress lives in the returned tree.
- The raw derivative produces structurally junky trees (`Cat Fail ...`, dangling `Alt` branches); we pinned one in a spec on purpose, and [Smart Constructors](./10-smart-constructors.md) will clean it up.
- The idea is Brzozowski's (JACM, 1964); the implementation is eleven lines of pattern matching and structural recursion. The suite stands at 27/27.

We can now feed a pattern one character. A string is just characters in a row — so the [next chapter](./09-matches.md) folds `deriv` across the input, asks `nullable` at the end, and the engine is complete.
