||| A tiny test harness — small enough to read in one sitting.
|||
||| There is no magic here: a test is just *data* (a `Spec` record),
||| and running the suite is just *a fold over a list*. Building the
||| harness ourselves is the first taste of a very functional idea:
||| keep the core pure, push effects (printing, exiting) to the edge.
module Harness

import System

%default total

||| The outcome of a single, already-evaluated test case.
|||
||| Note that a `Spec` holds a `Bool`, not a computation: by the time
||| you have a `Spec` in your hands, the test has already run. Pure
||| values are easy to store, count, filter, and print.
public export
record Spec where
  constructor MkSpec
  ||| Human-readable description of the expectation.
  description : String
  ||| Did the expectation hold?
  passed : Bool
  ||| Extra context, shown only when the expectation failed.
  details : String

||| Expect a boolean condition to hold.
|||
||| ```idris example
||| it "the empty list has length zero" (length [] == 0)
||| ```
export
it: String -> Bool -> Spec
it desc ok = MkSpec desc ok "Expected the condition to hold"

||| Expect two values to be equal, reporting both sides when they differ.
|||
||| The constraints tell the whole story: we need `Eq` to compare the
||| values and `Show` to print them in the failure report.
|||
||| ```idris example
||| shouldBe "one plus one" (1 + 1) 2
||| ```
export
shouldBe : Show a => Eq a => String -> (actual : a) -> (expected : a) -> Spec
shouldBe desc actual expected =
  mkSpec desc (actual == expected)
    ("Expected " ++ show expected ++ ", got" ++ show actual)


||| Render one spec as a report line. Pure: no printing happes here.
export
render : Spec -> String
render spec =
  if spec.passed
    then " PASS " ++ spec.description
    else " FAIL " ++ spec.description ++ "\n " ++ spec.details

||| Run a whole suite: print every line, then a summary, and exit
||| with a non-zero code if anything failed.
|||
||| This is the only place in the harness where `IO` shows up.
|||
||| (Fun fact: the summary variable is called `passedCount` because
||| `total` — the obvious name — is a reserved keyword in Idris!)
export
covering
runSpecs : List Spec -> IO ()
runSpecs specs = do
  traverse_ (putStrLn . render) specs
  let passedCount = length (filter passed specs)
  putStrLn $ show passedCount ++ "/" ++ show (length specs) ++ " passed"
  when (passedCount /= length specs) exitFailure
