||| Specs for the `Regex` module — the front door of the library.
|||
||| Users should need exactly one import. `compile` returns a
||| position-carrying error instead of a bare `Nothing`, and
||| `contains` gives the unanchored search everyone expects.
module Spec.Api

import Data.Either
import Harness
import Regex

||| Compile a pattern we trust, then apply a check to it.
withPattern : String -> (Regex -> Bool) -> Bool
withPattern pat check =
  case compile pat of
    Right r => check r
    Left _  => False

export
apiSpecs : List Spec
apiSpecs =
  [ it "compile accepts a well-formed pattern"
      (isRight (compile "(colou?r|gr[ae]y)"))
  , shouldBe "compile reports the position where parsing gave up"
      (compile "ab)")
      (Left (MkCompileError 2 "unexpected character"))
  , shouldBe "an unterminated class fails at its opening bracket"
      (compile "[oops")
      (Left (MkCompileError 0 "unexpected character"))
  , it "match is whole-string"
      (withPattern "\\d+" (\r => match r "123" && not (match r "a123")))
  , it "contains searches anywhere in the input"
      (withPattern "\\d{4}" (\r => contains r "born in 1991, maybe"))
  , it "contains still rejects when nothing matches"
      (withPattern "\\d{4}" (\r => not (contains r "no year here")))
  , shouldBe "test compiles and searches in one call"
      (test "wor\\w+" "hello world") (Right True)
  , shouldBe "test reports non-matches as Right False"
      (test "xyz" "hello world") (Right False)
  , shouldBe "test propagates compile errors"
      (test "[oops" "anything")
      (Left (MkCompileError 0 "unexpected character"))
  ]
