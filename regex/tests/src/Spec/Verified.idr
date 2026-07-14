||| Specs for `Regex.Verified` — where the tests become theorems.
|||
||| Everything else in this suite checks examples: finitely many
||| inputs, chosen by us. The proofs in `Regex.Verified` check *all*
||| inputs at once, and their test runner is the type checker: if
||| this module's import compiles, the theorems hold.
|||
||| The one runtime spec below is a marker so the suite output
||| mentions the chapter; the real assertions are compile-time.
module Spec.Verified

import Harness
import Regex.Verified

export
verifiedSpecs : List Spec
verifiedSpecs =
  [ it "nullable is provably sound and complete (checked at compile time)"
      True
  ]
