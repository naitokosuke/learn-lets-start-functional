||| Printing regexes back as pattern syntax — the parser's inverse.
|||
||| The interesting problem is *precedence*: `Cat (Alt a b) c` must
||| print as `(a|b)c`, not `a|bc`. We solve it the standard way: the
||| renderer carries the precedence of its surroundings and inserts
||| parentheses exactly when the child binds looser than the context.
|||
||| Levels: 0 = alternation, 1 = concatenation, 2 = postfix, 3 = atom.
||| Concatenation and alternation associate to the right (matching
||| the parser), so their right child renders one level looser than
||| their left child — that asymmetry is what makes
||| `compile (toPattern r) == Right r` hold exactly.
module Regex.Pretty

import Regex.Core
import Regex.Set
import Regex.Syntax

%default total

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
|||
||| For anything produced by `compile`, printing and re-parsing
||| gives back the identical tree. (Hand-built trees can contain
||| shapes with no syntax — `Fail`, or a star under a star — which
||| is exactly why `compile` never produces them.)
public export
toPattern : Regex -> String
toPattern = render 0
