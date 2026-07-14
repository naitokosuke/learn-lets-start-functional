||| Specs for `Regex.Core` — the abstract syntax of regular expressions.
module Spec.Core

import Harness
import Regex.Core
import Regex.Set

||| The AST is just data: we can build it, print it, and compare it.
export
astSpecs : List Spec
astSpecs =
  [ shouldBe "show renders the match-nothing regex"
      (show Fail) "Fail"
  , shouldBe "show renders the empty-string regex"
      (show Eps) "Eps"
  , shouldBe "show renders a one-character set"
      (show (lit 'a')) "Sym (MkSet False [('a', 'a')])"
  , shouldBe "show parenthesizes nested structure"
      (show (Star (Alt Eps Fail)))
      "Star (Alt Eps Fail)"
  , shouldBe "show renders alternation"
      (show (Alt Eps (Star Eps)))
      "Alt Eps (Star Eps)"
  , it "structurally equal regexes are equal"
      (Cat (lit 'a') (Alt Eps (lit 'b')) == Cat (lit 'a') (Alt Eps (lit 'b')))
  , it "different literals are not equal"
      (lit 'a' /= lit 'b')
  , it "different shapes are not equal"
      (Star (lit 'a') /= Cat (lit 'a') (lit 'a'))
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
      (nullable (lit 'a')) False
  , shouldBe "a star matches zero repetitions, i.e. the empty string"
      (nullable (Star (lit 'a'))) True
  , shouldBe "a sequence is nullable only when both halves are"
      (nullable (Cat Eps (Star (lit 'a')))) True
  , shouldBe "a sequence with a non-nullable half is not nullable"
      (nullable (Cat (Star (lit 'a')) (lit 'b'))) False
  , shouldBe "a choice is nullable when either branch is"
      (nullable (Alt (lit 'a') Eps)) True
  , shouldBe "a choice of two literals is not nullable"
      (nullable (Alt (lit 'a') (lit 'b'))) False
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
      (deriv 'a' (lit 'a')) Eps
  , shouldBe "consuming the wrong literal fails"
      (deriv 'b' (lit 'a')) Fail
  , shouldBe "a choice derives both branches — and drops the dead one"
      (deriv 'a' (Alt (lit 'a') (lit 'b')))
      Eps
  , shouldBe "a star unrolls one repetition, with no Eps junk in front"
      (deriv 'a' (Star (lit 'a')))
      (Star (lit 'a'))
  , shouldBe "a sequence derives its head first, simplified"
      (deriv 'a' (Cat (lit 'a') (lit 'b')))
      (lit 'b')
  , shouldBe "a nullable head lets the character reach the tail — cleanly"
      (deriv 'b' (Cat (Star (lit 'a')) (lit 'b')))
      Eps
  ]

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

||| Smart constructors: `cat`, `alt` and `star` build the same six
||| shapes, but simplify the obvious algebra on the way —
||| so derivatives stay small instead of accumulating junk.
export
smartSpecs : List Spec
smartSpecs =
  [ shouldBe "Fail swallows a sequence from the left"
      (cat Fail (lit 'a')) Fail
  , shouldBe "Fail swallows a sequence from the right"
      (cat (lit 'a') Fail) Fail
  , shouldBe "sequencing with the empty string is a no-op (left)"
      (cat Eps (lit 'a')) (lit 'a')
  , shouldBe "sequencing with the empty string is a no-op (right)"
      (cat (lit 'a') Eps) (lit 'a')
  , shouldBe "anything else still nests as Cat"
      (cat (lit 'a') (lit 'b')) (Cat (lit 'a') (lit 'b'))
  , shouldBe "a choice against Fail picks the live branch (left)"
      (alt Fail (lit 'a')) (lit 'a')
  , shouldBe "a choice against Fail picks the live branch (right)"
      (alt (lit 'a') Fail) (lit 'a')
  , shouldBe "identical branches collapse"
      (alt (lit 'a') (lit 'a')) (lit 'a')
  , shouldBe "anything else still nests as Alt"
      (alt (lit 'a') (lit 'b')) (Alt (lit 'a') (lit 'b'))
  , shouldBe "the star of Fail can only match the empty string"
      (star Fail) Eps
  , shouldBe "the star of Eps is just Eps"
      (star Eps) Eps
  , shouldBe "a double star collapses to a single one"
      (star (Star (lit 'a'))) (Star (lit 'a'))
  , shouldBe "anything else still wraps in Star"
      (star (lit 'a')) (Star (lit 'a'))
  ]

||| `matches r s` — the whole engine, end to end: derive once per
||| character, then ask `nullable`. Full-string semantics.
export
matchesSpecs : List Spec
matchesSpecs =
  [ it "a literal matches itself"
      (matches (lit 'a') "a")
  , it "a literal rejects a different character"
      (not (matches (lit 'a') "b"))
  , it "Eps matches the empty string"
      (matches Eps "")
  , it "matching is exact: 'a' does not match \"ab\""
      (not (matches (lit 'a') "ab"))
  , it "a sequence matches its halves in order"
      (matches (Cat (lit 'a') (lit 'b')) "ab")
  , it "a sequence cares about order"
      (not (matches (Cat (lit 'a') (lit 'b')) "ba"))
  , it "a choice accepts its left branch"
      (matches (Alt (lit 'a') (lit 'b')) "a")
  , it "a choice accepts its right branch"
      (matches (Alt (lit 'a') (lit 'b')) "b")
  , it "a choice rejects anything else"
      (not (matches (Alt (lit 'a') (lit 'b')) "c"))
  , it "a* matches the empty string"
      (matches (Star (lit 'a')) "")
  , it "a* matches one repetition"
      (matches (Star (lit 'a')) "a")
  , it "a* matches many repetitions"
      (matches (Star (lit 'a')) "aaaaaa")
  , it "a* rejects intruders"
      (not (matches (Star (lit 'a')) "aaba"))
  , it "(ab)* matches whole pairs only"
      (matches (Star (Cat (lit 'a') (lit 'b'))) "abab")
  , it "(ab)* rejects a dangling half pair"
      (not (matches (Star (Cat (lit 'a') (lit 'b'))) "aba"))
  , it "(a|b)*c — a taste of a real pattern"
      (matches (Cat (Star (Alt (lit 'a') (lit 'b'))) (lit 'c')) "abbac")
  ]
