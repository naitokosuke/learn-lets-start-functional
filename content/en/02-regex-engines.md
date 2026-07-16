---
title: What Is a Regex Engine?
description: Regexes as a little language of string sets, the three families of engines, catastrophic backtracking in the wild, and the 1964 idea our engine is built on.
---

# What Is a Regex Engine?

The [previous chapter](./01-why-functional.md) promised a villain and a forgotten idea that defeats it. This chapter delivers both, and ends with the roadmap for the rest of the book.

## A little language for sets of strings

Strip away the folklore and a regular expression is a very small thing: a *notation for describing a set of strings*.

The pattern `abc` describes a set with one element: the string `"abc"`. The pattern `a|b` describes a set with two elements: `"a"` and `"b"`. The pattern `a*` describes an infinite set: `""`, `"a"`, `"aa"`, `"aaa"`, and so on forever.

Every operator in regex syntax is a way of building bigger sets out of smaller ones: concatenation glues them end to end, `|` unions them, `*` repeats them. (The name, if you are curious, comes from Stephen Kleene's work in the 1950s on "regular events"; the `*` is called the Kleene star after him. Regexes are older than almost everything else in your toolchain.)

When you ask "does this string match this pattern?", you are really asking "is this string a member of the set this pattern describes?" That is the entire job description of a regex engine: given a pattern and a string, answer one membership question.

This view (a pattern is a *description*, and matching is checking membership in what it describes) sounds like a philosophical nicety, but it is the engineering heart of this book. A description is just data, and in a functional language, functions over data structures are what we do all day. Hold that thought.

## Three families of engines

Deciding membership can be implemented in wildly different ways, and essentially every regex engine in existence belongs to one of three families.

**Backtracking engines** are what you almost certainly use every day: Python's `re`, JavaScript's `RegExp`, Java's `java.util.regex`, Ruby, Perl, PCRE. They treat the pattern as a little program and execute it recursively: try this alternative; if the rest of the match fails, come back and try the other one. Backtracking is easy to implement, extends naturally to non-regular features like backreferences, and is usually fast. *Usually.* The failure mode is the subject of the next section.

**Automata engines** compile the pattern into a finite state machine before matching, either ahead of time (a DFA) or on the fly (an NFA simulation). Google's RE2 and Rust's `regex` crate are the famous examples. They guarantee linear-time matching: no input can make them blow up, which is why they exist. RE2 was built specifically so that Google could accept regexes from untrusted users.

The price of the automata approach is a compilation phase, a state-machine construction with real engineering complexity, and giving up backreferences. (The industry is slowly conceding the trade is worth it: .NET, for instance, now ships an opt-in non-backtracking mode alongside its classic engine.)

**Derivative engines**, our pick, are the little-known third family. No compilation to a state machine, no backtracking. The pattern itself, as a data structure, is transformed one character at a time until the answer falls out. They share the automata family's linear-time guarantee while remaining, from top to bottom, a handful of recursive functions on a tree.

The idea dates to 1964, slept in the literature for four decades, and was shaken awake by functional programmers. A 2009 paper with the telling title "Regular-expression derivatives re-examined" found that in a functional language the technique is not just viable but *pleasant*. That is the rediscovery this book retraces. We will meet the idea properly in a moment.

## The villain: catastrophic backtracking

First, let us watch the mainstream design fail. Consider this pattern (the syntax `a?` means "one `a`, or nothing", and `{3}` means "three times"):

```
(a?){3}a{3}
```

which spelled out is `a?a?a?aaa`. Match it against the input `"aaa"`.

A backtracking engine works left to right, and every `a?` is a *choice point*: greedily try to consume an `a`, and remember this spot; if anything later fails, come back and try consuming nothing instead. The engine's entire memory is a stack of these places-to-retry. Trace what it does:

```
attempt 1: a? a? a? each eat one 'a'   -> "aaa" consumed, a{3} needs 3 more -> FAIL
attempt 2: first two eat, third skips  -> "aa" consumed,  a{3} needs 3, 1 left -> FAIL
attempt 3: 1st and 3rd eat, 2nd skips  -> "aa" consumed,  1 left  -> FAIL
attempt 4: only the first eats         -> "a" consumed,   2 left  -> FAIL
attempt 5: 2nd and 3rd eat, 1st skips  -> "aa" consumed,  1 left  -> FAIL
attempt 6: only the second eats        -> "a" consumed,   2 left  -> FAIL
attempt 7: only the third eats         -> "a" consumed,   2 left  -> FAIL
attempt 8: all three skip              -> "" consumed,    3 left  -> MATCH
```

Three independent two-way choices, so the engine explores up to 2 × 2 × 2 = 8 combinations, and the one that works is dead last in its search order. Notice also *what it keeps redoing*: attempts 2, 3, and 5 each consume two `a`s and fail for the identical reason, but the engine has no way to notice they are the same situation. It remembers where to retry, not what it has learned.

Now generalize. Match `(a?){n}a{n}` against a string of n `a`s and the engine faces 2^n combinations. At n = 10 that is a thousand attempts; nobody notices. At n = 20 it is a million; a request gets slow. At n = 30 it is a billion; your request handler is now a space heater. The input did not have to be large (thirty characters!), it just had to be *shaped* wrong.

This is catastrophic backtracking. And crucially, the pattern looks completely innocent. Nobody writes `(a?){30}a{30}` on purpose, but real patterns with nested or adjacent repetition (`(\s*.*)+`, say) hide the same explosive structure. They sail through code review because they *work*, flawlessly, on every input anyone thought to try.

The exponential cliff is only there for inputs shaped just so, which is to say: for the inputs an attacker sends. There is a name for exploiting this deliberately: ReDoS, regular expression denial of service.

## Two famous outages

Real incidents make the point better than any argument.

In July 2016, Stack Overflow went down for over half an hour. The trigger was a regex that trimmed whitespace from the ends of lines, applied to a post containing roughly twenty thousand consecutive whitespace characters. The backtracking on that one string amounted to about 200 million character comparisons (quadratic, not even exponential, but plenty), which pinned CPU on the rendering path; health checks timed out, and the load balancer took the site out of rotation.

In July 2019, Cloudflare, which fronts a noticeable fraction of the whole web, served global 502 errors for about half an hour. A newly deployed rule in their web application firewall contained a regex whose critical section amounted to `.*.*=.*`. On certain inputs it backtracked catastrophically; CPU on the machines that inspect every request spiked to 100% across their worldwide fleet, and traffic for millions of sites stopped until the rule was rolled back.

Both companies employ excellent engineers. Both regexes were reviewed. The problem is not carelessness. It is that "exponential on adversarially shaped input" is invisible in testing and brutal in production.

> [!NOTE]
> Backtracking engines are not *wrong*; they are a reasonable trade-off, and features like backreferences genuinely require something like backtracking. The lesson of these outages is narrower: an engine that can go exponential should never be handed input you do not control. Both companies moved the affected paths to engines with linear-time guarantees afterward.

## Our promise, stated precisely

The engine we build makes a guarantee, and it is worth stating carefully now so we can hold ourselves to it later.

**Matching makes one pass over the input, consuming one character per step, and never re-reads a character it has consumed.** For each character we perform one *derivative step* (defined in a moment) and throw the character away. There is no position to rewind to, because the algorithm does not remember positions at all. Time is therefore linear in the length of the input: n characters, n steps.

One honest nuance, because precision matters more than a slogan: *the cost of each step depends on the pattern.* A derivative step walks the pattern tree, so a bigger or hairier pattern means a slower step. What the guarantee rules out is the catastrophe: the per-step cost depends on the pattern you wrote, never on how much input has already been consumed or what the input looks like. The 2^n cliff is simply not in the design.

One reassurance about scope: the guarantee is not just for spartan patterns. Convenience syntax like `a?`, `+`, and `{n,m}` will be defined by *translation into* the handful of core operators the guarantee covers, so the promise automatically extends to every pattern you can write, including `(a?){30}a{30}`. Sugar cannot reintroduce the cliff, because sugar does not exist by the time matching runs.

Keeping the per-step cost small does take actual work (that is what the [Smart Constructors](./10-smart-constructors.md) chapter is about), and we will measure the whole promise against a real backtracker, on this exact pattern family, in [The Race](./19-the-race.md).

## The forgotten idea: Brzozowski derivatives

So how do you match without backtracking and without building a state machine? With the idea Janusz Brzozowski published in 1964: the *derivative* of a regular expression.

Here is the whole intuition. Take a pattern and feed it a single character. Ask: **"if the input starts with this character, what pattern must the *rest* of the input match?"** The answer is itself a pattern, called the *derivative*.

Concretely: the derivative of the pattern `abc` with respect to the character `a` is the pattern `bc`. Once you have seen an `a`, what remains to be seen is `bc`.

The derivative of `abc` with respect to `x` is a pattern that matches nothing at all: no string starting with `x` was ever going to match `abc`, and the derivative says so immediately.

The derivative of `a*` with respect to `a` is `a*` again: after one `a`, you are right back where you started, happy to accept more.

Matching, then, is almost embarrassingly simple: derive once per character, left to right. Watch the whole algorithm run on the pattern `abc` and the input `"abc"`:

```
start:            abc
feed 'a', derive: bc
feed 'b', derive: c
feed 'c', derive: (the empty-string pattern)
input exhausted:  does what's left accept the empty string?  yes -> MATCH
```

Each step consumes one character and yields a new pattern; the old pattern and the old character are never consulted again. When the input runs out, one final question is asked of whatever pattern remains: "would you accept the empty string?" That final question is a function called `nullable`, and it is so central it gets [its own chapter](./07-nullable.md).

Feed the same pattern the input `"abx"` instead, and at the `'x'` step the derivative collapses to the match-nothing pattern: failure is discovered instantly, with nothing to unwind.

Notice what is *not* in this description: no states, no transition tables, no compilation phase, no retry stack. Just two functions, "derive by one character" and "do you accept the empty string?", both defined by recursion on the structure of the pattern. A pattern is a tree; each case of the tree gets an equation; the algorithm dissolves into a page of pattern matching.

This is why derivatives are the FP-native choice. In a language built around recursive functions over algebraic data types, the 1964 algorithm is not something you *implement* so much as something you *transcribe*. (If you saw the one-line `matches` in the previous chapter: the fold is this loop, and now you know what it folds.)

If that all sounds too easy, good instinct. The pattern-as-tree can grow as you take derivatives, and controlling that growth is where the engineering lives. But those are refinements to a core that fits on a page, and you will have that core matching real strings within four chapters.

## The road from here

The book runs in four parts, and you are near the end of the first.

**Introduction** (you are here) gets your machine [set up](./03-setup.md), teaches you [enough Idris to read the rest](./04-idris-crash-course.md), and builds the [tiny test harness](./05-tdd.md) that every subsequent chapter leans on.

**The Core Engine** is the heart of the book: patterns as a [data type](./06-regex-as-data.md), the [nullable](./07-nullable.md) test, the [derivative](./08-derivatives.md) itself, and finally [matches](./09-matches.md), a complete, correct engine in remarkably few lines.

**Making It Practical** turns correct into usable: [smart constructors](./10-smart-constructors.md) to keep derivatives small, [character classes](./11-character-classes.md), the familiar [sugar](./12-sugar.md) like `+` and `{n,m}`, a [parser-combinator library built from scratch](./13-parser-combinators.md), a [parser for real pattern syntax](./14-pattern-syntax.md), and a clean [public API](./15-public-api.md).

**Idris Power-Ups** is the payoff for choosing this language: [interfaces and two monoids hiding in our engine](./16-interfaces.md), [printing patterns back out](./17-pretty-printing.md), a chapter where [a test becomes a machine-checked theorem](./18-proofs.md), the [head-to-head race](./19-the-race.md) against a backtracker we build ourselves, a [working lexer](./20-lexer.md) as capstone, and [where to go next](./21-whats-next.md).

## Summary

- A regex is a little language: each pattern denotes a set of strings, and matching asks one membership question.
- Engines come in three families: backtracking (Python, JavaScript, Java, PCRE; fast until they are exponential), automata (RE2, Rust's `regex`; linear-time via state machines), and derivatives (our pick; linear-time via recursive functions on the pattern itself).
- Catastrophic backtracking is combinatorial re-exploration of choice points: `(a?){3}a{3}` on `"aaa"` already explores 8 combinations, and `(a?){n}a{n}` explores 2^n. That is the mechanism behind ReDoS attacks and the 2016 Stack Overflow and 2019 Cloudflare outages.
- Our promise, precisely: one pass, one derivative step per character, consumed input never re-read; per-step cost depends on the pattern, never on how much input came before.
- A Brzozowski derivative (1964) answers "after this character, what pattern must the rest match?"; matching is a fold of derivatives followed by one `nullable` check, all recursive functions on a tree.
- The book runs in four parts: Introduction, The Core Engine, Making It Practical, and Idris Power-Ups.

Before any of that theory can become code, you need Idris 2 on your machine: that is [Setting Up](./03-setup.md).
