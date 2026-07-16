---
title: TDD and a Tiny Test Harness
description: Why test-first works even better in a typed language, and a complete test harness in seventy lines that debuts the pure-core, IO-shell principle.
---

# TDD and a Tiny Test Harness

This is the last chapter of the introduction, and the first where we write code that stays in the project. Everything the book builds from here on will be driven by tests, so first we need something to run them. Building it ourselves turns out to be the perfect first exercise.

## Test-first, in a language like this?

The rhythm of this book is classic test-driven development: write a test that fails (*red*), write the smallest code that makes it pass (*green*), repeat. If you have done TDD before, that is familiar. If not, the pitch is short: writing the test first forces you to decide *what the code should do* before deciding how, and afterwards the test stays behind as a guard.

A reasonable question: does a language with a strong type checker even need this? Doesn't the compiler already catch everything?

No, and the two safety nets catch different acrobats. The type checker verifies your code is *coherent*: every case handled, every type aligned, every recursion (thanks to `%default total`) terminating. It cannot know that the derivative of `a*` with respect to `a` should be `a*`: that is a fact about *regular expressions*, not about types, and only a test can pin it down. Conversely, a test suite samples a few points; the type checker proves shapes for *all* inputs. We want both nets, at full strength, all the time.

Better still, in a compiled language the two nets combine into one workflow with a pleasing property: **the compiler is the first test**. When a new spec references a function that does not exist yet, the suite does not run and fail; it fails to *compile*:

```
Error: While processing right hand side of astSpecs. Undefined name Cat.
```

That is not an obstacle to TDD; that *is* the red. A compile error is the most honest failing test there is (it fails before the program even starts), and in this book, most red phases begin exactly this way. Red means "the world does not satisfy this spec yet", and "the world does not even contain these names yet" qualifies with distinction.

So we need a test harness. We will not install one, partly to keep the project dependency-free (nothing but the compiler, as promised in [Setting Up](./03-setup.md)), but mostly because a test harness is a wonderful thing to build: small, useful, and secretly a functional-design lesson. Ours is a little over seventy lines, and here it is, top to bottom. It lives at [regex/tests/src/Harness.idr](https://github.com/ubugeeei-prod/lets-start-functional/blob/main/regex/tests/src/Harness.idr), and, worth noting, the file has not changed since the day it was committed. Seventy-three lines, finished on day one.

## A test is data

```idris
||| A tiny test harness — small enough to read in one sitting.
|||
||| There is no magic here: a test is just *data* (a `Spec` record),
||| and running the suite is just *a fold over a list*. Building the
||| harness ourselves is the first taste of a very functional idea:
||| keep the core pure, push effects (printing, exiting) to the edge.
module Harness

import System

%default total

||| The outcome of a single, already-evaluated test case.
|||
||| Note that a `Spec` holds a `Bool`, not a computation: by the time
||| you have a `Spec` in your hands, the test has already run. Pure
||| values are easy to store, count, filter, and print.
public export
record Spec where
  constructor MkSpec
  ||| Human-readable description of the expectation.
  description : String
  ||| Did the expectation hold?
  passed : Bool
  ||| Extra context, shown only when the expectation failed.
  details : String
```

(New notation: lines starting with `|||` are doc comments, attached to the declaration below them. `public export` makes `Spec` (constructor, fields and all) visible to other modules; plain `export`, coming up, exposes just a name.)

The design decision that shapes everything else is in the record: a `Spec` holds a `Bool`, not a function to call later. If you come from Jest or JUnit or pytest, a "test" is a callback registered with a framework, which decides when to invoke it, catches what it throws, and reports through machinery you cannot see. Here there is no framework and nothing to invoke. By the time a `Spec` exists, the interesting expression (`1 + 1 == 2`, or eventually `matches r "aaa"`) *has already been evaluated*, right where the spec was written. A test is not a computation to be managed; it is a result to be reported: description, verdict, details. Three fields of plain data.

Why is that safe? Because in a pure language, evaluation *is* running. An expression like `matches r "aaa"` cannot write files, hang on the network, or interfere with the spec next to it; evaluating it can produce nothing but a value. All the machinery that test frameworks build to corral effects (setup and teardown, isolation, execution order) has nothing to do here, because plain data needs no supervision.

## Two ways to make a Spec

```idris
||| Expect a boolean condition to hold.
|||
||| ```idris example
||| it "the empty list has length zero" (length [] == 0)
||| ```
export
it : String -> Bool -> Spec
it desc ok = MkSpec desc ok "expected the condition to hold"

||| Expect two values to be equal, reporting both sides when they differ.
|||
||| The constraints tell the whole story: we need `Eq` to compare the
||| values and `Show` to print them in the failure report.
|||
||| ```idris example
||| shouldBe "one plus one" (1 + 1) 2
||| ```
export
shouldBe : Show a => Eq a => String -> (actual : a) -> (expected : a) -> Spec
shouldBe desc actual expected =
  MkSpec desc (actual == expected)
    ("expected " ++ show expected ++ ", got " ++ show actual)
```

`it` wraps a bare boolean; `shouldBe` compares two values and (its whole reason to exist) pre-bakes a useful failure message quoting both sides.

Look at `shouldBe`'s signature with [crash-course](./04-idris-crash-course.md) eyes. It works for any type `a`, but not unconditionally. `Eq a` is required because the definition uses `==`, and `Show a` because the failure message uses `show`. The constraints are not boilerplate; they are the function's needs, stated in the type, checked by the compiler. Delete the `Show a =>` and the definition stops compiling, because there would be no way to print the values. (The `(actual : a)` syntax just names the arguments in the signature: documentation the type checker keeps honest.)

## Reporting is pure too

```idris
||| Render one spec as a report line. Pure: no printing happens here.
export
render : Spec -> String
render spec =
  if spec.passed
    then "  ok    " ++ spec.description
    else "  FAIL  " ++ spec.description ++ "\n        " ++ spec.details
```

The instinct from most languages is to write this as "print the pass line, or print the fail lines". `render` refuses: it *computes the string* and hands it back. Nothing is printed. This looks like a distinction without a difference until you try to test your test harness, or want the report sorted, filtered, or written to a file. A function returning a `String` composes with all of that for free, while a function that prints composes with nothing. Pure as far as possible, effects at the last possible moment.

## The one impure function

```idris
||| Run a whole suite: print every line, then a summary, and exit
||| with a non-zero code if anything failed.
|||
||| This is the only place in the harness where `IO` shows up.
|||
||| (Fun fact: the summary variable is called `passedCount` because
||| `total` — the obvious name — is a reserved keyword in Idris!)
export
covering
runSpecs : List Spec -> IO ()
runSpecs specs = do
  traverse_ (putStrLn . render) specs
  let passedCount = length (filter passed specs)
  putStrLn $ show passedCount ++ "/" ++ show (length specs) ++ " passed"
  when (passedCount /= length specs) exitFailure
```

The doc comment says it plainly: this is the only place in the harness where `IO` shows up, and apart from the `main` that calls it, the only place in the entire test suite we will ever write. Everything funnels down to one `do` block that prints lines, prints a summary, and sets the exit code (that `exitFailure` is why `make test` can fail a CI build; it is what `import System` was for).

The body is a tour of the crash course cashing in. `traverse_ (putStrLn . render) specs` reads "for each spec: render, then print": the `.` composes the two functions, and `traverse_` runs the resulting action over the list. `filter passed specs` is the quiet showstopper: `passed` is a record field, but a field is just a function `Spec -> Bool`, so it slots straight into `filter`. Counting the passes is `length` of a `filter`: the "pure values are easy to count, filter, and print" promise from the record's doc comment, redeemed. And per the fun fact, the count lives in `passedCount`, because the obvious name is a keyword. The small print: `runSpecs` is marked `covering`, one honesty notch below the `total` gold standard: a visible little flag that says the strict all-inputs-terminate discipline is a promise we make about the pure core, and this function is the edge of it.

This shape, *pure core, IO shell*, is the first genuinely functional design idea in the book, and the harness exists partly to let you meet it at a small scale. A file of pure data and pure functions, with one thin impure skin at the bottom. The regex engine will have the same silhouette, with an even thinner skin: none at all.

## Wiring it up

The harness needs an entry point. Here is `tests/src/Main.idr` as it was committed, three sanity specs and a runner (this file grows a couple of lines per chapter as spec modules appear; the harness itself never changes):

```idris
||| Entry point of the test suite.
|||
||| Every spec module exports a plain `List Spec`; the runner just
||| concatenates them. Adding a module to the suite is adding a list.
module Main

import Harness

||| Sanity checks for the harness itself — the very first red/green
||| cycle of this project was making these pass.
sanitySpecs : List Spec
sanitySpecs =
  [ it "true is true" True
  , shouldBe "one plus one is two" (1 + 1) 2
  , shouldBe "strings concatenate" ("fun" ++ "ctional") "functional"
  ]

main : IO ()
main = runSpecs sanitySpecs
```

Because specs are data, a spec *suite* is a `List Spec`, and composing suites is `++`. That is the whole extension model, and the doc comment is a standing invitation: for the rest of the book, adding a feature's tests means exporting one more list and concatenating it here.

The package file, `tests/tests.ipkg`, as promised in the [setup chapter](./03-setup.md):

```ipkg
package regex-tests
version = 0.1.0

depends = regex

sourcedir = "src"
main = Main
executable = tests

modules = Main
        , Harness
```

`depends = regex` points at the library (via the Makefile's `depends/` trick), and `main`/`executable` make this package a runnable program named `tests`. Meanwhile the library itself, at this point in history, is one module of ceremony. Here is `src/Regex/Core.idr` in its entirety:

```idris
||| The heart of the engine.
|||
||| This module will grow, test by test, into a complete regular
||| expression matcher based on Brzozowski derivatives.
module Regex.Core

%default total
```

A doc comment, a module declaration, and the totality pledge. Now run the thing:

```
$ make test
idris2 --build regex.ipkg
1/1: Building Regex.Core (src/Regex/Core.idr)
rm -rf tests/depends/regex-0.1.0
mkdir -p tests/depends/regex-0.1.0
cp -R build/ttc/* tests/depends/regex-0.1.0/
printf 'package regex\nversion = 0.1.0\n' > tests/depends/regex-0.1.0/regex.ipkg
idris2 --build tests/tests.ipkg
1/2: Building Harness (src/Harness.idr)
2/2: Building Main (src/Main.idr)
Now compiling the executable: tests
./tests/build/exec/tests
  ok    true is true
  ok    one plus one is two
  ok    strings concatenate
3/3 passed
```

`3/3 passed`: the harness works, verified by itself, which is as bootstrappy as this book gets. And for completeness, here is what it looks like when things go wrong (sabotage the second spec to expect `3` and rerun):

```
  ok    true is true
  FAIL  one plus one is two
        expected 3, got 2
  ok    strings concatenate
2/3 passed
make: *** [test] Error 1
```

There is `shouldBe`'s pre-baked message earning its keep, and `exitFailure` propagating up through `make`. You will not see many `FAIL` lines in this book, but only because each one gets fixed in the very next section.

## The rhythm, and where to watch it

From here to the end, the project's git history keeps a strict beat, two commits per step. First a commit that adds specs: its message ends in `(red)`, and at that commit `make test` fails, almost always as a compile error, because the specs name things that do not exist. Then a commit with the smallest implementation that satisfies them, ending in `(green)`, and at that commit the suite passes again. The history is never broken anywhere *except* exactly at the red commits, and there it is broken on purpose, as documentation of what each test actually demanded.

You can see the first full cycle waiting just past the scaffold: [the scaffold commit](https://github.com/ubugeeei-prod/lets-start-functional/commit/fd1795e068cc36e9d12604bea38b0bb03fa14cfb) that added everything in this chapter, then [`test(core): specs for the Regex AST (red)`](https://github.com/ubugeeei-prod/lets-start-functional/commit/51d326b5444518b66b8b9ed0b468352ff048a63e), then [`feat(core): the Regex AST — six constructors, Show, Eq (green)`](https://github.com/ubugeeei-prod/lets-start-functional/commit/832542c132ce21d2b7902207cc654ca9621f02fd). That `Undefined name Cat` error quoted at the top of this chapter? It is exactly what `make test` prints at that red commit: `Cat` is one of the six constructors the specs demand and the empty `Regex.Core` does not yet provide.

Which is the cue for the next chapter: the introduction is over, and it is time to answer this book's first real question. What, exactly, *is* a regular expression, as a piece of data?

## Summary

- The type checker and the test suite catch different things: coherence for all inputs versus meaning at chosen points; we run both at full strength.
- In a compiled language the compiler is the first test: a spec referencing undefined names fails at compile time, and that *is* a legitimate red.
- A `Spec` is already-evaluated data (description, verdict, details), safe because pure evaluation has no effects to supervise, so no framework is needed.
- `it` and `shouldBe` build specs; `shouldBe`'s `Show a => Eq a =>` constraints state exactly what it needs and nothing more.
- `render` computes strings without printing; `runSpecs` is the single `IO` function in the whole suite: the pure-core, IO-shell silhouette the engine will repeat.
- Suites are `List Spec`, composed with `++`; `make test` reports `3/3 passed` on the scaffold, and a failure prints both expected and actual, then fails the build.
- The repo's history alternates `(red)` spec commits and `(green)` implementation commits, the beat every remaining chapter marches to.

Time for the first real red: in [A Regex Is Data](./06-regex-as-data.md), the specs demand six constructors that do not exist yet, and the compiler obliges with a satisfying refusal.
