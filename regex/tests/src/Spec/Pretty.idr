||| Specs for `Regex.Pretty` and the regex algebra.
|||
||| Two ideas meet here:
|||
||| 1. `toPattern` — the inverse of the parser: render an AST back
|||    into pattern syntax, with correct precedence and escaping.
||| 2. `Regex` forms a monoid *twice over* — once under sequencing
|||    (with `Eps` as neutral) and once under choice (with `Fail`).
|||    Idris lets both coexist as *named* implementations.
module Spec.Pretty

import Harness
import Regex
import Regex.Pretty

||| Compile, print, re-compile: the same tree should come back.
roundtrips : String -> Bool
roundtrips p =
  case compile p of
    Right r => compile (toPattern r) == Right r
    Left _  => False

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

    -- the two monoids
  , shouldBe "sequencing: <+> under SeqSemigroup is cat"
      ((<+>) @{SeqSemigroup} (lit 'a') (lit 'b'))
      (Cat (lit 'a') (lit 'b'))
  , shouldBe "sequencing: the neutral element is Eps"
      (the Regex (neutral @{SeqMonoid})) Eps
  , shouldBe "choice: <+> under AltSemigroup is alt"
      ((<+>) @{AltSemigroup} (lit 'a') (lit 'b'))
      (Alt (lit 'a') (lit 'b'))
  , shouldBe "choice: the neutral element is Fail"
      (the Regex (neutral @{AltMonoid})) Fail
  , it "anyOf folds a whole list of alternatives"
      (matches (anyOf [literal "let", literal "in", literal "where"]) "in")
  , shouldBe "anyOf of nothing is Fail — you can match none of no things"
      (anyOf []) Fail
  ]
