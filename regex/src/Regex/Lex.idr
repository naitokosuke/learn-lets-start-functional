||| The capstone: a lexer built on the engine.
|||
||| A lexer chops text into tokens using a table of rules — one
||| regex per token kind. The strategy is *maximal munch*: at each
||| position take the longest match any rule can make, and when two
||| rules tie, the one listed first wins.
|||
||| Derivatives make this almost embarrassingly direct: to advance
||| every rule by one character, derive every rule by one character.
||| No rule ever backtracks, so lexing stays a single pass.
module Regex.Lex

import Data.List
import Regex.Core
import Regex.Set

%default total

||| A token: which rule fired, and the exact text it consumed.
public export
record Token k where
  constructor MkToken
  kind : k
  text : String

||| Tokens print and compare whenever their kinds do — interface
||| implementations can have interface *constraints*.
export
Show k => Show (Token k) where
  show t = show t.kind ++ " " ++ show t.text

export
Eq k => Eq (Token k) where
  t1 == t2 = t1.kind == t2.kind && t1.text == t2.text

||| The first rule whose regex accepts right now, if any.
firstAccepting : List (k, Regex) -> Maybe k
firstAccepting []              = Nothing
firstAccepting ((k, r) :: rest) =
  if nullable r then Just k else firstAccepting rest

||| Advance every rule by one character. Dead rules collapse to
||| `Fail` on their own — the smart constructors see to that.
step : Char -> List (k, Regex) -> List (k, Regex)
step c = map (\(k, r) => (k, deriv c r))

||| Find the longest match at the head of the input.
|||
||| Walk forward, deriving all rules in lockstep; every time some
||| rule accepts, remember how far we got (`best`). When the input
||| ends — or every rule is dead — the last remembered accept is
||| the answer. Structural recursion on the input: total.
longest : List (k, Regex) -> List Char ->
          (sofar : Nat) -> (best : Maybe (k, Nat)) -> Maybe (k, Nat)
longest rules cs sofar best =
  let best' = case firstAccepting rules of
                Just k  => Just (k, sofar)
                Nothing => best
  in case cs of
       []          => best'
       (c :: rest) =>
         if all (\(_, r) => r == Fail) rules
           then best'
           else longest (step c rules) rest (S sofar) best'

||| Tokenize a whole string, or fail on the first stretch of input
||| that no rule can start a match on.
|||
||| A zero-length best match is treated as failure too: a rule that
||| matches the empty string would otherwise produce an infinite
||| stream of nothing.
|||
||| `assert_smaller` tells the totality checker what it cannot see
||| on its own: `rest` is a strict suffix of `cs`, because we only
||| recurse when the match consumed at least one character.
public export
tokenize : Eq k => List (k, Regex) -> String -> Maybe (List (Token k))
tokenize rules s = loop (unpack s)
  where
    loop : List Char -> Maybe (List (Token k))
    loop [] = Just []
    loop cs =
      case longest rules cs 0 Nothing of
        Nothing         => Nothing
        Just (_, Z)     => Nothing
        Just (k, S len) =>
          let (consumed, rest) = splitAt (S len) cs in
          map (MkToken k (pack consumed) ::) (loop (assert_smaller cs rest))
