---
title: "The Race: Linear vs Backtracking"
description: We build the backtracking rival, race it against the derivative engine — and the first benchmark run kills the wrong contestant.
---

# The Race: Linear vs Backtracking

This book has spent nineteen chapters claiming that derivatives beat backtracking. Time to prove it with a stopwatch — and to tell you, honestly, what happened when we first tried. This chapter is a true story; the commits are its receipts.

## Act 1: build the rival

You cannot race alone. We need a backtracking matcher — a simplified version of how many mainstream regex engines work — and it must be *correct*, or the race is meaningless. So the first spec is not about speed at all: the rival must agree with our engine on everything.

Commit [98b6a61](https://github.com/ubugeeei-prod/lets-start-functional/commit/98b6a61c029070f1af24f53251b93692043bdf45) adds [`regex/tests/src/Spec/Naive.idr`](https://github.com/ubugeeei-prod/lets-start-functional/blob/main/regex/tests/src/Spec/Naive.idr):

```idris
||| Both engines, same verdict?
agree : String -> String -> Bool
agree pat input =
  case compile pat of
    Left _  => False
    Right r => naiveMatch r input == matches r input

export
naiveSpecs : List Spec
naiveSpecs =
  [ it "the backtracker agrees on literals"
      (agree "abc" "abc" && agree "abc" "abd" && agree "abc" "")
  , it "the backtracker agrees on choice"
      (agree "a|b" "a" && agree "a|b" "b" && agree "a|b" "c")
  , it "the backtracker agrees on stars"
      (agree "a*" "" && agree "a*" "aaaa" && agree "a*" "aab"
        && agree "(ab)*" "abab" && agree "(ab)*" "aba")
  , it "the backtracker agrees on classes and shorthands"
      (agree "[a-c]+" "cab" && agree "[a-c]+" "cad"
        && agree "\\d{2,4}" "123" && agree "\\d{2,4}" "12345")
  , it "the backtracker agrees on the tricky nullable-head cases"
      (agree "(a*)*b" "aaab" && agree "(a*)*b" "aaaa"
        && agree "(a|)(a|)b" "ab" && agree "(a|)(a|)b" "aab")
  , it "the backtracker agrees on a real-world shape"
      (agree "\\w+@\\w+\\.\\w+" "user@example.com"
        && agree "\\w+@\\w+\\.\\w+" "user@example")
  ]
```

Note the "tricky nullable-head cases" — patterns like `(a*)*b` whose subexpressions can match nothing are exactly where naive matchers get subtly wrong answers or fail to terminate. Red, as usual, arrives at compile time:

```
Error: Module Regex.Naive not found
```

Commit [6f62a9f](https://github.com/ubugeeei-prod/lets-start-functional/commit/6f62a9f894cb15031bf5b7a23eacd94160137c9a) supplies [`regex/src/Regex/Naive.idr`](https://github.com/ubugeeei-prod/lets-start-functional/blob/main/regex/src/Regex/Naive.idr):

```idris
||| The matcher we deliberately did NOT build: a backtracker.
|||
||| This is (a simplified version of) how many mainstream regex
||| engines work. To match `Alt l r`, try `l`; if the rest of the
||| match fails, rewind and try `r`. Every choice point is a fork,
||| and on adversarial patterns the forks multiply: `(a?){n}` gives
||| 2^n ways to slice a run of a's, and a failing match visits all
||| of them. That blow-up has a name — catastrophic backtracking —
||| and it has taken real services down (Cloudflare, 2019; Stack
||| Overflow, 2016).
|||
||| Meanwhile `Regex.Core.matches` walks the input once, whatever
||| the pattern. The benchmark in the book races the two.
module Regex.Naive

import Regex.Core
import Regex.Set

-- Backtracking recursion is not structural; `covering` is honest.
%default covering

||| The worker. `k` is the *continuation*: what the rest of the
||| match still expects. `go r cs k` means "match some prefix of
||| `cs` against `r`, then hand the leftovers to `k`".
|||
||| Continuations are the functional way to say "and then". Note
||| how `Alt` becomes `||` — try the left match wholesale, or start
||| over on the right — and how `Cat l r` chains: match `l`, and
||| the continuation of `l` is "now match `r`".
|||
||| The one wrinkle: `Star`. A star whose body can match the empty
||| string (think `(a|)*`) could "repeat" forever without eating
||| anything, so we only loop when the body actually consumed input
||| — that is the `length rest < length cs` guard.
go : Regex -> List Char -> (List Char -> Bool) -> Bool
go Fail      _         _ = False
go Eps       cs        k = k cs
go (Sym s)   []        _ = False
go (Sym s)   (c :: cs) k = member c s && k cs
go (Cat l r) cs        k = go l cs (\rest => go r rest k)
go (Alt l r) cs        k = go l cs k || go r cs k
go (Star r)  cs        k =
  k cs || go r cs (\rest =>
    if length rest < length cs
      then go (Star r) rest k
      else False)

||| Whole-string matching, by backtracking. Same specification as
||| `Regex.Core.matches`; very different running time.
|||
||| The final continuation answers the final question: after the
||| whole pattern has matched, is the input fully consumed?
public export
naiveMatch : Regex -> String -> Bool
naiveMatch r s = go r (unpack s) null
```

The style is **continuation-passing**: `k` — the continuation — is a function meaning "what the rest of the match still expects". Continuations are the functional "and then". A regex alone cannot answer "did I succeed?"; it can only answer "here is what I left behind — does the rest work out?". So `Cat l r` matches `l` and hands it the continuation "now match `r`, then do whatever we were going to do". `Alt` becomes the honest `||`: try the whole left future, and if that entire tree of possibilities fails, rewind and try the right. That one `||` line *is* backtracking — pretty to read, and quietly exponential. `Star`'s guard (`length rest < length cs`) refuses zero-width repetitions, which is why `(a|)*` terminates; and `%default covering` admits up front that this recursion is not structural. The final continuation in `naiveMatch` is `null`: when the pattern is done, the input must be too.

```sh
make test
```

```
  ...
  ok    the backtracker agrees on the tricky nullable-head cases
  ok    the backtracker agrees on a real-world shape
154/154 passed
```

## Act 2: the racetrack

The classic adversarial family — from Russ Cox's famous writeup — is `(a?){n}a{n}` matched against exactly `n` a's. Every `a?` must match nothing for the whole thing to succeed, but a backtracker has `2^n` ways to distribute the a's and, failing forward, visits essentially all of them. The bench harness, [`regex/bench/src/Main.idr`](https://github.com/ubugeeei-prod/lets-start-functional/blob/main/regex/bench/src/Main.idr):

```idris
||| `(a?){n}a{n}`, built directly with the sugar combinators.
evil : Nat -> Regex
evil n = cat (exactly n (opt (lit 'a'))) (exactly n (lit 'a'))

||| n a's.
input : Nat -> String
input n = pack (replicate n 'a')

||| A fixed, friendly pattern: (a|b)*c.
fixed : Regex
fixed = cat (star (alt (lit 'a') (lit 'b'))) (lit 'c')

||| n a's followed by a single c.
inputC : Nat -> String
inputC n = pack (replicate n 'a' ++ ['c'])

||| A duration in milliseconds.
ms : Clock Duration -> Double
ms c = cast (seconds c) * 1000 + cast (nanoseconds c) / 1000000

||| Time one boolean computation. The `Lazy` argument keeps the
||| work from happening before the clock starts.
covering
timed : String -> Lazy Bool -> IO ()
timed label act = do
  t0 <- clockTime Monotonic
  let result = force act
  t1 <- clockTime Monotonic
  putStrLn $ "  " ++ label ++ ": "
          ++ show (ms (timeDifference t1 t0)) ++ " ms"
          ++ "  (matched: " ++ show result ++ ")"

covering
race : Nat -> IO ()
race n = do
  putStrLn $ "n = " ++ show n
  timed "derivatives " (matches (evil n) (input n))
  timed "backtracking" (naiveMatch (evil n) (input n))

covering
main : IO ()
main = do
  putStrLn "(a?){n}a{n} against a^n — both engines"
  traverse_ race [10, 12, 14, 16, 18, 20]
  putStrLn ""
  putStrLn "fixed pattern (a|b)*c, growing input — derivatives only"
  traverse_ (\n => timed ("length = " ++ show (S n))
                         (matches fixed (inputC n)))
            [9999, 99999, 999999]
```

The race pits both engines against the adversarial family at growing `n`; the second section pins down "linear in the input" directly, by holding the pattern *fixed* and growing the input a thousandfold.

The one subtlety is `Lazy Bool`: without it, Idris would evaluate the match *before* calling `timed`, and we would be timing nothing. `force act` starts the actual work after the first clock read. A `bench` target joins the Makefile:

```
## Race the derivative engine against the backtracker.
bench: install
	rm -rf bench/depends
	cp -R tests/depends bench/depends
	idris2 --build bench/bench.ipkg
	./bench/build/exec/bench
```

> [!NOTE]
> If you are replaying commits: the rival was built right after the pretty-printer, but the benchmark itself was wired up *last* — after the proofs and the lexer chapters — which is why the suite count jumps from 154 to 167 within this chapter. The commit history keeps everyone honest, including us.

## Act 3: the twist

We typed `make bench`, sat back to watch the backtracker suffer, and got this:

```sh
make bench
```

```
Killed: 9
```

Not one line of results. The operating system killed the process — out of memory — and here is the twist: it never even reached the backtracker. The victim was **our** engine.

So we did what you do: diagnose. Derive `evil n` by hand for a few characters and watch the trees. Each `a?` that might-or-might-not consume the character splits the derivative into choices, and the choices arrive shaped like `Alt x (Alt y (Alt x ...))` — with *duplicates*. Our `alt` from [Smart Constructors](./smart-constructors.md) does check for duplicates, but shallowly: `if l == r then l else Alt l r` compares only the two immediate arguments. The duplicate `x` above hides one level down in the spine, where that check never looks. Junk survives one derivative step, breeds in the next, compounds every step after that — and memory dies before the clock prints anything.

The cure has been known since Brzozowski's original 1964 paper: **normalize choices**. Flatten the whole `Alt` spine into a list, remove duplicates wherever they sit, rebuild. We rediscovered a sixty-year-old lemma with `make bench`, which is somehow both humbling and exactly how it should feel.

First, the failure pinned down as specs — commit [40b08d8](https://github.com/ubugeeei-prod/lets-start-functional/commit/40b08d864e98f2cbabfc6fc3202e7ee16ae1bc19). Two new cases join `smartSpecs` in `Spec/Core.idr`:

```idris
  , shouldBe "alternatives flatten and drop duplicates"
      (alt (Alt (lit 'a') (lit 'b')) (Alt (lit 'b') (lit 'c')))
      (Alt (lit 'a') (Alt (lit 'b') (lit 'c')))
  , shouldBe "duplicates hiding on the right are found too"
      (alt (lit 'a') (Alt (lit 'b') (lit 'a')))
      (Alt (lit 'a') (lit 'b'))
```

And `Spec/Naive.idr` gains the pattern family plus a regression test that measures the cure directly:

```idris
||| The catastrophic pattern family `(a?){n}a{n}`.
evil : Nat -> Regex
evil n = cat (exactly n (opt (lit 'a'))) (exactly n (lit 'a'))

||| Derive `r` through a run of n a's.
run : Nat -> Regex -> Regex
run n r = foldl (flip deriv) r (replicate n 'a')
```

```idris
    -- The regression that made this chapter necessary: without
    -- flattening-and-deduplication in `alt`, the derivatives of
    -- (a?){n}a{n} grow without bound and eat all memory.
  , it "derivatives of the catastrophic pattern stay small"
      (size (run 32 (evil 32)) < 5000)
  , it "and the catastrophic pattern still matches correctly"
      (matches (evil 24) (pack (replicate 24 'a'))
        && not (matches (evil 24) (pack (replicate 23 'a'))))
```

This red fails to compile — `size` does not exist yet — and even once it does, the old `alt` cannot pass the flatten-and-dedupe specs. Commit [fcdc16b](https://github.com/ubugeeei-prod/lets-start-functional/commit/fcdc16b7a02a9b4cd000ef5828ad9a55b52cb3d5) delivers the fix in [`regex/src/Regex/Core.idr`](https://github.com/ubugeeei-prod/lets-start-functional/blob/main/regex/src/Regex/Core.idr):

```idris
||| Flatten an Alt-spine into the list of its alternatives.
||| `Fail` contributes nothing — it is the identity of choice.
altList : Regex -> List Regex
altList (Alt l r) = altList l ++ altList r
altList Fail      = []
altList r         = [r]

||| Rebuild a (deduplicated) list of alternatives into a regex.
rebuildAlt : List Regex -> Regex
rebuildAlt []        = Fail
rebuildAlt [r]       = r
rebuildAlt (r :: rs) = Alt r (rebuildAlt rs)

||| Choose between two regexes — but normalize while building.
|||
||| Naively, `alt` only needs to drop `Fail` branches and collapse
||| `alt r r` to `r`. That version worked — until the benchmark
||| chapter, where deriving `(a?){n}a{n}` grew choices like
||| `Alt x (Alt y (Alt x ...))`: the duplicate `x` hides deep in the
||| spine where a shallow equality check never sees it, and memory
||| runs out. So we normalize properly: flatten every choice into a
||| list, drop duplicates wherever they sit, and rebuild. Brzozowski
||| knew this in 1964; we rediscovered it with `make bench`.
public export
alt : Regex -> Regex -> Regex
alt l r = rebuildAlt (nub (altList l ++ altList r))
```

Plus the measuring stick (and an `import Data.List` for `nub`):

```idris
||| The number of constructors in a regex — the measuring stick for
||| claims like "derivatives stay small".
public export
size : Regex -> Nat
size Fail      = 1
size Eps       = 1
size (Sym _)   = 1
size (Cat l r) = S (size l + size r)
size (Alt l r) = S (size l + size r)
size (Star r)  = S (size r)
```

All the old `alt` behavior falls out as special cases: `Fail` branches vanish because `altList Fail = []`, and `alt r r` collapses because `nub` keeps one copy. The new power is that duplicates are caught at *any depth* in the spine. Note what did **not** change: `deriv`, `matches`, `nullable` — the engine's logic is untouched. The entire fix lives inside one smart constructor, which is precisely what smart constructors bought us: a single choke point where every `Alt` in the program gets built.

```sh
make test
```

```
  ...
  ok    alternatives flatten and drop duplicates
  ok    duplicates hiding on the right are found too
  ...
  ok    derivatives of the catastrophic pattern stay small
  ok    and the catastrophic pattern still matches correctly
  ...
167/167 passed
```

## Act 4: the race, run

With `alt` normalizing, `make bench` finally produces numbers. Here is a real run from the machine this book was written on (Apple Silicon, Idris 2 0.8.0, Chez Scheme backend):

```
(a?){n}a{n} against a^n — both engines
n = 10
  derivatives : 0.084 ms  (matched: True)
  backtracking: 0.079 ms  (matched: True)
n = 12
  derivatives : 0.272 ms  (matched: True)
  backtracking: 0.474 ms  (matched: True)
n = 14
  derivatives : 0.58 ms  (matched: True)
  backtracking: 1.306 ms  (matched: True)
n = 16
  derivatives : 0.763 ms  (matched: True)
  backtracking: 7.355 ms  (matched: True)
n = 18
  derivatives : 1.349 ms  (matched: True)
  backtracking: 23.989 ms  (matched: True)
n = 20
  derivatives : 2.416 ms  (matched: True)
  backtracking: 113.461 ms  (matched: True)
```

The exact figures depend on your machine; the *shape* does not, and the shape is the whole story. At `n = 10` the two engines are neck and neck. Then the backtracker roughly quadruples every time `n` grows by two — that is `2^n` wearing a stopwatch. Extrapolate a little: `n = 30` would take minutes, `n = 40` days. (An earlier version of this benchmark tried `n = 22`; we killed it after twelve minutes of CPU time.) The derivative engine answers the `n = 20` case in two milliseconds.

The second half of the run demonstrates the promise in this book's pitch directly — a *fixed* pattern against inputs a thousand times longer:

```
fixed pattern (a|b)*c, growing input — derivatives only
  length = 10000: 0.63 ms  (matched: True)
  length = 100000: 6.993 ms  (matched: True)
  length = 1000000: 102.043 ms  (matched: True)
```

Ten times the input, ten times the time: one derivative per character, a million characters in a tenth of a second. Linear means linear.

> [!NOTE]
> One honesty note before we take the trophy. "Linear in the input" is the unconditional promise; the *constant* per character depends on how large the derivatives of your particular pattern get, and our `nub`-based normalization does its bookkeeping naively. Against the adversarial `(a?){n}a{n}` family, growing the *pattern* gets expensive — `evil 100` takes seconds per match, because every step walks and deduplicates large alternative lists. Industrial derivative engines memoize their way out of this (next section); ours prefers to stay readable.

## What the industrial engines do

Our engine is now the same *species* as the serious linear-time matchers, minus the heavy optimization. Google's RE2 — built in response to exactly this backtracking pathology — compiles regexes to automata and builds a DFA lazily, caching states as the input reveals which ones matter. Memoized derivatives amount to the same trick: `deriv` computed once per (state, character) pair and cached *is* a lazy DFA, a construction studied carefully in the Owens–Reppy–Turon paper you will meet in [What's Next](./whats-next.md). Rust's `regex` crate follows the same philosophy with a toolbox of engines behind one guaranteed-linear interface. What none of them do is backtrack — because, as our stopwatch just confirmed, an engine that is fast on the average case but exponential in the corner is an outage waiting for its input.

## Summary

- The rival is a continuation-passing backtracker: `k` is "what the rest of the match expects", `Alt` becomes `||` (that line *is* the backtracking), `Cat` chains continuations, and `Star` guards against empty-body loops. Specs pin it to agree with the derivative engine everywhere.
- The benchmark races both on Russ Cox's `(a?){n}a{n}` family, with `Lazy` keeping the work inside the clock.
- The twist: the first `make bench` OOM'd *our* engine. The shallow duplicate check in `alt` misses duplicates deep in the `Alt` spine, and derivative junk compounds per character.
- The fix is Brzozowski's own normalization — flatten, dedupe (`nub`), rebuild — implemented entirely inside the `alt` smart constructor, with `size` guarding the property in the suite forever after.
- Industrial engines (RE2, rust/regex) are lazy-DFA cousins of memoized derivatives: same species, more chrome.

The engine is fast, proven where it counts, and battle-tested by its own benchmark. Time to build something *with* it: [Capstone: A Lexer](./lexer.md).
