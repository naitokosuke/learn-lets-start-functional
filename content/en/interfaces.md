---
title: Interfaces and Two Monoids
description: Naming the contract behind Show, Eq and the parser ladder — and making one type a monoid twice over, with Idris's named implementations.
---

# Interfaces and Two Monoids

You have been using interfaces since [A Regex Is Data](./regex-as-data.md) without ever stopping to name them. This chapter names them — and then runs straight into a question that Haskell answers with a workaround and Idris answers with a feature.

## You already use interfaces

Back in [A Regex Is Data](./regex-as-data.md), we wrote this and moved on:

```idris
export
Show Regex where
  show = showRegex
```

And the test harness from [TDD and a Tiny Test Harness](./tdd.md) has carried this signature the whole way:

```idris
shouldBe : Show a => Eq a => String -> (actual : a) -> (expected : a) -> Spec
```

In [Parser Combinators](./parser-combinators.md) we climbed the ladder from `Functor` to `Alternative`. So the machinery is old news. What we have never done is say precisely what the three moving parts are:

- An **interface** is a contract: a named set of function signatures that a type may promise to provide. `Show` says "I can be rendered as a `String`"; `Eq` says "I can be compared".
- An **implementation** is the fulfilment of that contract for one specific type — and here is the part worth internalizing: an implementation is a *value*, a record of functions that the compiler builds once and then passes around on your behalf. The `Show Regex where ...` block above constructs that value.
- A **constraint** like `Show a =>` in a signature is a *request* for one of those values. When you call `shouldBe "..." actual expected` at type `Regex`, the compiler silently finds the `Show Regex` and `Eq Regex` implementations and hands them in as extra arguments. No registry, no runtime lookup — it is resolved entirely at compile time.

If you know Haskell: interface = type class, implementation = instance. If you know Rust: trait and impl. The idea is the same; what Idris adds comes at the end of this chapter.

## The smallest useful contract: Semigroup

The prelude ships a contract so small it looks like a joke:

```idris
interface Semigroup ty where
  (<+>) : ty -> ty -> ty

interface Semigroup ty => Monoid ty where
  neutral : ty
```

(Doc comments trimmed; that is the whole shape.) A **semigroup** is a type with one binary operation, `<+>`, that must be *associative*: `a <+> (b <+> c)` equals `(a <+> b) <+> c`. A **monoid** is a semigroup with a *neutral element* — a value that changes nothing when combined from either side.

You know several monoids already. Strings, under concatenation, with `""` as neutral:

```
Main> "fun" <+> "ctional"
"functional"
Main> the String neutral
""
```

And numbers — twice. Addition is associative and `0` changes nothing; multiplication is associative and `1` changes nothing. Both are perfectly good monoids on the same type.

And *there* is the rub. An interface may have only one implementation per type — that is what lets the compiler pick it silently. So which one is THE `Monoid` on integers: sum or product? Haskell's answer is a workaround: wrap the number in a `newtype` (`Sum` or `Product`) so that each wrapper type gets its own instance, and unwrap afterwards. Idris's prelude answers by refusing to choose — there is no numeric `Monoid` at all — because Idris has a better tool: implementations can be **named**, and a type can have as many named implementations as it likes.

## A regex is a monoid twice over

Our `Regex` type has exactly the same two-monoid problem, and it is not a curiosity — it is the algebra we have been using all book:

| operation | combine | neutral | why neutral |
|-----------|---------|---------|-------------|
| sequencing | `cat` | `Eps` | the empty string before or after `r` is just `r` |
| choice | `alt` | `Fail` | an impossible branch can always be dropped |

We built both facts into the smart constructors back in [Smart Constructors](./smart-constructors.md): `cat Eps r = r` and `alt Fail r = r` are the identity laws, written as code. Time to make the algebra official — and to write it as a spec first.

## Red: asking for both monoids at once

The specs live at the tail of [`regex/tests/src/Spec/Pretty.idr`](https://github.com/ubugeeei-prod/lets-start-functional/blob/main/regex/tests/src/Spec/Pretty.idr), from commit [114a177](https://github.com/ubugeeei-prod/lets-start-functional/commit/114a1772565ccf9bdabe3c24099150ed6052f252):

```idris
    -- the two monoids
  , shouldBe "sequencing: <+> under SeqSemigroup is cat"
      ((<+>) @{SeqSemigroup} (lit 'a') (lit 'b'))
      (Cat (lit 'a') (lit 'b'))
  , shouldBe "sequencing: the neutral element is Eps"
      (the Regex (neutral @{SeqMonoid})) Eps
  , shouldBe "choice: <+> under AltSemigroup is alt"
      ((<+>) @{AltSemigroup} (lit 'a') (lit 'b'))
      (Alt (lit 'a') (lit 'b'))
  , shouldBe "choice: the neutral element is Fail"
      (the Regex (neutral @{AltMonoid})) Fail
  , it "anyOf folds a whole list of alternatives"
      (matches (anyOf [literal "let", literal "in", literal "where"]) "in")
  , shouldBe "anyOf of nothing is Fail — you can match none of no things"
      (anyOf []) Fail
  ]
```

Two pieces of new syntax, both doing exactly what they look like:

- `@{SeqSemigroup}` passes an implementation *explicitly, by name*. Where a constraint is usually filled in silently, `@{...}` says "use this one".
- `the Regex (...)` is the prelude's type ascription function — plain `neutral` could belong to any monoid on any type, so we pin it down.

The suite goes red before it can even run, because this spec module also imports a module that does not exist yet:

```
Error: Module Regex.Pretty not found
```

(And even with that module in place, `SeqSemigroup` and friends are undefined names — nothing in `Regex.Core` provides them yet.)

## Green: named implementations

From commit [bd405ed](https://github.com/ubugeeei-prod/lets-start-functional/commit/bd405eda8e87a78a1716c306df0286a221d3ccd2), in [`regex/src/Regex/Core.idr`](https://github.com/ubugeeei-prod/lets-start-functional/blob/main/regex/src/Regex/Core.idr):

```idris
-- ---------------------------------------------------------------
-- The regex algebra, made official.
--
-- Regex is a monoid twice over: once under sequencing (Eps is the
-- do-nothing element) and once under choice (Fail is the
-- nothing-to-choose element). In Haskell you would pick one and
-- wrap the other in a newtype; Idris lets both coexist as *named*
-- implementations, chosen explicitly with @{...}.
-- ---------------------------------------------------------------

public export
[SeqSemigroup] Semigroup Regex where
  (<+>) = cat

public export
[SeqMonoid] Monoid Regex using SeqSemigroup where
  neutral = Eps

public export
[AltSemigroup] Semigroup Regex where
  (<+>) = alt

public export
[AltMonoid] Monoid Regex using AltSemigroup where
  neutral = Fail

||| Accept any of the given regexes: fold with the choice monoid.
||| `anyOf []` is `Fail` — offered no options, match nothing.
public export
anyOf : List Regex -> Regex
anyOf = foldr alt Fail
```

Read the syntax:

- `[SeqSemigroup] Semigroup Regex where ...` is an ordinary implementation with a name in front. Because it is named, it does not become the default — it coexists peacefully with `AltSemigroup` on the same type.
- `Monoid` has `Semigroup` as a *parent* constraint, and with two candidate parents in scope the compiler cannot guess. `using SeqSemigroup` says which parent this monoid extends. `SeqMonoid`'s `<+>` is `cat`; `AltMonoid`'s is `alt`.
- There is deliberately no unnamed implementation. Writing `lit 'a' <+> lit 'b'` with no `@{...}` is a compile error — for a type that is two monoids at once, "just combine them" is a question, not an instruction, and Idris makes you answer it.

`anyOf` is the choice monoid put to work: fold a list of alternatives with `alt`, seeded with its neutral element. `anyOf []` returning `Fail` is not an edge case we handled — it falls out of the algebra. Offered no options, you can match none of them.

```sh
make test
```

```
  ...
  ok    sequencing: <+> under SeqSemigroup is cat
  ok    sequencing: the neutral element is Eps
  ok    choice: <+> under AltSemigroup is alt
  ok    choice: the neutral element is Fail
  ok    anyOf folds a whole list of alternatives
  ok    anyOf of nothing is Fail — you can match none of no things
148/148 passed
```

> [!NOTE]
> This commit pair delivers more than the monoids: the same spec file opens with tests for `toPattern`, a pretty-printer that turns a `Regex` back into pattern syntax, and the green commit implements it. That is a story of its own — it gets the [next chapter](./pretty-printing.md).

## The laws the compiler does not check

`Semigroup` and `Monoid` come with laws — associativity, and neutrality on both sides. Nothing in the code above proves them. The compiler checks that `(<+>)` and `neutral` have the right *types*; whether `cat` is actually associative is a promise we make, not one Idris verifies here.

Are the promises even true? Almost. `cat` and `alt` are associative and have their neutral elements *as matchers* — combining in either order accepts the same strings. On the nose, as trees, smart-constructor simplification can make the two sides of a law differ in shape for corner cases. Our specs spot-check the laws on examples, which is the same deal every Haskell typeclass lives with.

But notice what kind of sentence a law is: "for **all** `a`, `b`, `c`, ...". Our tests can only ever check finitely many examples of it. Idris can do better — it can state a for-all sentence as a *type* and check a proof of it at compile time. That is not a rhetorical flourish; it is [two chapters away](./proofs.md).

## What the language just did for us

A recap of this chapter's one big idea: in most languages with typeclass-style interfaces, "one implementation per type" is a hard rule, and the escape hatch is inventing wrapper types. In Idris, implementations are ordinary named values — so the rule softens to "one *default* per type, any number of named alternatives", and `@{name}` selects one at the call site with no wrapping and no unwrapping. The type stays `Regex` throughout; only the algebra changes hats.

## Summary

- An interface is a contract; an implementation is a compiler-built value that fulfils it; a constraint like `Show a =>` requests that value silently at compile time.
- A semigroup is a type with an associative `<+>`; a monoid adds a neutral element. Strings form one monoid; numbers form two — which is exactly the trouble.
- `Regex` is also a monoid twice over: sequencing with neutral `Eps`, and choice with neutral `Fail`.
- Idris's named implementations (`[SeqMonoid] Monoid Regex using SeqSemigroup where ...`) let both coexist on one type, selected explicitly with `@{SeqMonoid}` — where Haskell reaches for newtype wrappers.
- `anyOf = foldr alt Fail` is the choice monoid at work, and `anyOf [] = Fail` for free.
- Monoid laws are contracts the compiler does not check here — but Idris could, and in [Tests Become Theorems](./proofs.md) it will.

The same green commit also taught the engine to print its patterns back out — [Printing Patterns Back](./pretty-printing.md) tells that story.
