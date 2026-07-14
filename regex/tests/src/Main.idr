||| Entry point of the test suite.
|||
||| Every spec module exports a plain `List Spec`; the runner just
||| concatenates them. Adding a module to the suite is adding a list.
module Main

import Harness
import Spec.Core

||| Sanity checks for the harness itself — the very first red/green
||| cycle of this project was making these pass.
sanitySpecs : List Spec
sanitySpecs =
  [ it "true is true" True
  , shouldBe "one plus one is two" (1 + 1) 2
  , shouldBe "strings concatenate" ("fun" ++ "ctional") "functional"
  ]

main : IO ()
main = runSpecs $ sanitySpecs
                ++ astSpecs
                ++ nullableSpecs
                ++ derivSpecs
                ++ matchesSpecs
