||| Specs for `Regex.Naive` — the matcher we deliberately did NOT build.
|||
||| A backtracking matcher tries one possibility, and if that fails,
||| rewinds and tries another. It gives the same answers as our
||| derivative engine — these specs prove that on a pile of cases —
||| but its running time can explode exponentially. The book's
||| benchmark chapter feeds both engines the infamous `(a?){n}a{n}`
||| family and lets the clock tell the story.
module Spec.Naive

import Harness
import Regex
import Regex.Naive

||| Both engines, same verdict?
agree : String -> String -> Bool
agree pat input =
  case compile pat of
    Left _  => False
    Right r => naiveMatch r input == matches r input

export
naiveSpecs : List Spec
naiveSpecs =
  [ it "the backtracker agrees on literals"
      (agree "abc" "abc" && agree "abc" "abd" && agree "abc" "")
  , it "the backtracker agrees on choice"
      (agree "a|b" "a" && agree "a|b" "b" && agree "a|b" "c")
  , it "the backtracker agrees on stars"
      (agree "a*" "" && agree "a*" "aaaa" && agree "a*" "aab"
        && agree "(ab)*" "abab" && agree "(ab)*" "aba")
  , it "the backtracker agrees on classes and shorthands"
      (agree "[a-c]+" "cab" && agree "[a-c]+" "cad"
        && agree "\\d{2,4}" "123" && agree "\\d{2,4}" "12345")
  , it "the backtracker agrees on the tricky nullable-head cases"
      (agree "(a*)*b" "aaab" && agree "(a*)*b" "aaaa"
        && agree "(a|)(a|)b" "ab" && agree "(a|)(a|)b" "aab")
  , it "the backtracker agrees on a real-world shape"
      (agree "\\w+@\\w+\\.\\w+" "user@example.com"
        && agree "\\w+@\\w+\\.\\w+" "user@example")
  ]
