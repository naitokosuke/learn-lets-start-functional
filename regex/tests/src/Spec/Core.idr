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

||| `nullable r` answers one question: does `r` match the empty string?
export
nullableSpecs : List Spec
nullableSpecs =
  [ shouldBe "Fail never matches, so not the empty string either"
      (nullable Fail) False
  , shouldBe "Eps matches exactly the empty string"
      (nullable Eps) True
  , shouldBe "a literal needs one character, empty is not enough"
      (nullable (Lit 'a')) False
  , shouldBe "a star matches zero repetitions, i.e. the empty string"
      (nullable (Star (Lit 'a'))) True
  , shouldBe "a sequence is nullable only when both halves are"
      (nullable (Cat Eps (Star (Lit 'a')))) True
  , shouldBe "a sequence with a non-nullable half is not nullable"
      (nullable (Cat (Star (Lit 'a')) (Lit 'b'))) False
  , shouldBe "a choice is nullable when either branch is"
      (nullable (Alt (Lit 'a') Eps)) True
  , shouldBe "a choice of two literals is not nullable"
      (nullable (Alt (Lit 'a') (Lit 'b'))) False
  ]
