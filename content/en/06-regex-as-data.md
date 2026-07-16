---
title: A Regex Is Data
description: "The book's central idea: a regular expression is a tree of data, and everything we do to it is a plain function on that tree."
---

# A Regex Is Data

The introduction is behind us: Idris is installed, the crash course is done, and the [tiny test harness](./05-tdd.md) is waiting for something to test. Time to build the engine, starting with the single most important idea in this book.

## The idea

In every language you have used so far, a regular expression is a *string*. You write `"(a|b)*c"`, hand it to some library, and a black box does the rest. Maybe the box compiles it to a state machine, maybe it interprets it directly. Either way, you never see inside.

We are going to throw the box away. In this book, a regular expression is not a string and not a state machine. It is a **tree of data**, an ordinary value like a list or a record, and everything we will ever do to it (matching included!) is a plain function that walks that tree.

This is the functional programming move, and you will see it again and again: take the thing that other designs hide inside machinery, and represent it as honest, inspectable data. Once a regex is data, we can build it, print it, compare it, transform it, and, a few chapters from now, *prove things about it*.

So what does the tree look like? It turns out that six shapes of node are enough to express every classic regex. But before we write them down, we owe the harness a failing test.

## Red: describing a type that does not exist

Following the rhythm from [the TDD chapter](./05-tdd.md), we start by writing specs against the module we *wish* we had. Here is the whole first spec list, from commit [51d326b](https://github.com/ubugeeei-prod/lets-start-functional/commit/51d326b5444518b66b8b9ed0b468352ff048a63e), in `regex/tests/src/Spec/Core.idr`:

```idris
||| Specs for `Regex.Core` — the abstract syntax of regular expressions.
module Spec.Core

import Harness
import Regex.Core

||| The AST is just data: we can build it, print it, and compare it.
export
astSpecs : List Spec
astSpecs =
  [ shouldBe "show renders the match-nothing regex"
      (show Fail) "Fail"
  , shouldBe "show renders the empty-string regex"
      (show Eps) "Eps"
  , shouldBe "show renders a character literal"
      (show (Lit 'a')) "Lit 'a'"
  , shouldBe "show parenthesizes nested structure"
      (show (Cat (Lit 'a') (Star (Lit 'b'))))
      "Cat (Lit 'a') (Star (Lit 'b'))"
  , shouldBe "show renders alternation"
      (show (Alt Eps (Lit 'x')))
      "Alt Eps (Lit 'x')"
  , it "structurally equal regexes are equal"
      (Cat (Lit 'a') (Alt Eps (Lit 'b')) == Cat (Lit 'a') (Alt Eps (Lit 'b')))
  , it "different literals are not equal"
      (Lit 'a' /= Lit 'b')
  , it "different shapes are not equal"
      (Star (Lit 'a') /= Cat (Lit 'a') (Lit 'a'))
  ]
```

Read the specs as a wish list: we want values named `Fail`, `Eps`, `Lit`, `Cat`, `Alt`, `Star`, a `show` that renders them back as the code that builds them, and an `==` that compares them.

None of that exists yet (at this point `Regex.Core` contains nothing but its module header and a `%default total` directive), so `make test` does not even reach the test runner:

```
2/3: Building Spec.Core (src/Spec/Core.idr)
Error: While processing right hand side of astSpecs. Undefined name Cat.

Spec.Core:28:26--28:29
 28 |       (Star (Lit 'a') /= Cat (Lit 'a') (Lit 'a'))
                               ^^^
Did you mean any of: Cast, or Nat?
```

This is worth pausing on. In a dynamically typed language, "red" means a test *ran* and *failed*. In Idris, there is an earlier shade of red: **the code does not compile**. `Undefined name Cat` is the type checker telling us exactly which wish is unfulfilled. The compiler is the first test runner, and a compile error is a perfectly good failing test. Throughout this book, plenty of red steps will look exactly like this.

## Green: six constructors

Here is the answer, from commit [832542c](https://github.com/ubugeeei-prod/lets-start-functional/commit/832542c132ce21d2b7902207cc654ca9621f02fd), at the top of `regex/src/Regex/Core.idr`:

```idris
||| The abstract syntax of regular expressions.
|||
||| Six constructors are enough to express every classic regex:
|||
||| | Constructor | Regex syntax | Matches                              |
||| |-------------|--------------|--------------------------------------|
||| | `Fail`      | (none)       | nothing at all — the empty set       |
||| | `Eps`       | (empty)      | exactly the empty string             |
||| | `Lit c`     | `c`          | exactly the one-character string "c" |
||| | `Cat l r`   | `lr`         | an `l`-match followed by an `r`-match|
||| | `Alt l r`   | `l\|r`       | whatever `l` or `r` matches          |
||| | `Star r`    | `r*`         | zero or more `r`-matches in a row    |
|||
||| Everything else you know from regex — `+`, `?`, character classes,
||| `{n,m}` — is syntactic sugar that we will *compile down* to these
||| six later in the book.
public export
data Regex : Type where
  ||| Matches nothing at all: the empty *set* of strings (∅).
  ||| Do not confuse it with `Eps`, which matches the empty *string*.
  Fail : Regex
  ||| Matches exactly the empty string (ε).
  Eps : Regex
  ||| Matches exactly one specific character.
  Lit : Char -> Regex
  ||| Sequencing (concatenation): `Cat l r` matches a string that can
  ||| be split so that `l` matches the front and `r` matches the rest.
  Cat : Regex -> Regex -> Regex
  ||| Choice (alternation): matches anything either branch matches.
  Alt : Regex -> Regex -> Regex
  ||| Kleene star: zero or more repetitions, so `Star r` always
  ||| matches the empty string too.
  Star : Regex -> Regex
```

This is an algebraic data type, exactly like the ones from the [crash course](./04-idris-crash-course.md), just bigger and load-bearing. A `Regex` is one of six things, three of which contain smaller `Regex`es. That recursion is what makes it a tree.

Notice how much of the code is `|||` doc comments. That is deliberate, and it is a habit worth stealing: doc comments are written for the *next reader* of the code, which in a project like this is usually you in three weeks. Idris treats them as part of the program. Ask the REPL and it will serve them back:

```repl
Main> :doc Regex
data Regex.Core.Regex : Type
  The abstract syntax of regular expressions.

  Six constructors are enough to express every classic regex:
  ...
  Constructors:
    Fail : Regex
      Matches nothing at all: the empty *set* of strings (∅).
      Do not confuse it with `Eps`, which matches the empty *string*.
    Eps : Regex
      Matches exactly the empty string (ε).
  ...
```

Let us walk the six constructors with concrete examples.

- `Lit 'a'` matches the one-character string `"a"` and nothing else. It is the regex `a`.
- `Cat (Lit 'a') (Lit 'b')` matches `"ab"`: an `a`-match followed by a `b`-match. It is the regex `ab`.
- `Alt (Lit 'a') (Lit 'b')` matches `"a"` or `"b"`. It is the regex `a|b`.
- `Star (Lit 'a')` matches `""`, `"a"`, `"aa"`, ... It is the regex `a*`.

Bigger patterns are just bigger trees. The regex `(a|b)*c` becomes:

```idris
Cat (Star (Alt (Lit 'a') (Lit 'b'))) (Lit 'c')
```

Yes, that is noisier than `(a|b)*c`, for now. A [later chapter](./14-pattern-syntax.md) will parse the compact syntax into exactly these trees. The tree form is not the inconvenient version; it is the *real* one, and the string syntax is a front-end for it.

### Fail and Eps are not the same nothing

The two leaf constructors without arguments deserve their own moment, because confusing them is the classic beginner mistake in this corner of computer science.

- `Fail` is the empty **set** of strings. It matches *nothing*: not the empty string, not any string. If your pattern somewhere reduces to `Fail`, that branch of the match is dead. Its traditional symbol is ∅.
- `Eps` is the set containing exactly one string: the empty **string** `""`. It matches successfully, as long as there is nothing left to consume. Its traditional symbol is ε.

An analogy from types you already know: `Fail` is like a function that never returns; `Eps` is like a function that returns `void`, since returning nothing is still returning. One is absence of an answer; the other is an answer with nothing in it.

Keep that distinction in mind. The next two chapters build the entire matching algorithm on it.

## Teaching Idris to print a Regex

The specs demand `show (Lit 'a')` to be `"Lit 'a'"`, but Idris has no idea how to print a type we invented five minutes ago. We have to teach it, and the mechanism for that is an **interface**.

If you know Rust, an interface is a trait; if you know Haskell, a type class. It is also close to a Java or TypeScript interface, with one twist: the implementation lives *outside* the type, in its own block, so you can implement interfaces for types you did not define.

`Show` is the standard interface for "this type can be rendered as a string". First the workhorse functions, from the same commit:

```idris
mutual
  ||| Render a regex the way you would type its constructors in code.
  showRegex : Regex -> String
  showRegex Fail      = "Fail"
  showRegex Eps       = "Eps"
  showRegex (Lit c)   = "Lit " ++ show c
  showRegex (Cat l r) = "Cat " ++ showArg l ++ " " ++ showArg r
  showRegex (Alt l r) = "Alt " ++ showArg l ++ " " ++ showArg r
  showRegex (Star r)  = "Star " ++ showArg r

  ||| Constructor arguments need parentheses — except the ones that
  ||| have no arguments of their own.
  showArg : Regex -> String
  showArg Fail = "Fail"
  showArg Eps  = "Eps"
  showArg r    = "(" ++ showRegex r ++ ")"
```

Two functions that call each other, which is why they sit in a `mutual` block: Idris normally requires things to be defined before use, and `mutual` says "these definitions are one unit, check them together".

Why two functions at all? Parentheses. `Cat (Lit 'a') (Star (Lit 'b'))` must not print as `Cat Lit 'a' Star Lit 'b'`: that is not valid code, and it is ambiguous. So `showArg` wraps every *argument* in parens, except `Fail` and `Eps`, which have no arguments of their own and need none. The spec `"show parenthesizes nested structure"` pinned exactly this behavior down before we wrote it.

With the rendering done, the interface implementation is one line:

```idris
||| Regexes can be printed. `Show` is an *interface* (if you know
||| Haskell: a type class; if you know Rust: a trait) and this block
||| is our implementation of it for `Regex`.
export
Show Regex where
  show = showRegex
```

Read it as: "here is how `Regex` implements `Show`: its `show` is `showRegex`". From now on, every function in the ecosystem that says "give me anything `Show`-able" (including our harness's `shouldBe`) accepts a `Regex`.

## Teaching Idris to compare a Regex

Same story for equality. The `Eq` interface asks for `==`, and we define it structurally: two trees are equal when they have exactly the same shape with exactly the same characters at the leaves.

```idris
||| Structural equality: two regexes are equal when they are built
||| from exactly the same constructors in the same shape.
|||
||| Note this is equality of *syntax*, not of *meaning*:
||| `Alt (Lit 'a') (Lit 'a')` and `Lit 'a'` match the same strings
||| but are not `==`.
export
Eq Regex where
  Fail      == Fail      = True
  Eps       == Eps       = True
  Lit c     == Lit d     = c == d
  Cat l1 r1 == Cat l2 r2 = l1 == l2 && r1 == r2
  Alt l1 r1 == Alt l2 r2 = l1 == l2 && r1 == r2
  Star r1   == Star r2   = r1 == r2
  _         == _         = False
```

The matching cases recurse into the children; the final catch-all `_ == _ = False` handles every mixed pair, like `Eps == Fail`.

> [!WARNING]
> This is equality of **syntax**, not of **meaning**. `Alt (Lit 'a') (Lit 'a')` and `Lit 'a'` match exactly the same strings, but they are different trees, so they are not `==`. Deciding whether two regexes mean the same thing is a much deeper question. Structural equality is the cheap, honest thing our tests need: "did this function build the exact tree I expected?"

## Green, for real this time

The red commit already registered the new specs in `tests/src/Main.idr`: the runner's `main` became `runSpecs (sanitySpecs ++ astSpecs)`. As that file's doc comment puts it: every spec module exports a plain `List Spec`, so adding a module to the suite is just adding a list. Run it:

```sh
make test
```

```
  ok    true is true
  ok    one plus one is two
  ok    strings concatenate
  ok    show renders the match-nothing regex
  ok    show renders the empty-string regex
  ok    show renders a character literal
  ok    show parenthesizes nested structure
  ok    show renders alternation
  ok    structurally equal regexes are equal
  ok    different literals are not equal
  ok    different shapes are not equal
11/11 passed
```

Three sanity checks from the harness chapter, eight new specs, all green. The engine now has a heart; it just does not beat yet.

> [!NOTE]
> Take stock of what we did *not* write: no matching logic, no state machine, nothing clever. We declared six shapes of data and taught the language to print and compare them. In a functional language, this is not a warm-up before the real program: defining the data *is* the first half of the program.

## Summary

- A regex here is not a string or a state machine: it is a tree of plain data, and every operation on it will be an ordinary function.
- Six constructors express every classic regex: `Fail`, `Eps`, `Lit`, `Cat`, `Alt`, `Star`; everything else is sugar we will compile down later.
- `Fail` matches the empty *set* of strings (nothing at all); `Eps` matches the empty *string*. They are different nothings.
- In a typed language, a compile error like `Undefined name Cat` is the first shade of red: the type checker is the first test runner.
- Interfaces (`Show`, `Eq`) are Idris's traits/type classes: an implementation block teaches existing generic code to work with our new type.
- `==` on `Regex` is structural: equality of syntax, not meaning. `Alt (Lit 'a') (Lit 'a')` and `Lit 'a'` are not `==`.
- Doc comments (`|||`) are part of the program; `:doc Regex` in the REPL serves them to the next reader.

The tree can be built, printed, and compared, but it cannot match anything yet. The first question we will teach it to answer sounds like a strange one: [does it match the empty string?](./07-nullable.md)
