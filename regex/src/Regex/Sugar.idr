||| The convenience layer: `+`, `?`, `{n,m}` and string literals.
|||
||| None of these add matching power — each one is a small function
||| that builds on the six core constructors. This is a deliberately
||| functional way to design a feature: keep the core minimal, and
||| let everything else be *definitions*, not new machinery.
module Regex.Sugar

import Regex.Core
import Regex.Set

%default total

||| One or more repetitions: `r+` is `r` followed by `r*`.
public export
plus : Regex -> Regex
plus r = cat r (star r)

||| Zero or one: `r?` is a choice between `r` and the empty string.
public export
opt : Regex -> Regex
opt r = alt r Eps

||| Match a whole string, character by character.
|||
||| A right fold turns `"abc"` into `a · (b · (c · ε))` — the same
||| shape you would have written by hand.
public export
literal : String -> Regex
literal s = foldr (cat . lit) Eps (unpack s)

||| Exactly `n` repetitions: `r{n}`.
|||
||| Recursion on a `Nat` is pattern matching like any other:
||| zero repetitions match the empty string, and `S k` repetitions
||| are one `r` followed by `k` more.
public export
exactly : Nat -> Regex -> Regex
exactly Z     _ = Eps
exactly (S k) r = cat r (exactly k r)

||| At least `n` repetitions: `r{n,}` is `n` copies, then `r*`.
public export
atLeast : Nat -> Regex -> Regex
atLeast n r = cat (exactly n r) (star r)

||| Up to `n` optional repetitions.
|||
||| The nesting matters: `upTo 2 r` is `(r (r)?)?`, so each extra
||| repetition is only allowed after the previous one appeared.
upTo : Nat -> Regex -> Regex
upTo Z     _ = Eps
upTo (S k) r = opt (cat r (upTo k r))

||| Between `n` and `m` repetitions: `r{n,m}` is `n` required copies
||| followed by `m - n` optional ones. (If `m < n`, natural-number
||| subtraction truncates to zero and this means exactly `n`.)
public export
between : (n : Nat) -> (m : Nat) -> Regex -> Regex
between n m r = cat (exactly n r) (upTo (m `minus` n) r)
