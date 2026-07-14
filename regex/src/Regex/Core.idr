||| The heart of the engine.
|||
||| This module will grow, test by test, into a complete regular
||| expression matcher based on Brzozowski derivatives.
|||
||| The big idea of this whole project: a regular expression is not a
||| string, and not a state machine — it is a *tree of data*. Every
||| operation we will ever need (matching included!) is a plain
||| function that walks this tree.
module Regex.Core

%default total

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

||| Does this regex match the empty string?
|||
||| This tiny function is one half of the whole matching algorithm
||| (the other half is `deriv`). Read each line as a fact about the
||| empty string:
|||
||| - `Fail` matches nothing, so certainly not the empty string.
||| - `Eps` is *defined* as matching the empty string.
||| - A literal needs one real character.
||| - A sequence matches "" only if both halves can match "".
||| - A choice matches "" if either branch does.
||| - A star matches zero repetitions, which is exactly "".
|||
||| There is no algorithm here to memorize — the function is just the
||| definition of "matches the empty string", written case by case.
public export
nullable : Regex -> Bool
nullable Fail      = False
nullable Eps       = True
nullable (Lit _)   = False
nullable (Cat l r) = nullable l && nullable r
nullable (Alt l r) = nullable l || nullable r
nullable (Star _)  = True

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

||| Regexes can be printed. `Show` is an *interface* (if you know
||| Haskell: a type class; if you know Rust: a trait) and this block
||| is our implementation of it for `Regex`.
export
Show Regex where
  show = showRegex

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
