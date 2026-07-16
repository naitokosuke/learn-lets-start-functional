---
title: Why Functional? Why Idris?
description: What went wrong with functional programming tutorials, why a regex engine is the perfect fix, and why Idris 2 is the right language to build it in.
---

# Why Functional? Why Idris?

This is the first chapter of the book, and it has one job: to convince you that the next few hundred pages are worth your time. No code to write yet — just the plan, and the reasons behind it.

## The reputation problem

Functional programming has a marketing problem, and it is largely self-inflicted.

If you have ever tried to learn it, you know the drill. You search for "what is a monad" and you get burritos. You get spacesuits, boxes, conveyor belts, and the infamous "a monad is just a monoid in the category of endofunctors, what's the problem?"

Or you open a proper tutorial, and it starts with the lambda calculus. Or with category theory. Or with a wall of algebraic laws to memorize before you have written a single line that does anything. Somewhere around page three you quietly close the tab and go back to writing code that actually ships.

The frustrating part is that none of that material is *wrong*. It is just upside down. It teaches the abstractions first and hopes the motivation shows up later. That is like teaching someone to drive by starting with a thermodynamics lecture: technically foundational, practically useless as a first step.

Here is the thing, though: you already know how to learn a programming paradigm, because you have done it before. You did not learn objects by studying the Liskov substitution principle. You built things, the language pushed back, and the concepts crystallized out of the work.

That is what we are going to do here. This book's thesis is simple: **build one small, real, useful thing, and let every language feature earn its keep along the way.** Nothing gets introduced because it is beautiful. Everything gets introduced because the code we are writing needs it *right now*, and you get to watch it pay for itself.

Since we are skipping the theory lecture, here is the working definition we will use instead, and it fits in a breath. Functional programming means building software out of *functions in the mathematical sense*: the output depends on the input and on nothing else, and calling a function changes nothing in the world.

Everything people praise about the style — testability, fearless refactoring, code you can understand by reading just the part in front of you — falls out of that one property. Everything that seems exotic about it is just the engineering required to hold onto that property while still doing useful work. That is the whole secret; the rest of the book is practice.

## The one small, real thing: a regex engine

The thing we will build is a regular expression engine. Not a toy that matches `a*b` and calls it a day — a real engine with character classes, escapes, counted repetition like `a{2,4}`, a parser for pattern syntax, a pretty-printer, and a public API you could actually use. All of it written test-first, in small steps, with every step preserved in version control.

Why a regex engine, of all things? Three reasons.

**First, you already know what it is supposed to do.** Everyone has written `\w+@\w+` at some point. We spend zero pages explaining the problem domain, which means every page goes toward the interesting part: how the solution works. When a test says that `colou?r` should match both spellings of the word, you do not need convincing.

**Second, a regex engine is functional programming's home turf.** The whole thing — the pattern representation, the matching algorithm, the parser, the printer — is pure functions transforming trees. There is no database, no network, no UI. The entire engine will have exactly one function that touches the outside world (the test runner that prints results), and everything else is a value going in and a value coming out. You could not design a better first project for learning to think in functions if you tried.

**Third, and best of all, there is a villain.** Mainstream regex engines — the ones in Python, JavaScript, Java, Ruby — share a design flaw called *catastrophic backtracking*: certain innocent-looking patterns take exponential time on certain inputs. This is not a theoretical curiosity; it has taken down Stack Overflow and Cloudflare, and it powers a whole category of denial-of-service attacks.

Our engine will be immune — not because we sprinkle timeouts or add a cleverness layer, but because the pure-functional algorithm at its heart *cannot* backtrack. It matches any pattern against any input in a single left-to-right pass. The villain, and exactly how we defeat it, gets the whole [next chapter](./02-regex-engines.md).

## A glimpse of the destination

To make this concrete, here is the entire matching algorithm of the finished engine — the actual code, from the actual repository, that decides whether a pattern matches a string:

```idris
matches : Regex -> String -> Bool
matches r s = nullable (foldl (flip deriv) r (unpack s))
```

One line. You are not supposed to be able to read it yet — that is what the book is for — but notice what you *can* see: no loops, no mutable match state, no retry stack. Two helper functions (`nullable` and `deriv`, each about six lines of code) and a fold over the characters of the input. By the end of [the core engine part](./09-matches.md) you will have written this line yourself, test-first, and it will feel almost obvious.

And here is the finished engine doing its job, in an interactive session against the repository as it stands today (once you have cloned it — command below — this is `make repl` in the `regex/` directory):

```
Main> :module Regex
Imported module Regex
Main> :exec printLn (test "colou?r" "my favourite colour")
Right True
Main> :exec printLn (test "gr[ae]y" "a green wall")
Right False
```

Real pattern syntax in, parsed by a parser we write ourselves, matched by the one-liner above. (The `Right` wrapper is the engine reporting that the pattern itself was well-formed — that story is told in [A Public API](./15-public-api.md).)

That is the pattern for the whole book: things that sound advanced — derivative-based matching, parser combinators, machine-checked proofs — turn out to be small, when the language fits the problem. The point of functional programming is not intellectual sophistication. It is that the code gets *shorter and more trustworthy at the same time*.

## Why Idris 2, and not Haskell?

Haskell is the name that comes up first in most "learn functional programming" advice, so picking Idris 2 deserves an explanation. Idris is a functional language in the Haskell family (the syntax will look strikingly familiar if you have seen Haskell), but it makes a few different choices, and for a *first* functional language, every one of those choices works in your favor.

**Idris is strict, not lazy.** In Haskell, expressions are evaluated lazily — not when you write them, but when something eventually demands their value. Laziness is powerful, but it means your intuition about *when* things run and *how much memory* they use has to be rebuilt from scratch, and that rebuild is one of Haskell's steepest learning curves.

Idris evaluates eagerly, like Python or JavaScript or Rust: arguments are computed, then the function runs. Your existing mental model of program performance transfers over almost unchanged. (Haskell folks: yes, this also means no lazy infinite lists by default — Idris has an explicit `Inf` type for that, and we will not need it.)

**There is usually one obvious way to do a thing.** Haskell is a gloriously large language with decades of extensions, several string types, and five libraries for everything. Idris 2 is small and recent enough that the path is well lit: one string type, one record syntax that comes with dot access like `point.x`, do-notation and interfaces built in from day one. Less time choosing, more time building.

**Holes make the compiler your pair programmer.** In Idris you can write a program with a hole in it — a name starting with `?` — and the compiler will tell you exactly what type of thing belongs there, along with everything you have available to build it.

Instead of writing code and then arguing with the type checker, you have a conversation with it. This workflow is the single best onboarding feature any typed language has, and it gets a starring role in the [crash course](./04-idris-crash-course.md).

**The totality checker teaches honesty.** Idris can check that a function is *total* — that it handles every possible input and always terminates. We will turn this on for the entire engine. It sounds academic; in practice it is a tireless reviewer that catches the `case` you forgot and the recursion that never ends, at compile time. It will also, in a late chapter, quietly turn out to be the thing that lets [tests become theorems](./18-proofs.md).

And here is the part that makes the choice safe: **everything you learn in this book maps one-to-one onto Haskell.** Algebraic data types, pattern matching, higher-order functions, interfaces (Haskell calls them type classes), monoids, functors, do-notation, parser combinators — all of it transfers directly, most of it with identical or near-identical syntax.

This is deliberate. You are not learning a boutique language instead of a mainstream one; you are learning the shared core of the entire ML-family through its friendliest member. The [final chapter](./21-whats-next.md) includes the explicit Idris-to-Haskell mapping for when you want to make the jump.

> [!NOTE]
> Idris is best known for *dependent types* — types that can depend on values, which let you prove things about your programs. We will get a genuine taste of that near the end of the book, but it is dessert, not the main course. You do not need to know what a dependent type is to read on, and we will not pretend you do.

## Do I need math for this?

No — and it is worth spelling out why, because this is the fear that theory-first teaching instilled.

You will meet a handful of words with mathematical pedigrees: *monoid* shows up when our engine turns out to contain two of them, and the matching algorithm is literally called a *derivative*. In every case the word arrives *after* the code — you will have already written and tested the thing, and the term is just its name. Learning that something you built has a fancy name is a much better feeling than being told to understand the name before you may build.

As for the m-word: this book contains no monad tutorial. Do-notation appears when we need to sequence effects, is used honestly, and gets its mechanics explained exactly when our own parser code makes the pattern visible — around [Parser Combinators](./13-parser-combinators.md). No burritos at any point.

## What we will not build

Honesty up front about scope. Our engine will match real patterns — classes, escapes, alternation, repetition, counted bounds — but it is a *matcher*, not a full PCRE clone. Specifically, we will not build:

- **Capture groups** — extracting the substring that a parenthesized group matched. Our parentheses group; they do not capture.
- **Anchors** like `^` and `$` — our `match` is whole-string by definition, and we will build a `contains` for searching within a string.
- **Backreferences** like `(\w+) \1` — these are not regular languages at all, and they are precisely the feature that forces engines into backtracking in the first place.
- **Unicode character categories** like `\p{Greek}` — our character sets handle ranges and negation, which is plenty for the ideas.
- **An optimizing DFA compiler** the way RE2 does it — our engine is linear-time without one, at a modest constant-factor cost.

None of these are omitted because they are impossible — most of them reappear as sketched exercises in [What's Next](./21-whats-next.md). They are omitted because every chapter in this book exists to teach you functional programming, and these features would be more regex than lesson.

## The commit history is the book

One more thing before we start, because it shapes how you read everything that follows.

This book was not written and then implemented. It was *committed*. Every chapter that builds code corresponds to real commits in the repository: first a commit that adds a failing test (labeled `(red)`), then a commit with the smallest implementation that makes it pass (labeled `(green)`). Here is an actual pair from the middle of the story, exactly as `git log` shows it:

```
d1a0950 test(core): specs for matches, end to end (red)
d8e7c5c feat(core): matches — fold deriv, then ask nullable (green)
```

The history is the tutorial. You can check out any commit and be standing at an exact sentence of this book, with the code in exactly the state the text describes.

Grab it now:

```sh
git clone https://github.com/ubugeeei-prod/lets-start-functional.git
```

The `regex/` directory is the engine; `content/` is the text you are reading. Run `git log --oneline` inside and you will see the whole story laid out, oldest commit at the bottom: scaffold, red, green, red, green, up through a working lexer built on top of our own engine.

You do not have to follow along by replaying commits — the book quotes all the code you need — but knowing the history is there changes the contract. Nothing in this book is pseudocode. Everything ran, and you can watch it run.

## Summary

- Functional programming's reputation problem comes from teaching abstractions before motivation; this book inverts that and lets features earn their keep inside one real project.
- That project is a regex engine: a familiar problem, a domain that is purely functions on trees, and a real-world villain (catastrophic backtracking) that our design defeats by construction.
- The finished engine's matching algorithm is one line of code over two small helpers — a preview of the book's recurring lesson that the right foundation makes hard things small.
- We use Idris 2 because it is strict (your performance intuition survives), small (one obvious way to do things), interactive (holes turn the compiler into a collaborator), and honest (the totality checker), while everything transfers one-to-one to Haskell — a mapping the final chapter makes explicit.
- We are building a matcher, not a PCRE clone: no capture groups, anchors, backreferences, Unicode categories, or DFA compilation — see [What's Next](./21-whats-next.md) for how those would go.
- The repository's commit history *is* the book: red test commits, green implementation commits, replayable at every step.

Next, we meet the villain properly: what a regex engine actually is, how the mainstream ones can blow up, and the forgotten 1964 idea that keeps ours safe — in [What Is a Regex Engine?](./02-regex-engines.md).
