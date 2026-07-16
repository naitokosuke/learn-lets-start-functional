---
title: "nullable: Matching Nothing"
description: "The engine's first question: does a regex match the empty string? One equation per constructor answers it."
---

# nullable: Matching Nothing

We have a [tree of data](./06-regex-as-data.md) that can be built, printed, and compared. Now the engine gets its first real capability, and it is a strange one: deciding whether a regex matches the empty string.

## Why this question, of all questions?

It sounds like trivia. Who matches empty strings on purpose?

Here is the secret: the matching algorithm we are building has exactly two moving parts, and this is one of them. The other part (arriving in the [next chapter](./08-derivatives.md)) consumes the input one character at a time, transforming the pattern as it goes. When the input runs out, one question remains: *is the pattern that is left happy to stop here?* And "happy to stop with no input left" is precisely "matches the empty string".

So this odd little predicate is not a warm-up exercise. It is half of the whole engine. We will call it `nullable`, the traditional name in the literature: a regex is *nullable* when the empty string is among the strings it matches.

We can already answer it by hand for the leaves. `Eps` matches the empty string: that is its entire job. `Lit 'a'` does not; it needs a real character. `Fail` matches nothing whatsoever, so certainly not `""`. The interesting cases are the three constructors that contain other regexes. Rather than reason it out in prose, let us pin every case down with specs.

## Red: the spec

From commit [2712951](https://github.com/ubugeeei-prod/lets-start-functional/commit/271295156419e42c3577eed84e1e0330058b93f5), appended to `regex/tests/src/Spec/Core.idr`. First the leaves and the star:

```idris
||| `nullable r` answers one question: does `r` match the empty string?
export
nullableSpecs : List Spec
nullableSpecs =
  [ shouldBe "Fail never matches, so not the empty string either"
      (nullable Fail) False
  , shouldBe "Eps matches exactly the empty string"
      (nullable Eps) True
  , shouldBe "a literal needs one character, empty is not enough"
      (nullable (Lit 'a')) False
  , shouldBe "a star matches zero repetitions, i.e. the empty string"
      (nullable (Star (Lit 'a'))) True
```

`Star` is a `True`, always: `a*` means *zero* or more `a`s, and zero repetitions is the empty string. Whatever is under the star does not even matter.

Then sequencing and choice, where the answer depends on the children:

```idris
  , shouldBe "a sequence is nullable only when both halves are"
      (nullable (Cat Eps (Star (Lit 'a')))) True
  , shouldBe "a sequence with a non-nullable half is not nullable"
      (nullable (Cat (Star (Lit 'a')) (Lit 'b'))) False
  , shouldBe "a choice is nullable when either branch is"
      (nullable (Alt (Lit 'a') Eps)) True
  , shouldBe "a choice of two literals is not nullable"
      (nullable (Alt (Lit 'a') (Lit 'b'))) False
  ]
```

Convince yourself of the two `Cat` specs before reading on. `Cat l r` matches `""` only if the string can split into an `l`-part and an `r`-part that are both empty, so *both* halves must be nullable. In the second spec, `a*b` can never match `""`, because that final `b` demands a character, no matter how generous the `a*` in front is.

For `Alt`, either branch matching `""` is enough: `Alt (Lit 'a') Eps` (an `a`, or nothing) is nullable; `a|b` is not.

Run the suite and we get the now-familiar shade of red, because `nullable` does not exist:

```
2/3: Building Spec.Core (src/Spec/Core.idr)
Error: While processing right hand side of nullableSpecs. Undefined name nullable.

Spec.Core:50:8--50:16
 50 |       (nullable (Alt (Lit 'a') (Lit 'b'))) False
             ^^^^^^^^
```

## Green: one equation per constructor

Commit [3b1516d](https://github.com/ubugeeei-prod/lets-start-functional/commit/3b1516ddb2ecf05f2ce671efee5257370a2c0bcf) adds this to `regex/src/Regex/Core.idr`:

```idris
||| Does this regex match the empty string?
|||
||| This tiny function is one half of the whole matching algorithm
||| (the other half is `deriv`). Read each line as a fact about the
||| empty string:
|||
||| - `Fail` matches nothing, so certainly not the empty string.
||| - `Eps` is *defined* as matching the empty string.
||| - A literal needs one real character.
||| - A sequence matches "" only if both halves can match "".
||| - A choice matches "" if either branch does.
||| - A star matches zero repetitions, which is exactly "".
|||
||| There is no algorithm here to memorize — the function is just the
||| definition of "matches the empty string", written case by case.
public export
nullable : Regex -> Bool
nullable Fail      = False
nullable Eps       = True
nullable (Lit _)   = False
nullable (Cat l r) = nullable l && nullable r
nullable (Alt l r) = nullable l || nullable r
nullable (Star _)  = True
```

Six lines, and there is no algorithm in them: nothing is searched or accumulated, and no state is threaded through. Each equation simply *is* the definition of "matches the empty string" for that shape of tree. `Cat` is `&&` because a sequence needs both halves to vanish; `Alt` is `||` because a choice needs only one branch to. You do not memorize this function: you read each line, nod, and move on.

This is what "a regex is data" buys us. Because the pattern is a tree with six known shapes, a question about the pattern becomes six small facts, one per shape. Most of the functions in this book will have exactly this texture.

```sh
make test
```

```
  ok    true is true
  ...
  ok    different shapes are not equal
  ok    Fail never matches, so not the empty string either
  ok    Eps matches exactly the empty string
  ok    a literal needs one character, empty is not enough
  ok    a star matches zero repetitions, i.e. the empty string
  ok    a sequence is nullable only when both halves are
  ok    a sequence with a non-nullable half is not nullable
  ok    a choice is nullable when either branch is
  ok    a choice of two literals is not nullable
19/19 passed
```

## The safety net: exhaustiveness and %default total

Now for what the language did quietly while we typed those six equations.

Remember the very first line of `Regex.Core`, back from the scaffold: `%default total`. It tells Idris that every function in the module must be *total*: defined for every possible input, and guaranteed to finish. For `nullable`, that promise splits in two.

First, **coverage**. There are exactly six ways to build a `Regex`, and `nullable` must handle all six. Suppose that during some future refactor we delete the `Star` case. The module simply stops compiling:

```
Error: nullable is not covering.

Regex.Core:48:1--64:25
 48 | ||| Does this regex match the empty string?
 ...

Missing cases:
    nullable (Star _)
```

The compiler does not just complain; it *names the missing case*. This is the safety net under everything that follows. Later in the book we will add constructors to `Regex` itself (character classes, in [their own chapter](./11-character-classes.md)), and the moment we do, every function that pattern-matches on `Regex` will fail to compile until it handles the new shape, each one pointing at exactly what is missing. In most languages, "I added a variant, now let me grep for every switch statement" is a prayer. Here it is a compile error with a to-do list attached.

Second, **termination**. `nullable` calls itself, so how does Idris know it is not going to recurse forever? Look at *what* it recurses on: `nullable (Cat l r)` calls `nullable l` and `nullable r`, and `l` and `r` are strict subtrees of the input. Every recursive call peels at least one constructor off. Trees are finite, so the recursion must bottom out at the leaves.

This pattern is called **structural recursion** (recursion where every call is on a piece of the input), and it is exactly what the totality checker wants to see. Write your recursion structurally and totality checking is free; you will rarely think about it again. Nearly every function in this book, including the entire matcher, is structurally recursive.

> [!TIP]
> When you write a function over an ADT, let the constructors drive: write one equation per constructor, put a hole (`?rhs`) on the right of each, and fill them in one at a time. The compiler tracks which cases remain. This is pattern matching as a workflow, not just a syntax.

## Summary

- `nullable r` answers one question: does `r` match the empty string? It looks like trivia but is one half of the entire matching algorithm; the other half arrives next chapter.
- The function is six equations, one per constructor, and there is no algorithm to memorize: each line is the *definition* of "matches empty" for that shape.
- `Cat` is `&&` (both halves must vanish); `Alt` is `||` (one branch is enough); `Star` is always `True` (zero repetitions).
- `%default total` makes exhaustiveness a compile-time guarantee: delete a case and the compiler names it (`Missing cases: nullable (Star _)`).
- Structural recursion (recursing only on subtrees) is what convinces the totality checker that a function terminates.
- The suite is at 19/19, all green.

Next comes the other half of the algorithm, and the heart of the whole book: [the derivative](./08-derivatives.md). What is left of a pattern after it eats one character?
