||| Where the tests become theorems.
|||
||| Our specs check `nullable` on a handful of examples. This module
||| checks it on *every* regex at once. The trick is dependent types:
||| we write down what "r matches cs" *means* as a data type, and
||| then prove that `nullable` answers exactly that question for the
||| empty string. If this module compiles, the theorems are true —
||| the type checker is the test runner.
module Regex.Verified

import Regex.Core
import Regex.Set

%default total

||| Evidence that the regex `r` matches the character list `cs`.
|||
||| Read each constructor as a rule of inference. There is no code
||| here — a value of this type is a *derivation*, like the ones you
||| would draw on paper in a theory course.
public export
data Matches : Regex -> List Char -> Type where
  ||| ε matches the empty string.
  MEps   : Matches Eps []
  ||| A set matches any single member. The `member c s = True`
  ||| argument is itself evidence — a proof obligation, not a Bool
  ||| we promise to have checked.
  MSym   : (c : Char) -> member c s = True -> Matches (Sym s) [c]
  ||| If `l` matches `xs` and `r` matches `ys`, the concatenation
  ||| matches `xs ++ ys`. (The lists are bound explicitly so that
  ||| proofs may inspect them — see the erasure aside in the book.)
  MCat   : {xs, ys : List Char} ->
           Matches l xs -> Matches r ys -> Matches (Cat l r) (xs ++ ys)
  ||| A choice matches whatever its left branch matches...
  MAltL  : Matches l xs -> Matches (Alt l r) xs
  ||| ...or whatever its right branch matches. (`l` kept relevant,
  ||| again for the proofs.)
  MAltR  : {l : Regex} -> Matches r xs -> Matches (Alt l r) xs
  ||| A star matches the empty string (zero repetitions)...
  MStarZ : Matches (Star r) []
  ||| ...or one non-empty repetition followed by more star. The
  ||| non-emptiness (`c ::`) is what keeps derivations finite.
  MStarS : Matches r (c :: xs) -> Matches (Star r) ys ->
           Matches (Star r) (c :: (xs ++ ys))

-- Note what is NOT here: no constructor mentions Fail. `Fail`
-- matches nothing precisely because there is no way to build
-- evidence for it.

||| Boolean fact: if `a && b` came out True, both sides are True.
andBoth : {a, b : Bool} -> a && b = True -> (a = True, b = True)
andBoth {a = True}  {b = True}  Refl = (Refl, Refl)
andBoth {a = True}  {b = False} prf  = absurd prf
andBoth {a = False}             prf  = absurd prf

||| Boolean fact: if `a || b` came out True, one side is True.
orEither : {a, b : Bool} -> a || b = True -> Either (a = True) (b = True)
orEither {a = True}  _   = Left Refl
orEither {a = False} prf = Right prf

||| **Soundness**: when `nullable r` says True, there really is a
||| derivation of `r` matching the empty string.
|||
||| The proof is induction on `r` — which in Idris is just pattern
||| matching and recursion, the same tools we have used all book.
export
nullableSound : (r : Regex) -> nullable r = True -> Matches r []
nullableSound Fail      prf = absurd prf
nullableSound Eps       _   = MEps
nullableSound (Sym s)   prf = absurd prf
nullableSound (Cat l r) prf =
  let (pl, pr) = andBoth prf
  in MCat (nullableSound l pl) (nullableSound r pr)
nullableSound (Alt l r) prf =
  case orEither prf of
    Left  pl => MAltL (nullableSound l pl)
    Right pr => MAltR (nullableSound r pr)
nullableSound (Star r)  _   = MStarZ

||| List fact: a concatenation is empty only when both halves are.
appendNil : (xs, ys : List a) -> xs ++ ys = [] -> (xs = [], ys = [])
appendNil []        []        _    = (Refl, Refl)
appendNil []        (y :: ys) Refl impossible
appendNil (x :: xs) _         Refl impossible

||| Boolean fact: anything or-ed with True is True.
orTrueRight : (a : Bool) -> a || True = True
orTrueRight True  = Refl
orTrueRight False = Refl

||| **Completeness**: when there is a derivation of `r` matching
||| the empty string, `nullable r` says True.
|||
||| This time the induction is on the *derivation*. The equation
||| argument `cs = []` lets each case learn what the emptiness of
||| the input tells us about its sub-derivations.
export
nullableComplete : Matches r cs -> cs = [] -> nullable r = True
nullableComplete MEps _ = Refl
nullableComplete (MSym c p) Refl impossible
nullableComplete (MCat {xs} {ys} pl pr) prf =
  let (ex, ey) = appendNil xs ys prf
      nl = nullableComplete pl ex
      nr = nullableComplete pr ey
  in rewrite nl in rewrite nr in Refl
nullableComplete (MAltL pl) prf =
  rewrite nullableComplete pl prf in Refl
nullableComplete (MAltR {l} pr) prf =
  rewrite nullableComplete pr prf in orTrueRight (nullable l)
nullableComplete MStarZ _ = Refl
nullableComplete (MStarS p ps) Refl impossible

-- ---------------------------------------------------------------
-- Derivations you can hold in your hand
-- ---------------------------------------------------------------

||| Evidence that `ab` matches "ab": a concatenation of two
||| one-character derivations. The membership proofs are `Refl`
||| because `member 'a' (single 'a')` *computes* to True.
export
exampleAB : Matches (Cat (lit 'a') (lit 'b')) ['a', 'b']
exampleAB = MCat (MSym 'a' Refl) (MSym 'b' Refl)

||| Evidence that `a*` matches "aa": two repetitions, then zero.
export
exampleStar : Matches (Star (lit 'a')) ['a', 'a']
exampleStar = MStarS (MSym 'a' Refl) (MStarS (MSym 'a' Refl) MStarZ)
