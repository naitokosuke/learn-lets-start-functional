---
title: What's Next
description: An inventory of everything you built, the functional ideas you now own, exercises from gentle to boss-level, and where to read on.
---

# What's Next

You started this book knowing how to program and knowing nothing about functional programming. Let us take stock of what you are walking away with — and where the road continues.

## Look what you built

A real regular expression engine, from an empty directory:

- a six-constructor AST that *is* the regex — [A Regex Is Data](./06-regex-as-data.md) — generalized to symbolic character sets in [Character Classes](./11-character-classes.md);
- a matcher made of two tiny functions, [`nullable`](./07-nullable.md) and [the derivative](./08-derivatives.md), folded into [a one-line engine](./09-matches.md) that walks the input exactly once;
- [smart constructors](./10-smart-constructors.md) that keep every derivative small — battle-hardened in [the race](./19-the-race.md) when the benchmark found the case they missed;
- the full convenience layer — `+`, `?`, `{n,m}`, string literals — as [plain functions](./12-sugar.md);
- a [parser-combinator library](./13-parser-combinators.md) built from scratch, a [pattern parser](./14-pattern-syntax.md) on top of it, and [a public API](./15-public-api.md) with honest error positions;
- a [pretty-printer](./17-pretty-printing.md) that provably-by-test inverts the parser, and [two monoids](./16-interfaces.md) that made the regex algebra official;
- a [machine-checked proof](./18-proofs.md) that `nullable` is sound and complete — for every regex, verified at compile time;
- a [benchmark](./19-the-race.md) against a backtracking rival you also built, and a [maximal-munch lexer](./20-lexer.md) that composes the whole engine into a compiler's front end.

All of it test-first, in a few hundred lines of Idris. And because the commit history *is* the tutorial, you can replay any step of it:

```sh
git clone https://github.com/ubugeeei-prod/lets-start-functional
cd lets-start-functional
git log --oneline --reverse
```

Pick any red commit, run the suite, watch it fail for exactly the reason its chapter said it would, then step forward one commit and watch it pass:

```sh
git checkout 40b08d8    # test(core,naive): alt must flatten and dedupe (red)
make -C regex test
```

```sh
git checkout fcdc16b    # feat(core): alt flattens the spine and dedupes (green)
make -C regex test
```

```
  ...
167/167 passed
```

## The functional ideas you now own

**Data first.** The single most transferable idea in the book: the regex is a *tree*, not a string and not a state machine, and every capability — matching, printing, deriving, lexing — is a function that walks it. You earned this in [A Regex Is Data](./06-regex-as-data.md) and cashed it in every chapter after. When a problem feels tangled, the functional move is to ask: what is the data?

**A pure core and an IO shell.** The engine never prints, reads, or throws; even the [test harness](./05-tdd.md) keeps `Spec` values pure and confines `IO` to one function at the edge. Purity is what made every function in this book trivially testable — call it, compare the value.

**Exhaustive pattern matching and totality as refactoring insurance.** When `Lit` became `Sym CharSet` in [Character Classes](./11-character-classes.md), the compiler produced a complete to-do list of every function that needed updating. Total functions over closed data types mean the machine, not your memory, tracks what a change touches.

**Higher-order functions as control flow.** `foldl (flip deriv)` *is* the matcher's main loop; the parser's `many` and `<|>` *are* iteration and branching; the backtracker's continuation `k` in [the race](./19-the-race.md) is "and then" as a value. Where other languages reach for loops and exceptions, you now reach for functions that take functions.

**Smart constructors and thinking algebraically.** `cat`, `alt`, and `star` enforce identities (`Eps`, `Fail`) and absorption at the only place terms get built — and [Interfaces and Two Monoids](./16-interfaces.md) revealed that this was monoid structure all along. Naming the algebra is not decoration; it is what told us `anyOf []` must be `Fail` before we ever wrote a test for it.

**Interfaces, including named implementations.** Contracts (`Show`, `Eq`, `Semigroup`), implementations as compiler-passed values, constraints as requests — plus the distinctly Idris answer to "which monoid is *the* monoid": have several, by name, chosen with `@{...}`.

**Strictness made visible.** Idris is strict, and twice that mattered: `recur` had to delay the parser's self-reference in [Parser Combinators](./13-parser-combinators.md), and the benchmark needed `Lazy` to keep the work from running before the clock started. Laziness is available, but it is *marked* — you always know which side of the fence a value sits on.

**Honesty annotations.** `%default total` as the baseline, a deliberate `covering` on the parser's recursive grammar, one `assert_smaller` in the lexer with a comment justifying it. The discipline is not "everything must be total"; it is that every exception is visible, local, and signed.

**Proofs as the far end of testing.** [Tests Become Theorems](./18-proofs.md) did not introduce a new activity — it extended the one you were already doing. A spec checks a claim on examples; a proof checks it on all inputs; the same pattern matching and recursion powers both. Dependent types are what let the test suite's ambition grow without bound.

## Exercises

Roughly in order of difficulty. The engine is yours now — break it and mend it.

1. **Anchors.**
   Add `^` and `$` to the pattern syntax. Our `match` is whole-string and `contains` wraps the pattern in `.*`, so think first about what anchors should *mean* here — this is as much a design exercise as a coding one.
2. **Leftmost search.**
   `contains` answers yes or no; write a search that returns *where* the match is. The lexer's `longest` — walk forward, remember the last accept — is a strong hint.
3. **Replace and split.**
   With positions in hand, `replace : Regex -> String -> String -> String` and `split : Regex -> String -> List String` are satisfying afternoons, and both are pure List problems once the search exists.
4. **Capture groups.**
   Hard, and worth it. Returning *what* each group matched pushes you toward tagged transitions — search for "PikeVM" or "tagged NFA" to see how industrial engines thread capture state through a linear-time walk without giving up the linearity.
5. **A real DFA.**
   Memoize `deriv`: the set of derivatives of a regex is finite once you normalize (as [the race](./19-the-race.md) taught us the hard way), so caching them builds a deterministic automaton ahead of time. The Owens–Reppy–Turon paper below is the guide.
6. **Unicode classes.**
   Our `CharSet` ranges already fit; add syntax like `\p{L}` backed by real category tables, and find out how much of "Unicode support" is data rather than code.
7. **Error positions in the combinators.**
   Our `compile` reports where parsing stopped; make the combinators themselves track positions, so every `Parser` can say where and why it failed. This touches the parser type — a good test of how well the abstraction contains change.
8. **Boss level: prove `deriv` correct.**
   State `Matches (deriv c r) cs` iff `Matches r (c :: cs)` and prove both directions. The `Star` case will demand more than structural induction — this is where well-founded recursion enters, and where you outgrow this book.

## Now go read Haskell

Here is a secret about what just happened: by learning Idris, you learned to read Haskell — the language most functional-programming literature is written in. The dialects are close. Where this book wrote

```idris
interface Semigroup ty where
  (<+>) : ty -> ty -> ty

[SeqSemigroup] Semigroup Regex where
  (<+>) = cat
```

a Haskell file says

```
class Semigroup a where
  (<>) :: a -> a -> a

instance Semigroup Regex where
  (<>) = cat
```

— one colon becomes two, `interface` becomes `class`, `implementation` becomes `instance`. And where Idris let us keep two monoids under names, Haskell wraps values in single-field types to give each algebra its own type:

```
newtype Sum     = Sum     Int
newtype Product = Product Int

instance Semigroup Sum     where Sum a     <> Sum b     = Sum (a + b)
instance Semigroup Product where Product a <> Product b = Product (a * b)
```

The phrasebook:

| Idris | Haskell |
|-------|---------|
| `interface` | `class` |
| `implementation` (anonymous) | `instance` |
| named implementations, `@{...}` | newtype wrappers (`Sum`, `Product`, ...) |
| `x : Type` | `x :: *` (older) / `x :: Type` (newer GHC) |
| totality checker | you're on your own |
| strict by default, `Lazy` opt-in | lazy by default, strictness opt-in |

The last row is the one to respect: Haskell's pervasive laziness has real consequences — space leaks, different performance reasoning — that this book never had to teach you. But the data declarations, the folds, the monoids, the type classes: you read all of that now. Open any Haskell paper or library and see for yourself.

## Reading list

- Janusz Brzozowski, **"Derivatives of Regular Expressions"** (Journal of the ACM, 1964). The origin of everything in our `Core` — including, as we found out the hard way, the normalization fix.
- Scott Owens, John Reppy and Aaron Turon, **"Regular-expression derivatives re-examined"** (Journal of Functional Programming, 2009). The modern treatment: character classes, normalization, DFA construction — essentially this book's engine, done by professionals.
- Russ Cox, **"Regular Expression Matching Can Be Simple And Fast"** and its sequels — [swtch.com/~rsc/regexp](https://swtch.com/~rsc/regexp/). The essays that made linear-time matching a cause; our benchmark's `(a?){n}a{n}` is his.
- Edwin Brady, **"Type-Driven Development with Idris"** (Manning). The natural next book: the language that carried you here, taught by its creator, with types leading the design instead of tests.
- The **Idris 2 documentation** at [idris-lang.org](https://www.idris-lang.org/) — reference material for everything we used and the many things we did not touch.
- And a hat-tip to **chibivue** ([book.chibivue.land](https://book.chibivue.land/)) — the build-it-small-and-test-first format of this book owes it an obvious debt.

## Farewell

Twenty-one chapters ago, "functional programming" may have sounded like a place other people lived.

Now you have a matcher whose main loop is a fold, an algebra with two monoids on one type, a theorem your compiler checks while it builds, and a lexer that inherited linearity without asking. None of it required a burrito.

Thank you for building along. If you find a bug, prove a theorem, or take an exercise somewhere fun, the repository at [github.com/ubugeeei-prod/lets-start-functional](https://github.com/ubugeeei-prod/lets-start-functional) welcomes issues and pull requests.

Go write something small, pure, and correct.
