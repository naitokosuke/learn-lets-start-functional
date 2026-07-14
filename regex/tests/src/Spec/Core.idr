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

||| `deriv c r` is the regex that matches whatever `r` matches
||| *after* consuming the character `c` — the Brzozowski derivative.
export
derivSpecs : List Spec
derivSpecs =
  [ shouldBe "Fail stays Fail, whatever we feed it"
      (deriv 'a' Fail) Fail
  , shouldBe "Eps has nothing left to give after any character"
      (deriv 'a' Eps) Fail
  , shouldBe "consuming the right literal leaves the empty string"
      (deriv 'a' (Lit 'a')) Eps
  , shouldBe "consuming the wrong literal fails"
      (deriv 'b' (Lit 'a')) Fail
  , shouldBe "a choice derives both branches"
      (deriv 'a' (Alt (Lit 'a') (Lit 'b')))
      (Alt Eps Fail)
  , shouldBe "a star unrolls one repetition and keeps going"
      (deriv 'a' (Star (Lit 'a')))
      (Cat Eps (Star (Lit 'a')))
  , shouldBe "a sequence derives its head first"
      (deriv 'a' (Cat (Lit 'a') (Lit 'b')))
      (Cat Eps (Lit 'b'))
  , shouldBe "a nullable head lets the character reach the tail too"
      (deriv 'b' (Cat (Star (Lit 'a')) (Lit 'b')))
      (Alt (Cat (Cat Fail (Star (Lit 'a'))) (Lit 'b')) Eps)
  ]

||| `matches r s` — the whole engine, end to end: derive once per
||| character, then ask `nullable`. Full-string semantics.
export
matchesSpecs : List Spec
matchesSpecs =
  [ it "a literal matches itself"
      (matches (Lit 'a') "a")
  , it "a literal rejects a different character"
      (not (matches (Lit 'a') "b"))
  , it "Eps matches the empty string"
      (matches Eps "")
  , it "matching is exact: 'a' does not match \"ab\""
      (not (matches (Lit 'a') "ab"))
  , it "a sequence matches its halves in order"
      (matches (Cat (Lit 'a') (Lit 'b')) "ab")
  , it "a sequence cares about order"
      (not (matches (Cat (Lit 'a') (Lit 'b')) "ba"))
  , it "a choice accepts its left branch"
      (matches (Alt (Lit 'a') (Lit 'b')) "a")
  , it "a choice accepts its right branch"
      (matches (Alt (Lit 'a') (Lit 'b')) "b")
  , it "a choice rejects anything else"
      (not (matches (Alt (Lit 'a') (Lit 'b')) "c"))
  , it "a* matches the empty string"
      (matches (Star (Lit 'a')) "")
  , it "a* matches one repetition"
      (matches (Star (Lit 'a')) "a")
  , it "a* matches many repetitions"
      (matches (Star (Lit 'a')) "aaaaaa")
  , it "a* rejects intruders"
      (not (matches (Star (Lit 'a')) "aaba"))
  , it "(ab)* matches whole pairs only"
      (matches (Star (Cat (Lit 'a') (Lit 'b'))) "abab")
  , it "(ab)* rejects a dangling half pair"
      (not (matches (Star (Cat (Lit 'a') (Lit 'b'))) "aba"))
  , it "(a|b)*c — a taste of a real pattern"
      (matches (Cat (Star (Alt (Lit 'a') (Lit 'b'))) (Lit 'c')) "abbac")
  ]
