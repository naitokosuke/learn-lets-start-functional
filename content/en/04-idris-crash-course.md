---
title: An Idris Crash Course
description: A REPL-driven tour of exactly as much Idris 2 as you need to read the rest of the book — functions, data, holes, totality, and a first sip of IO.
---

# An Idris Crash Course

You have Idris installed from [the last chapter](./03-setup.md); now you learn to speak it. This is not a language reference — it is the minimum Idris needed to read every chapter that follows, learned the way the rest of the book works: by typing things and watching what comes back.

Open a terminal, create an empty file called `Scratch.idr` containing just the line `module Scratch`, and load it into the REPL with `idris2 Scratch.idr`. The prompt becomes `Scratch> `. Everything below either goes in that file (reload with `:r` after editing) or gets typed at that prompt. Do type along — this chapter works about three times better with your fingers involved.

## Values have types, and you can always ask

The `:t` command tells you the type of anything, and it is the question you will ask most in your Idris career:

```
Scratch> :t 42
42 : Integer
Scratch> :t 3.14
3.14 : Double
Scratch> :t 'x'
fromChar 'x' : Char
```

Read `42 : Integer` as "42 has type Integer". (The `fromChar` noise is Idris showing that literals are overloadable; ignore it and read the type after the colon.) `Integer` is arbitrary-precision, like Python's int. `Double` is your familiar floating point. `Char` and `String` are what they look like.

One type will keep appearing that you may not have met: `Nat`, the natural numbers — whole numbers from zero up, *with no negatives*. Idris uses `Nat` wherever negative values would be nonsense: lengths, counts, indices. You can nudge a literal into a particular type with `the`:

```
Scratch> the Nat 3
3
Scratch> the Nat 3 - the Nat 5
Error: Can't find an implementation for Neg Nat.
```

Three minus five is not a natural number, and Idris refuses at compile time rather than wrapping around or going negative behind your back. This is your first taste of a design philosophy: make the type say what is actually true.

## Functions

Add this to `Scratch.idr` (then `:r` in the REPL to reload):

```idris
double : Integer -> Integer
double x = x + x
```

Two lines, and they are always these two lines: the *type signature* on its own line — `double` takes an `Integer` and returns an `Integer` — then the definition. No `return` keyword; the right-hand side of `=` *is* the result, because a function here is exactly the mathematical kind: same input, same output, nothing else happening on the side.

```
Scratch> double 21
42
```

Note the application syntax: `double 21`, no parentheses around arguments. Multi-argument functions just stack arrows. Here is the standard library's addition on `Nat`:

```
Scratch> :t plus
Prelude.plus : Nat -> Nat -> Nat
```

Read `Nat -> Nat -> Nat` as "takes a `Nat`, then takes a `Nat`, then gives a `Nat`". The arrows associate the way they read, and something delightful falls out: you can apply a two-argument function to *one* argument and get a function back.

```
Scratch> :t plus 1
plus 1 : Nat -> Nat
```

`plus 1` is a perfectly good value — the add-one function — ready to be passed around or applied later. This is called *currying* (every function secretly takes one argument at a time), and it is why the application syntax has no parentheses: `plus 1 2` is really `(plus 1) 2`. Partial application will be doing quiet, useful work all through this book.

## Pattern matching and recursion

Functional languages replace the `if`/`while` toolbox with something better: define a function by *cases on the shape of its input*. Here is the length of a list, from scratch:

```idris
length' : List a -> Nat
length' [] = 0
length' (first :: rest) = 1 + length' rest
```

Two equations, one per possible shape of list: the empty list `[]` has length zero, and a list built from a first element and a rest (`::` is pronounced "cons") has length one more than the rest. There is no loop — recursion on the structure does the walking. The lowercase `a` in `List a` means the function works on lists of *anything*; `a` is a type variable. (Rust folks: it is `Vec<T>`'s `T`, without the angle brackets.)

```
Scratch> length' [10, 20, 30]
3
```

This shape — one equation per constructor, recursion where the data recurses — is the single most important pattern in this book. The regex engine's core is exactly this, three times over.

## Making your own data

The `data` keyword introduces a new type by listing the ways to build one:

```idris
data Coin = Heads | Tails

flipCoin : Coin -> Coin
flipCoin Heads = Tails
flipCoin Tails = Heads
```

`Coin` is a brand-new type with exactly two values. `Heads` and `Tails` are called *constructors*, and pattern matching works on them just like on lists:

```
Scratch> flipCoin Heads
Tails
```

Constructors can carry data, and types can take parameters. Suppose we want "either a value, or nothing":

```idris
data Perhaps a = Nope | Yep a
```

A `Perhaps Integer` is either `Nope`, or `Yep 42` — a `Yep` wrapping an actual `Integer`. Now the reveal: you did not need to define this, because it is the single most-used data type in the language, under the name `Maybe`:

```
Scratch> :t Just
Prelude.Just : ty -> Maybe ty
```

`Maybe a` is either `Nothing` or `Just x` — and it is what Idris has instead of `null`. More on that shortly.

## Lists, and the three workhorses

You have seen list literals and `::`. They are the same thing:

```
Scratch> 1 :: 2 :: 3 :: []
[1, 2, 3]
```

Three functions do most of the list work you would write loops for elsewhere. `map` applies a function to every element, `filter` keeps the elements passing a test, and `foldr` combines all the elements with an operator:

```
Scratch> map (* 2) [1, 2, 3]
[2, 4, 6]
Scratch> filter (> 10) [4, 25, 7, 90]
[25, 90]
Scratch> foldr (+) 0 [1, 2, 3, 4]
10
```

The `(* 2)` and `(> 10)` are *operator sections* — partial application again, this time of an operator. `foldr (+) 0 [1, 2, 3, 4]` computes `1 + (2 + (3 + (4 + 0)))`: replace every cons with `+` and the final `[]` with `0`. Functions that take other functions as arguments are called *higher-order*, and passing behavior around like this is the everyday texture of functional code.

One string-specific fact you will need constantly: a `String` is not a `List Char`, but converting is two functions, `unpack` and `pack`:

```
Scratch> unpack "abc"
['a', 'b', 'c']
Scratch> pack ['f', 'u', 'n']
"fun"
```

Our regex engine consumes input character by character, so `unpack` will appear on page one of the real work.

## Records, let, and where

For data with named fields, records beat positional constructors:

```idris
record Point where
  constructor MkPoint
  x : Double
  y : Double
```

`MkPoint 3 4` builds one, and fields come out with dot syntax, `p.x` — yes, like every language you already know. Local names are introduced with `let ... in`:

```idris
distance : Point -> Point -> Double
distance p q =
  let dx = p.x - q.x
      dy = p.y - q.y
  in sqrt (dx * dx + dy * dy)
```

```
Scratch> distance (MkPoint 0 0) (MkPoint 3 4)
5.0
```

The alternative is `where`, which hangs helper definitions *below* the main equation — same idea, different reading order, and the helpers get their own type signatures:

```idris
average : List Double -> Double
average xs = total' / count
  where
    total' : Double
    total' = foldr (+) 0 xs
    count : Double
    count = cast (length xs)
```

Use `let` for small intermediate values, `where` for named helpers worth their own signature. The book uses both.

## Holes: programming as a conversation

Here is the feature that changes how it feels to write Idris. When you do not know what goes somewhere, *say so*, with a name starting with `?`:

```idris
swap : (a, b) -> (b, a)
swap (first, second) = ?whats_this
```

This *compiles*. The file loads. And now you can interrogate the hole:

```
Scratch> :t whats_this
 0 b : Type
 0 a : Type
   first : a
   second : b
------------------------------
whats_this : (b, a)
```

Read it like a detective's case board: below the line is what you owe — a value of type `(b, a)` — and above the line is everything you have: `first` of type `a` and `second` of type `b`. (The `0`s say the types themselves are not available at runtime; ignore that for now.) With the goal and the inventory laid out, the definition writes itself:

```idris
swap : (a, b) -> (b, a)
swap (first, second) = (second, first)
```

This is the workflow: write the type signature, put a hole on the right-hand side, ask the compiler what the situation is, refine, repeat. You sketch the shape of the solution and fill in the blanks *with the type checker as your collaborator*, rather than writing everything and then arguing about it. When the code in later chapters seems to appear fully formed, this is how it was actually written — signature first, holes in the middle. (Editor note: with idris2-lsp, hovering a hole shows this same report inline.)

## Maybe instead of null

What does Idris do when there might be no answer? It says so in the type. Here is "first character of a string", which the empty string breaks:

```idris
firstChar : String -> Maybe Char
firstChar str =
  case unpack str of
    []     => Nothing
    c :: _ => Just c
```

(`case ... of` is pattern matching mid-expression; the `_` is a wildcard for "don't care".)

```
Scratch> firstChar "idris"
Just 'i'
Scratch> firstChar ""
Nothing
```

The return type `Maybe Char` is an honest contract: you might not get a `Char`, and the compiler makes every caller handle the `Nothing` case before it can touch the value. There is no null, so there is no "forgot to check for null". The billion-dollar mistake is not fixed here — it is unrepresentable.

## Interfaces, glanced at

Try comparing two coins:

```
Scratch> Heads == Heads
Error: Can't find an implementation for Eq Coin.
```

`==` is not built-in magic — it belongs to an *interface* called `Eq`, and our `Coin` type never signed up. Signing up looks like this:

```idris
Eq Coin where
  Heads == Heads = True
  Tails == Tails = True
  _     == _     = False
```

```
Scratch> Heads == Heads
True
```

An interface names a capability (`Eq` is "can be compared with `==`", `Show` is "can be rendered as a `String` by `show`"), and an implementation provides it for one type. (Haskellers: these are type classes. Rustaceans: traits.) When a later chapter writes a constraint like `Show a => Eq a => ...` in a signature, it is saying "any type `a`, provided it can be printed and compared" — our test harness does exactly this, next chapter. Interfaces get a proper chapter of their own much later ([Interfaces and Two Monoids](./16-interfaces.md)); for now, recognizing them is enough.

## Totality: the compiler that demands honesty

Add this line near the top of `Scratch.idr`, right after the `module` line — the regex engine's core modules all carry it:

```idris
%default total
```

It asks Idris to check that every function is *total*: defined for every possible input, and guaranteed to finish. A total function is one you can trust like arithmetic — call it on anything, get an answer, always.

What does the checker actually catch? Two things. Missing cases: delete the `[]` equation from `length'` and the file stops compiling, because a caller could hand you an empty list and you would have no answer. And dubious recursion — put this in a file called `Bad.idr` and try `idris2 --check Bad.idr`:

```idris
module Bad

%default total

countdown : Nat -> List Nat
countdown n = n :: countdown (n `minus` 1)
```

```
Error: countdown is not total, possibly not terminating due to recursive path Bad.countdown

Bad:5:1--5:28
 1 | module Bad
 2 |
 3 | %default total
 4 |
 5 | countdown : Nat -> List Nat
     ^^^^^^^^^^^^^^^^^^^^^^^^^^^
```

The checker accepts recursion when some argument visibly shrinks toward a base case — `length'` recursing on `rest` is fine — but `countdown` never provably stops (`minus` bottoms out at zero and then stays there, so `countdown 0` calls `countdown 0` forever). The error is the compiler catching an infinite loop *before you run it*.

Idris recognizes three honesty levels, declared with keywords. A `total` function covers every input and terminates on all of them — the gold standard, and what `%default total` demands. A `covering` function promises every input matches *some* equation, but makes no termination promise — this is the honest label for things like a server loop, or code whose termination the checker cannot see. A `partial` function promises nothing at all — it may crash on some inputs — and every use of it is a place your program can die; Idris makes you say the word so the shame is visible. Nearly everything we write in this book will be `total`, and that fact becomes quietly load-bearing in [Tests Become Theorems](./18-proofs.md): a total function is one the type checker can *reason* about.

> [!NOTE]
> A fun consequence of totality being a language feature: `total` is a *reserved word*. Try naming a variable `total` and the parser stops you with `Keyword 'total' is not a valid start to a declaration`. This is why `average` above calls its helper `total'` (a trailing prime is the traditional dodge), and why the test harness we build next chapter counts passing tests in a variable named `passedCount` — its source contains the comment: "Fun fact: the summary variable is called `passedCount` because `total` — the obvious name — is a reserved keyword in Idris!"

## Five lines of IO

You saw in the setup chapter that `putStrLn "hello"` is a *description* of an action, not an action performed. Descriptions have a type — `IO ()` , "an action that, when run, produces nothing interesting" — and a compiled program runs whatever description is bound to the name `main`. Multiple actions are sequenced with `do`:

```idris
module Main

main : IO ()
main = do
  putStrLn "hello from Idris"
  putStrLn (show (2 + 2))
```

Save as `Hello.idr`, compile, run:

```sh
$ idris2 Hello.idr -o hello
$ ./build/exec/hello
hello from Idris
4
```

Read `do` as "then": do this, then this. That is genuinely all you need for now — our entire test suite will contain exactly one `do` block. There is something deeper going on with `do` (it works on much more than `IO`, and yes, this is the road that leads to the m-word), but this book does not explain it until the code *needs* it, which happens in [Parser Combinators](./13-parser-combinators.md). Until then: `do` means "then". Promise kept from chapter one — no burritos.

## Summary

- `:t` tells you the type of anything; `Integer`, `Double`, `Char`, `String` are what you expect, and `Nat` (no negatives) appears wherever counting happens.
- Functions are a signature line plus equations; application is whitespace, functions curry, and partial application (`plus 1`, `(* 2)`) is everyday currency.
- Data types are lists of constructors; functions are defined by one equation per constructor shape, with recursion following the data — the pattern the whole engine is built from.
- `map`, `filter`, and `foldr` replace most loops; `unpack`/`pack` convert between `String` and `List Char`; records give named fields with dot access; `let` and `where` name local things.
- Holes (`?name`) let you compile incomplete programs and ask the type checker what belongs in the gap — signature first, holes in the middle is how all the book's code gets written.
- `Maybe` replaces null with an honest type; interfaces like `Eq` and `Show` name capabilities per type; `%default total` makes the compiler verify every function answers every input and terminates — and `total` is a reserved word, as our test harness's `passedCount` variable can attest.
- `do` sequences `IO` actions and for now just means "then"; the deeper story waits until [Parser Combinators](./13-parser-combinators.md).

Now you can read Idris — time to write some, starting with the tool every later chapter stands on: [TDD and a Tiny Test Harness](./05-tdd.md).
