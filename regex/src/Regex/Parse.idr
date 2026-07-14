||| A parser-combinator library from scratch, in about a screen of code.
|||
||| A `Parser a` is *just a function*: give it input characters, and
||| it either fails or hands back a value and the leftover input.
||| Big parsers are built by combining small ones — and the combining
||| operators are not regex-specific at all. They are the standard
||| functional interfaces:
|||
||| - `Functor`     : transform a parser's result (`map`)
||| - `Applicative` : run parsers in sequence (`<*>`, `*>`, `<*`)
||| - `Monad`       : let one parser depend on another's result (`do`)
||| - `Alternative` : try one parser, fall back to another (`<|>`)
module Regex.Parse

%default total

||| A parser of `a`s: consume characters, maybe produce an `a`
||| and the unconsumed rest.
public export
record Parser a where
  constructor MkParser
  runParser : List Char -> Maybe (a, List Char)

||| Run a parser against a whole string. Succeeds only when every
||| character is consumed — leftovers mean the parse failed.
public export
parse : Parser a -> String -> Maybe a
parse p s =
  case runParser p (unpack s) of
    Just (a, []) => Just a
    _            => Nothing

||| Consume one character satisfying the predicate.
public export
satisfy : (Char -> Bool) -> Parser Char
satisfy ok = MkParser $ \cs =>
  case cs of
    (c :: rest) => if ok c then Just (c, rest) else Nothing
    []          => Nothing

||| Consume exactly the character `c`.
public export
char : Char -> Parser Char
char c = satisfy (== c)

public export
Functor Parser where
  map f p = MkParser $ \cs =>
    case runParser p cs of
      Just (a, rest) => Just (f a, rest)
      Nothing        => Nothing

public export
Applicative Parser where
  pure a = MkParser $ \cs => Just (a, cs)
  pf <*> pa = MkParser $ \cs =>
    case runParser pf cs of
      Nothing        => Nothing
      Just (f, rest) =>
        case runParser pa rest of
          Nothing         => Nothing
          Just (a, rest') => Just (f a, rest')

public export
Monad Parser where
  p >>= f = MkParser $ \cs =>
    case runParser p cs of
      Nothing        => Nothing
      Just (a, rest) => runParser (f a) rest

public export
Alternative Parser where
  empty = MkParser $ \_ => Nothing
  p <|> q = MkParser $ \cs =>
    case runParser p cs of
      Just res => Just res
      Nothing  => runParser q cs

mutual
  ||| Zero or more occurrences. (`many p` can call itself forever if
  ||| `p` succeeds without consuming, so Idris will not certify it
  ||| total — we own up to that with `covering`.)
  public export
  covering
  many : Parser a -> Parser (List a)
  many p = some p <|> pure []

  ||| One or more occurrences. The idiom brackets `[| ... |]` are
  ||| Applicative sugar: cons the first result onto the rest.
  public export
  covering
  some : Parser a -> Parser (List a)
  some p = [| p :: many p |]

||| Parse a natural number, digit by digit.
public export
covering
natural : Parser Nat
natural = map digitsToNat (some (satisfy isDigit))
  where
    digitVal : Char -> Nat
    digitVal c = cast (ord c - ord '0')

    digitsToNat : List Char -> Nat
    digitsToNat = foldl (\acc, c => 10 * acc + digitVal c) 0
