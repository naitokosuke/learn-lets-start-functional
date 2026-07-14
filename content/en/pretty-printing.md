---
title: Printing Patterns Back
description: toPattern renders the AST back into pattern syntax — context-dependent escaping, precedence with one Nat, and a roundtrip property that made the parser change.
---

# Printing Patterns Back

The parser turns pattern strings into trees. This chapter builds its inverse: `toPattern : Regex -> String`, which turns trees back into pattern strings — and a property test that squeezes both functions at once.

## Why print a regex?

Three reasons, in ascending order of delight.

First, debugging. `Show Regex` is faithful but noisy — `show (cat (lit 'a') (lit 'b'))` produces `Cat (Sym (MkSet False [('a', 'a')])) (Sym (MkSet False [('b', 'b')]))`, which is nobody's idea of readable. `"ab"` is.

Second, error messages. A tool that manipulates regexes — simplifying them, combining them, deriving them — wants to *show its work* in the syntax users actually write.

Third, the delicious one: a printer that is genuinely the parser's inverse gives us a property test. Take a tree, print it, re-parse it — the same tree must come back. One spec line exercises every corner of both functions against each other.

The hard problem is **precedence**. The tree `Cat (Alt a b) c` must print as `(a|b)c`; print it naively as `a|bc` and you have described a different tree. Parentheses must appear exactly where the child binds more loosely than its surroundings — no more (noise), no less (wrong).

## Red: the printer, specified

Commit [114a177](https://github.com/ubugeeei-prod/lets-start-functional/commit/114a1772565ccf9bdabe3c24099150ed6052f252) adds [`regex/tests/src/Spec/Pretty.idr`](https://github.com/ubugeeei-prod/lets-start-functional/blob/main/regex/tests/src/Spec/Pretty.idr). The roundtrip property is a helper:

```idris
||| Compile, print, re-compile: the same tree should come back.
roundtrips : String -> Bool
roundtrips p =
  case compile p of
    Right r => compile (toPattern r) == Right r
    Left _  => False
```

And the specs — escaping, precedence, character sets, then the property:

```idris
export
prettySpecs : List Spec
prettySpecs =
  [ shouldBe "a literal prints as itself"
      (toPattern (lit 'a')) "a"
  , shouldBe "metacharacters come back escaped"
      (toPattern (lit '.')) "\\."
  , shouldBe "control characters come back by name"
      (toPattern (lit '\n')) "\\n"
  , shouldBe "star binds directly to an atom"
      (toPattern (Star (lit 'a'))) "a*"
  , shouldBe "star parenthesizes a compound"
      (toPattern (Star (Cat (lit 'a') (lit 'b')))) "(ab)*"
  , shouldBe "alternation parenthesizes under concatenation"
      (toPattern (Cat (lit 'a') (Alt (lit 'b') (lit 'c')))) "a(b|c)"
  , shouldBe "shorthand sets print as their escapes"
      (toPattern (Sym digit)) "\\d"
  , shouldBe "negated shorthands too"
      (toPattern (Sym (complement word))) "\\W"
  , shouldBe "the any-character set prints as the wildcard"
      (toPattern (Sym anyChar)) "."
  , shouldBe "classes print their ranges"
      (toPattern (Sym (MkSet False [('a', 'z'), ('0', '9')]))) "[a-z0-9]"
  , shouldBe "negated classes get their caret"
      (toPattern (Sym (complement (range 'a' 'z')))) "[^a-z]"
  , it "compiled patterns survive print-and-reparse"
      (all roundtrips
        ["gr[ae]y", "(a|b)*c", "colou?r", "a.c", "[^x]+", "\\d{2,4}"])
```

(The list continues with the monoid specs from the [previous chapter](./interfaces.md) — one commit, two chapters.) The suite is red at compile time:

```
Error: Module Regex.Pretty not found
```

## Green: escaping depends on where you stand

Commit [bd405ed](https://github.com/ubugeeei-prod/lets-start-functional/commit/bd405eda8e87a78a1716c306df0286a221d3ccd2) adds [`regex/src/Regex/Pretty.idr`](https://github.com/ubugeeei-prod/lets-start-functional/blob/main/regex/src/Regex/Pretty.idr). It starts with a subtlety most people never notice until they write a printer: which characters need escaping *depends on where you are standing*.

```idris
||| Escape one character for use outside a class.
escapeOutside : Char -> String
escapeOutside '\n' = "\\n"
escapeOutside '\t' = "\\t"
escapeOutside '\r' = "\\r"
escapeOutside c    = if isMeta c then "\\" ++ pack [c] else pack [c]

||| Escape one character for use inside a class.
escapeInside : Char -> String
escapeInside '\n' = "\\n"
escapeInside '\t' = "\\t"
escapeInside '\r' = "\\r"
escapeInside c    =
  if elem c (unpack "]\\-^") then "\\" ++ pack [c] else pack [c]
```

Outside a class, `(`, `*`, `|` and their friends are special; inside `[...]`, they are ordinary, but `]`, `-` and `^` suddenly matter. The `isMeta` predicate already existed in the parser — this commit simply marks it `public export` so the printer and parser cannot drift apart about what counts as special. One definition, two consumers.

## Green: sets prefer their short names

A `CharSet` could always print as `[...]` syntax, but nobody wants to read `[0-9]` when they wrote `\d`. So the renderer tries the short spellings first:

```idris
||| One class item: `a` or `a-z`.
rangeItem : (Char, Char) -> String
rangeItem (lo, hi) =
  if lo == hi
    then escapeInside lo
    else escapeInside lo ++ "-" ++ escapeInside hi

||| Render a character set, preferring the short spellings:
||| shorthands like `\d` and the wildcard `.` where they apply,
||| class syntax otherwise.
renderSet : CharSet -> String
renderSet s =
  if      s == anyChar          then "."
  else if s == digit            then "\\d"
  else if s == complement digit then "\\D"
  else if s == word             then "\\w"
  else if s == complement word  then "\\W"
  else if s == space            then "\\s"
  else if s == complement space then "\\S"
  else case s of
    MkSet False [(lo, hi)] =>
      if lo == hi
        then escapeOutside lo
        else "[" ++ rangeItem (lo, hi) ++ "]"
    MkSet neg rs =>
      "[" ++ (if neg then "^" else "")
          ++ concat (map rangeItem rs) ++ "]"
```

That cascade of equality tests works because `CharSet` is plain data with structural `Eq` — and because the parser builds these particular sets in exactly one shape each. `\d` in a pattern becomes `range '0' '9'`, so `range '0' '9'` prints back as `\d`. Data in canonical form is data you can recognize with `==`.

## Green: precedence is one Nat

Now the main event. Every renderer of nested syntax faces the parenthesis question, and the standard answer is beautifully small: pass down a number describing how tightly the *surroundings* bind, and wrap in parentheses exactly when the current node binds more loosely.

```idris
wrap : Bool -> String -> String
wrap True  body = "(" ++ body ++ ")"
wrap False body = body

||| Render at a given surrounding precedence.
render : (prec : Nat) -> Regex -> String
render _ Fail      = "∅"   -- Fail has no pattern syntax; see the book
render _ Eps       = ""
render _ (Sym s)   = renderSet s
render p (Cat l r) = wrap (p > 1) (render 2 l ++ render 1 r)
render p (Alt l r) = wrap (p > 0) (render 1 l ++ "|" ++ render 0 r)
render p (Star r)  = wrap (p > 2) (render 3 r ++ "*")

||| Render a regex as pattern syntax.
public export
toPattern : Regex -> String
toPattern = render 0
```

The levels are 0 = alternation, 1 = concatenation, 2 = postfix, 3 = atom. `Alt` produces a level-0 thing, so it wraps whenever the context demands anything tighter (`p > 0`) — that is the `a(b|c)` spec. `Star` produces a level-2 thing and asks its child for a level-3 atom, so `Star (Cat ...)` wraps its body: `(ab)*`.

## The asymmetry, and the conversation it forced

Look closely at the `Cat` line — it is not symmetric:

```idris
render p (Cat l r) = wrap (p > 1) (render 2 l ++ render 1 r)
```

The left child renders at level 2, the right child at level 1. Why? Because `Cat` *associates to the right* in our trees: the parser folds `abc` into `Cat a (Cat b c)`. A right child that is itself a `Cat` is not a deviation from the shape — it is the shape — so it may render at concatenation level, no parentheses. A *left* child that is a `Cat` would be a shape the parser never produces, and rendering it at level 2 duly fences it off. The same asymmetry appears on the `Alt` line, one level down. The renderer does not just know the grammar's precedence; it knows the parser's *associativity*.

And that knowledge caught something. While making the roundtrip spec pass, one shape refused to line up: concatenation folded to the right (`foldr cat Eps`, from [Parsing Pattern Syntax](./pattern-syntax.md)) — but alternation folded to the *left*. Nobody had noticed, because matching does not care which way `a|b|c` leans. A printer cares intensely. So the green commit changed the parser, in [`regex/src/Regex/Syntax.idr`](https://github.com/ubugeeei-prod/lets-start-functional/blob/main/regex/src/Regex/Syntax.idr):

```idris
  ||| Lowest precedence: sequences separated by `|`.
  ||| Folded to the right, like concatenation — a consistent shape
  ||| keeps the pretty-printer's roundtrip exact. (`alt x Fail` is
  ||| `x`, so the trailing `Fail` seed leaves no junk behind.)
  alternation : Parser Regex
  alternation = do
    first <- sequenceOf
    rest  <- many (char '|' *> sequenceOf)
    pure (foldr alt Fail (first :: rest))
```

where the last line used to read `pure (foldl alt first rest)`. Two functions that claim to be inverses must agree about tree shapes — not just about meaning — and it took a test that runs them nose to nose to force that conversation. This is the quiet payoff of the property spec: it does not merely check the printer; it audits every structural decision the parser ever made.

> [!WARNING]
> One honesty note. `Fail` renders as `∅`, and `∅` does not re-parse — there is no pattern syntax for "match nothing" (and none for shapes like a star directly under a star, either). So the roundtrip property is stated for *compiled* patterns: `compile` never produces `Fail` or the other syntaxless shapes, which is exactly why `compile (toPattern r) == Right r` can hold without exception for every tree that came from `compile`. Hand-built trees get a best-effort rendering, nothing more.

```sh
make test
```

```
  ...
  ok    a literal prints as itself
  ok    metacharacters come back escaped
  ok    control characters come back by name
  ok    star binds directly to an atom
  ok    star parenthesizes a compound
  ok    alternation parenthesizes under concatenation
  ok    shorthand sets print as their escapes
  ...
  ok    compiled patterns survive print-and-reparse
  ...
148/148 passed
```

## What the language just did for us

Nothing in this chapter needed new machinery — and that is the point worth savoring. The printer is a fold over the same six constructors as everything else; precedence is an ordinary `Nat` argument; the roundtrip property is a plain function returning `Bool`. When your regexes are data, "print them back" is just one more tree walk, and "the printer inverts the parser" is just one more thing a test can say.

## Summary

- `toPattern : Regex -> String` renders the AST back into pattern syntax — for debugging, for error messages, and for the roundtrip property `compile (toPattern r) == Right r`.
- Escaping is context-dependent: `escapeOutside` and `escapeInside` disagree about which characters are special, and both defer to the parser's own `isMeta`.
- `renderSet` prefers short spellings (`\d`, `.`) by structural equality — canonical data is recognizable data.
- Precedence is one `Nat` threaded through `render`; `wrap` inserts parentheses exactly when a node binds more loosely than its context.
- `Cat`'s children render at different levels because the tree is right-associated — and making the roundtrip exact forced the parser's alternation to switch from `foldl` to `foldr`. Inverse functions must agree about shapes, and the property test made them.
- `Fail` prints as `∅`, which has no syntax — the roundtrip is honest about its scope: compiled patterns only.

Every spec so far — including today's property — checked examples we thought to write down. [Tests Become Theorems](./proofs.md) checks all inputs at once, and the test runner is the type checker.
