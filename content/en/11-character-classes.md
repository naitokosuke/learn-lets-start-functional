---
title: Character Classes
description: Describe sets of characters symbolically, as ranges plus a negation flag, and let the compiler guide the AST refactor.
---

# Character Classes

Real patterns are full of `.`, `[a-z]` and `\d`, and our engine can only match one exact character at a time. This chapter builds symbolic character sets, then lets the compiler walk us through generalizing the AST.

## The problem with enumerating

A character class is a *set* of characters: `[a-z]` is the set of lowercase letters, `\d` is the set of digits, `.` is the set of, well, everything. The obvious representation is a list of members. For `[abc]` that is fine. For `.` it is hopeless: Unicode has over a million characters, and building a million-element list to represent "any character" is absurd. Negated classes like `[^"]` (everything *except* a quote) are even worse.

The functional instinct here is to stop storing the members and start storing the *description*. A set of characters can be described by:

- a list of inclusive ranges (`[a-z0-9_]` is three ranges and a one-character range), and
- a flag saying "actually, everything *not* in those ranges".

With that, `.` is "not in the empty list of ranges": two words, not a million entries. Membership is a question we answer by computation, not by lookup.

## Red: specs for a set type

The specs go in a new file, `regex/tests/src/Spec/Set.idr`. The basics first, building sets and asking about membership:

```idris
||| Specs for `Regex.Set` — symbolic sets of characters.
|||
||| A character class like `[a-z0-9]` or `[^"\\]` is a *set* of
||| characters. We describe sets symbolically (ranges + a negation
||| flag) instead of enumerating them, so `.` (any character) is as
||| cheap as `a`.
module Spec.Set

import Harness
import Regex.Set

export
setSpecs : List Spec
setSpecs =
  [ it "a single-character set contains its character"
      (member 'a' (single 'a'))
  , it "a single-character set contains nothing else"
      (not (member 'b' (single 'a')))
  , it "a range contains a character inside it"
      (member 'm' (range 'a' 'z'))
  , it "a range includes both of its endpoints"
      (member 'a' (range 'a' 'z') && member 'z' (range 'a' 'z'))
  , it "a range excludes characters outside it"
      (not (member 'A' (range 'a' 'z')))
  , it "oneOf builds a set from the characters of a string"
      (member 'b' (oneOf "abc") && not (member 'd' (oneOf "abc")))
```

Then the interesting ones: the wildcard, complement, and the named shorthands every regex user expects:

```idris
  , it "anyChar contains everything"
      (member 'x' anyChar && member '!' anyChar && member ' ' anyChar)
  , it "complement flips membership"
      (not (member 'a' (complement (single 'a')))
        && member 'b' (complement (single 'a')))
  , it "digit is 0-9"
      (member '7' digit && not (member 'x' digit))
  , it "word is letters, digits and underscore"
      (member 'k' word && member 'Z' word && member '4' word
        && member '_' word && not (member '-' word))
  , it "space is whitespace"
      (member ' ' space && member '\t' space && member '\n' space
        && not (member 'x' space))
  , it "sets compare structurally"
      (range 'a' 'z' == range 'a' 'z' && single 'a' /= single 'b')
  ]
```

Wire `setSpecs` into `Main.idr` and run:

```sh
make test
```

```
Error: Module Regex.Set not found

Spec.Set:10:1--10:17
 06 | ||| cheap as `a`.
 07 | module Spec.Set
 08 |
 09 | import Harness
 10 | import Regex.Set
      ^^^^^^^^^^^^^^^^
```

Red. This is commit [3664e98](https://github.com/ubugeeei-prod/lets-start-functional/commit/3664e980fcc4826957d9f6ea8159187c83d854c3).

## Green: CharSet

The whole module, `regex/src/Regex/Set.idr`, starts with the record:

```idris
||| A set of characters, described by ranges and a negation flag.
|||
||| - `MkSet False [('a','z')]` is the class `[a-z]`.
||| - `MkSet True  [('0','9')]` is the class `[^0-9]`.
||| - `MkSet True  []` negates the empty set: *every* character.
public export
record CharSet where
  constructor MkSet
  ||| When True, the set is "every character NOT in the ranges".
  negated : Bool
  ||| Inclusive ranges; a single character is a one-element range.
  ranges : List (Char, Char)

export
Show CharSet where
  show (MkSet neg rs) = "MkSet " ++ show neg ++ " " ++ show rs

export
Eq CharSet where
  MkSet n1 r1 == MkSet n2 r2 = n1 == n2 && r1 == r2
```

Membership is one line, and it is a lovely one:

```idris
||| Is `c` a member of the set?
|||
||| `any` does the real work: is `c` inside any of the ranges?
||| The negation flag then flips the answer — note the `/=`, which
||| on booleans is exactly "exclusive or".
public export
member : Char -> CharSet -> Bool
member c (MkSet neg rs) = neg /= any (\(lo, hi) => lo <= c && c <= hi) rs
```

Sit with that `/=` for a moment. We need "in a range" when the flag is off and "not in a range" when the flag is on. You could write an `if`. But look at the truth table of `/=` on booleans: it is true exactly when the two sides differ. `False /= inRanges` is `inRanges`; `True /= inRanges` is `not inRanges`. Not-equals *is* exclusive-or, and exclusive-or with a flag *is* conditional negation. Three characters replace a four-line conditional, and once you have seen the trick you cannot unsee it.

The constructors are one-liners:

```idris
||| The set containing exactly one character.
public export
single : Char -> CharSet
single c = MkSet False [(c, c)]

||| The set of characters from `lo` to `hi`, inclusive: `[lo-hi]`.
public export
range : Char -> Char -> CharSet
range lo hi = MkSet False [(lo, hi)]

||| The set of all characters appearing in a string: `[abc]`.
public export
oneOf : String -> CharSet
oneOf s = MkSet False (map (\c => (c, c)) (unpack s))

||| Every character — the wildcard `.` (we allow it to match
||| newlines; single-line mode is all we need).
public export
anyChar : CharSet
anyChar = MkSet True []

||| Everything *except* the members of the given set: `[^...]`.
|||
||| Because negation is just a flag, complement is one field flip —
||| no enumeration, no cost.
public export
complement : CharSet -> CharSet
complement (MkSet neg rs) = MkSet (not neg) rs
```

`complement` is the payoff of the symbolic representation in miniature. Complementing an enumerated set means materializing "everything else", a million-element nightmare. Complementing a *description* means flipping one boolean. The work moved from the data to the `member` function, where it costs nothing.

The shorthands are not functions at all, just plain values:

```idris
||| The digits `0-9` — the escape `\d`.
public export
digit : CharSet
digit = range '0' '9'

||| Letters, digits and underscore — the escape `\w`.
public export
word : CharSet
word = MkSet False [('a', 'z'), ('A', 'Z'), ('0', '9'), ('_', '_')]

||| Whitespace — the escape `\s`.
public export
space : CharSet
space = oneOf " \t\r\n"
```

```sh
make test
```

```
  ...
  ok    a single-character set contains its character
  ...
  ok    sets compare structurally
  ...
68/68 passed
```

This is commit [d308014](https://github.com/ubugeeei-prod/lets-start-functional/commit/d308014230c5b32ef497b5b1ded14b4df547cd8e).

## Red: character sets belong in the AST

`CharSet` exists, but the engine cannot use it: the AST's only way to consume a character is `Lit Char`, one exact character. Here is the plan, and it is a real refactor of the core type, our first. `Lit Char` becomes `Sym CharSet`: "match exactly one character drawn from this set". A literal is then just the special case of a one-character set, available through an ordinary function `lit`.

The specs first, in `Spec/Core.idr`:

```idris
||| The `Sym` constructor generalizes single-character literals to
||| whole character sets — `.`, `[a-z]`, `\d` and friends.
export
symSpecs : List Spec
symSpecs =
  [ it "a range matches any character inside it"
      (matches (Sym (range 'a' 'z')) "q")
  , it "a range rejects characters outside it"
      (not (matches (Sym (range 'a' 'z')) "Q"))
  , it "the wildcard matches any single character"
      (matches (Sym anyChar) "!")
  , it "the wildcard still needs exactly one character"
      (not (matches (Sym anyChar) "") && not (matches (Sym anyChar) "ab"))
  , it "\\d* matches a run of digits"
      (matches (Star (Sym digit)) "2026")
  , it "a negated class matches everything but its members"
      (matches (Star (Sym (complement (oneOf "\"")))) "no quotes here")
  , it "lit is still available as a one-character set"
      (matches (lit 'a') "a" && not (matches (lit 'a') "b"))
  ]
```

```sh
make test
```

```
Error: While processing right hand side of symSpecs. Undefined name lit.

Spec.Core:99:17--99:20
 95 |       (matches (Star (Sym digit)) "2026")
 96 |   , it "a negated class matches everything but its members"
 97 |       (matches (Star (Sym (complement (oneOf "\"")))) "no quotes here")
 98 |   , it "lit is still available as a one-character set"
 99 |       (matches (lit 'a') "a" && not (matches (lit 'a') "b"))
                      ^^^
Did you mean any of: Lit, or it?
```

Red: neither `Sym` nor `lit` exists. This is commit [18e8d25](https://github.com/ubugeeei-prod/lets-start-functional/commit/18e8d25353606318038a5e4e575579c824e2904f).

## Green: let the compiler drive

Here is the refactoring technique this chapter is really about: **change the data type first, then follow the errors.** In `Core.idr`, swap the constructor:

```idris
  ||| Matches exactly one character, drawn from a set: literals,
  ||| classes like `[a-z]`, and the wildcard `.` are all this one
  ||| constructor with different sets.
  Sym : CharSet -> Regex
```

Now build, and the compiler hands you the complete to-do list:

```
Error: While processing left hand side of showRegex. Undefined name Lit.
...
Error: While processing left hand side of ==. Undefined name Lit.
...
Error: While processing left hand side of nullable. Undefined name Lit.
...
Error: While processing left hand side of deriv. Undefined name Lit.
```

Every function that pattern-matched on `Lit` (`showRegex`, `Eq`'s `==`, `nullable`, `deriv`) stops compiling, with a line number. There is no fifth place hiding somewhere: pattern matching plus the `%default total` pledge means the compiler *must* account for every case of `Regex` in every function, so it cannot fail to notice a function we forgot. In most languages, "I changed a core type" is followed by days of grepping and prayer. Here it is followed by fixing four flagged sites, and when the file compiles, the refactor is done.

The fixes: `nullable (Sym _) = False` (a set still needs exactly one character), the `Show` and `Eq` cases delegate to `CharSet`'s own implementations, and `deriv` gets the only genuinely new logic in the whole refactor:

```idris
deriv c (Sym s)   = if member c s then Eps else Fail
```

Compare it with the old line, `if c == x then Eps else Fail`. Equality against one character became membership in a set. That is the entire semantic difference between literals and character classes, and it is one function call wide.

Finally, `Lit` lives on as an ordinary function:

```idris
||| The familiar way to ask for one specific character: a
||| one-character set. `Lit` from the earlier chapters lives on as
||| this ordinary function — the AST no longer needs a special case.
public export
lit : Char -> Regex
lit c = Sym (single c)
```

The same move as the smart constructors in the [previous chapter](./10-smart-constructors.md): what used to be a constructor is now a lowercase function that builds the general shape. The AST got *smaller* in spirit: still six constructors, but one of them now covers literals, classes, escapes and the wildcard alike.

There is one more cost to pay: every existing spec that said `Lit 'a'` must now say `lit 'a'` (and a couple of `show`-output expectations change, since a literal now prints as `Sym (MkSet False [('a', 'a')])`). This churn is mechanical, a find-and-replace, but it is worth pausing on *why* it happened. Our old specs reached past the public idea of "a literal" and touched the constructor itself, an implementation detail. The detail changed, and the tests paid for the intimacy. The new specs, written against `lit`, will survive any future change to how literals are represented. Losing the constructor from the tests is not a chore; it is the design getting better.

```sh
make test
```

```
  ...
  ok    a range matches any character inside it
  ...
  ok    lit is still available as a one-character set
  ...
75/75 passed
```

This is commit [4d2733d](https://github.com/ubugeeei-prod/lets-start-functional/commit/4d2733d8248bdd3bc0de79eee10ba0b79213e45f).

## Summary

- Enumerating a class's members cannot represent `.` or `[^"]`; describing sets symbolically (ranges plus a negation flag) makes every class, including "everything", a few words of data.
- `member` computes membership with `any` over the ranges, and `/=` on booleans is exclusive-or: conditional negation in three characters.
- `complement` flips one field; the symbolic representation makes negation free.
- `\d`, `\w`, `\s` are not features; they are named values of `CharSet`.
- The AST refactor `Lit Char` → `Sym CharSet` was compiler-guided: change the type, and totality checking enumerates every function needing a new case. `deriv`'s new case swaps `==` for `member`.
- `lit` remains as a plain function; the specs' switch from `Lit` to `lit` removed an implementation detail that had leaked into the tests.

Next we add `+`, `?`, `{n,m}` and string literals, and discover they cost nothing, in [Sugar Is Just Functions](./12-sugar.md).
