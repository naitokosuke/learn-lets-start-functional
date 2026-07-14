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

import Regex.Set

%default total

||| The abstract syntax of regular expressions.
|||
||| Six constructors are enough to express every classic regex:
|||
||| | Constructor | Regex syntax     | Matches                              |
||| |-------------|------------------|--------------------------------------|
||| | `Fail`      | (none)           | nothing at all — the empty set       |
||| | `Eps`       | (empty)          | exactly the empty string             |
||| | `Sym s`     | `c` `[a-z]` `.`  | any one character from the set `s`   |
||| | `Cat l r`   | `lr`             | an `l`-match followed by an `r`-match|
||| | `Alt l r`   | `l\|r`           | whatever `l` or `r` matches          |
||| | `Star r`    | `r*`             | zero or more `r`-matches in a row    |
|||
||| Everything else you know from regex — `+`, `?`, `{n,m}` — is
||| syntactic sugar that we will *compile down* to these six later
||| in the book.
public export
data Regex : Type where
  ||| Matches nothing at all: the empty *set* of strings (∅).
  ||| Do not confuse it with `Eps`, which matches the empty *string*.
  Fail : Regex
  ||| Matches exactly the empty string (ε).
  Eps : Regex
  ||| Matches exactly one character, drawn from a set: literals,
  ||| classes like `[a-z]`, and the wildcard `.` are all this one
  ||| constructor with different sets.
  Sym : CharSet -> Regex
  ||| Sequencing (concatenation): `Cat l r` matches a string that can
  ||| be split so that `l` matches the front and `r` matches the rest.
  Cat : Regex -> Regex -> Regex
  ||| Choice (alternation): matches anything either branch matches.
  Alt : Regex -> Regex -> Regex
  ||| Kleene star: zero or more repetitions, so `Star r` always
  ||| matches the empty string too.
  Star : Regex -> Regex

mutual
  ||| Render a regex the way you would type its constructors in code.
  showRegex : Regex -> String
  showRegex Fail      = "Fail"
  showRegex Eps       = "Eps"
  showRegex (Sym s)   = "Sym (" ++ show s ++ ")"
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
  Sym s1    == Sym s2    = s1 == s2
  Cat l1 r1 == Cat l2 r2 = l1 == l2 && r1 == r2
  Alt l1 r1 == Alt l2 r2 = l1 == l2 && r1 == r2
  Star r1   == Star r2   = r1 == r2
  _         == _         = False

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
nullable (Sym _)   = False
nullable (Cat l r) = nullable l && nullable r
nullable (Alt l r) = nullable l || nullable r
nullable (Star _)  = True

||| Sequence two regexes — but simplify the obvious cases.
|||
||| These "smart constructors" use two bits of regex algebra:
|||
||| - `Fail` is *absorbing*: nothing followed by anything is nothing.
||| - `Eps` is the *identity*: the empty string followed by `r` is `r`.
|||
||| Why bother? `deriv` builds new regexes out of old ones, and
||| without simplification the results grow junk like
||| `Alt (Cat Fail r) Eps` at every step. Simplifying while building
||| keeps every derivative small — which is what makes the engine
||| fast in practice, not just in theory.
public export
cat : Regex -> Regex -> Regex
cat Fail _   = Fail
cat _   Fail = Fail
cat Eps r    = r
cat r   Eps  = r
cat l   r    = Cat l r

||| Choose between two regexes — but simplify the obvious cases.
|||
||| `Fail` is the identity of choice (an impossible branch can be
||| dropped), and choosing between two identical regexes is no
||| choice at all.
public export
alt : Regex -> Regex -> Regex
alt Fail r    = r
alt l    Fail = l
alt l    r    = if l == r then l else Alt l r

||| Repeat a regex — but simplify the obvious cases.
|||
||| Repeating the impossible (or the empty string) zero-or-more
||| times can only ever produce the empty string, and a double star
||| adds nothing a single star does not.
public export
star : Regex -> Regex
star Fail       = Eps
star Eps        = Eps
star (Star r)   = Star r
star r          = Star r

||| The familiar way to ask for one specific character: a
||| one-character set. `Lit` from the earlier chapters lives on as
||| this ordinary function — the AST no longer needs a special case.
public export
lit : Char -> Regex
lit c = Sym (single c)

-- ---------------------------------------------------------------
-- The regex algebra, made official.
--
-- Regex is a monoid twice over: once under sequencing (Eps is the
-- do-nothing element) and once under choice (Fail is the
-- nothing-to-choose element). In Haskell you would pick one and
-- wrap the other in a newtype; Idris lets both coexist as *named*
-- implementations, chosen explicitly with @{...}.
-- ---------------------------------------------------------------

public export
[SeqSemigroup] Semigroup Regex where
  (<+>) = cat

public export
[SeqMonoid] Monoid Regex using SeqSemigroup where
  neutral = Eps

public export
[AltSemigroup] Semigroup Regex where
  (<+>) = alt

public export
[AltMonoid] Monoid Regex using AltSemigroup where
  neutral = Fail

||| Accept any of the given regexes: fold with the choice monoid.
||| `anyOf []` is `Fail` — offered no options, match nothing.
public export
anyOf : List Regex -> Regex
anyOf = foldr alt Fail

||| The Brzozowski derivative: `deriv c r` is the regex matching
||| exactly the strings `s` such that `r` matches `c :: s`.
|||
||| In plain words: "if `r` had to consume the character `c` first,
||| what would be left of it?" Matching a whole string is then just
||| deriving once per character — no backtracking, ever. This is the
||| reason our engine runs in a single left-to-right pass.
|||
||| The two interesting cases:
|||
||| - `Cat l r`: the character must be consumed by `l` — unless `l`
|||   can match the empty string, in which case it may also skip `l`
|||   and be consumed by `r`. That is exactly where `nullable` earns
|||   its keep.
||| - `Star r`: a star that consumes a character has committed to at
|||   least one repetition: derive one `r`, then the star continues.
public export
deriv : Char -> Regex -> Regex
deriv _ Fail      = Fail
deriv _ Eps       = Fail
deriv c (Sym s)   = if member c s then Eps else Fail
deriv c (Cat l r) =
  if nullable l
    then alt (cat (deriv c l) r) (deriv c r)
    else cat (deriv c l) r
deriv c (Alt l r) = alt (deriv c l) (deriv c r)
deriv c (Star r)  = cat (deriv c r) (Star r)

||| Does `r` match the whole string `s`?
|||
||| The entire matching algorithm is one line: fold `deriv` over the
||| characters, then ask `nullable` about what is left.
|||
||| ```
||| matches r "abc"
|||   = nullable (deriv 'c' (deriv 'b' (deriv 'a' r)))
||| ```
|||
||| Each character is consumed exactly once, left to right. There is
||| no backtracking to blow up on adversarial input — the number of
||| derivative steps is always exactly the length of the string.
||| That is the "linear time" in this book's title.
public export
matches : Regex -> String -> Bool
matches r s = nullable (foldl (flip deriv) r (unpack s))
