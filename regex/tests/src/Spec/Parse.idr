||| Specs for `Regex.Parse` — a parser-combinator library from scratch.
|||
||| A `Parser a` is just a function from input to "maybe a result and
||| the leftover input". Everything else — sequencing, choice,
||| repetition — falls out of implementing the standard interfaces.
module Spec.Parse

import Harness
import Regex.Parse

export
parseSpecs : List Spec
parseSpecs =
  [ shouldBe "char consumes exactly its character"
      (parse (char 'a') "a") (Just 'a')
  , shouldBe "char rejects the wrong character"
      (parse (char 'a') "b") Nothing
  , shouldBe "parse demands that all input is consumed"
      (parse (char 'a') "ab") Nothing
  , shouldBe "map transforms a result (Functor)"
      (parse (map toUpper (char 'a')) "a") (Just 'A')
  , shouldBe "sequencing keeps both results (Applicative)"
      (parse [| MkPair (char 'a') (char 'b') |] "ab") (Just ('a', 'b'))
  , shouldBe "choice takes the first branch that succeeds (Alternative)"
      (parse (char 'a' <|> char 'b') "b") (Just 'b')
  , shouldBe "many matches zero occurrences"
      (parse (many (satisfy isDigit)) "") (Just [])
  , shouldBe "many matches as many occurrences as it can"
      (parse (many (satisfy isDigit)) "123") (Just ['1', '2', '3'])
  , shouldBe "some demands at least one occurrence"
      (parse (some (satisfy isDigit)) "") Nothing
  , shouldBe "natural reads a number (Monad, do-notation inside)"
      (parse natural "2026") (Just 2026)
  , shouldBe "combinators compose: a natural between parentheses"
      (parse (char '(' *> natural <* char ')') "(42)") (Just 42)
  ]
