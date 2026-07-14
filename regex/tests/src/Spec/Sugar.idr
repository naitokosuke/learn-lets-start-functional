||| Specs for `Regex.Sugar` — the convenience layer.
|||
||| `+`, `?`, `{n,m}` and string literals add no new matching power:
||| they are ordinary functions that *compile down* to the six core
||| constructors. Sugar is cheap when it is just functions.
module Spec.Sugar

import Harness
import Regex.Core
import Regex.Set
import Regex.Sugar

export
sugarSpecs : List Spec
sugarSpecs =
  [ -- plus: one or more
    shouldBe "plus r is literally r followed by r*"
      (plus (lit 'a')) (Cat (lit 'a') (Star (lit 'a')))
  , it "a+ needs at least one a"
      (not (matches (plus (lit 'a')) ""))
  , it "a+ matches one or many"
      (matches (plus (lit 'a')) "a" && matches (plus (lit 'a')) "aaaa")

    -- opt: zero or one
  , shouldBe "opt r is literally a choice between r and Eps"
      (opt (lit 'a')) (Alt (lit 'a') Eps)
  , it "a? matches zero or one a, never two"
      (matches (opt (lit 'a')) ""
        && matches (opt (lit 'a')) "a"
        && not (matches (opt (lit 'a')) "aa"))

    -- literal: a whole string, character by character
  , it "literal matches exactly its own string"
      (matches (literal "abc") "abc" && not (matches (literal "abc") "abd"))
  , shouldBe "the empty literal is Eps"
      (literal "") Eps

    -- counted repetition
  , it "exactly 3 means three, no more, no fewer"
      (matches (exactly 3 (lit 'a')) "aaa"
        && not (matches (exactly 3 (lit 'a')) "aa")
        && not (matches (exactly 3 (lit 'a')) "aaaa"))
  , it "atLeast 2 rejects one but accepts many"
      (not (matches (atLeast 2 (lit 'a')) "a")
        && matches (atLeast 2 (lit 'a')) "aa"
        && matches (atLeast 2 (lit 'a')) "aaaaaa")
  , it "between 2 4 accepts two through four"
      (not (matches (between 2 4 (lit 'a')) "a")
        && matches (between 2 4 (lit 'a')) "aa"
        && matches (between 2 4 (lit 'a')) "aaa"
        && matches (between 2 4 (lit 'a')) "aaaa"
        && not (matches (between 2 4 (lit 'a')) "aaaaa"))

    -- sugar composes with everything else
  , it "\\d{4}-\\d{2}-\\d{2} matches a date"
      (matches datePattern "2026-07-14")
  , it "the date pattern rejects a malformed date"
      (not (matches datePattern "2026-7-14"))
  ]
  where
    datePattern : Regex
    datePattern =
      cat (exactly 4 (Sym digit))
        (cat (lit '-')
          (cat (exactly 2 (Sym digit))
            (cat (lit '-') (exactly 2 (Sym digit)))))
