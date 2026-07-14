||| The front door of the library.
|||
||| ```idris example
||| case compile "(colou?r|gr[ae]y)" of
|||   Right r  => contains r "a grey wall"   -- True
|||   Left err => ...
||| ```
|||
||| `import Regex` brings in the AST, the character sets and the
||| sugar (via `import public`), plus the functions below. The
||| parser internals stay behind the curtain.
module Regex

import public Regex.Core
import public Regex.Set
import public Regex.Sugar

import Regex.Parse
import Regex.Syntax

%default total

||| What went wrong while compiling a pattern, and where.
public export
record CompileError where
  constructor MkCompileError
  ||| Zero-based index into the pattern string.
  position : Nat
  message  : String

export
Show CompileError where
  show e = e.message ++ " at position " ++ show e.position

export
Eq CompileError where
  e1 == e2 = e1.position == e2.position && e1.message == e2.message

||| Compile a pattern, or say where it went wrong.
|||
||| The underlying parser never dies halfway — it simply stops
||| consuming. So "how far did it get" is exactly "where the
||| pattern stopped making sense", and that is the position we
||| report.
export
covering
compile : String -> Either CompileError Regex
compile s =
  case runParser patternParser (unpack s) of
    Just (r, [])   => Right r
    Just (_, rest) =>
      Left (MkCompileError (length (unpack s) `minus` length rest)
                           "unexpected character")
    Nothing        => Left (MkCompileError 0 "malformed pattern")

||| Does the regex match the *whole* input? A synonym for
||| `Regex.Core.matches`, under the name users expect.
export
match : Regex -> String -> Bool
match = matches

||| Does the regex match *somewhere inside* the input?
|||
||| No new machinery: searching for `r` is matching `.*r.*` against
||| the whole string.
export
contains : Regex -> String -> Bool
contains r = matches (cat dotStar (cat r dotStar))
  where
    dotStar : Regex
    dotStar = star (Sym anyChar)

||| Compile and search in one call — for the quick, one-shot cases.
export
covering
test : (pattern : String) -> (input : String) -> Either CompileError Bool
test pattern input = map (\r => contains r input) (compile pattern)
