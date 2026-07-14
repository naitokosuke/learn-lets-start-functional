||| From pattern strings to the AST.
|||
||| The grammar, from loosest to tightest binding:
|||
||| ```
||| alternation := sequence ('|' sequence)*
||| sequence    := repetition*
||| repetition  := atom ('*' | '+' | '?' | '{' count '}')*
||| atom        := '(' alternation ')' | '[' class ']'
|||              | '.' | '\' escape | plain character
||| ```
|||
||| Each grammar rule is a parser; each parser returns a piece of
||| AST. Note what this module does *not* contain: there is no
||| matching logic here at all. Parsing and matching stay separate,
||| and meet only at the `Regex` type.
module Regex.Syntax

import Regex.Core
import Regex.Set
import Regex.Sugar
import Regex.Parse

-- A recursive grammar needs recursive parsers, and those (like
-- many/some) are honest `covering` functions rather than `total`.
%default covering

||| Characters that mean something special outside a class.
isMeta : Char -> Bool
isMeta c = elem c (unpack "()[]{}|*+?.\\")

||| A backslash escape interpreted as a single character:
||| `\n`, `\t`, `\r`, or any escaped literal like `\.` or `\\`.
escapedChar : Parser Char
escapedChar = char '\\' *> map interp anyToken
  where
    interp : Char -> Char
    interp 'n' = '\n'
    interp 't' = '\t'
    interp 'r' = '\r'
    interp c   = c

||| A backslash escape interpreted as a regex atom. The shorthand
||| classes expand to the sets from `Regex.Set`; anything else is
||| the escaped character itself.
escapedAtom : Parser Regex
escapedAtom = char '\\' *> map interp anyToken
  where
    interp : Char -> Regex
    interp 'd' = Sym digit
    interp 'D' = Sym (complement digit)
    interp 'w' = Sym word
    interp 'W' = Sym (complement word)
    interp 's' = Sym space
    interp 'S' = Sym (complement space)
    interp 'n' = lit '\n'
    interp 't' = lit '\t'
    interp 'r' = lit '\r'
    interp c   = lit c

||| Inside a class, `\d` `\w` `\s` contribute their ranges.
shorthandRanges : Parser (List (Char, Char))
shorthandRanges =
  char '\\' *>
    (   (char 'd' *> pure (ranges digit))
    <|> (char 'w' *> pure (ranges word))
    <|> (char 's' *> pure (ranges space)))

||| A literal character inside a class: anything but `]`, `\` or
||| `-` — those need escaping.
classChar : Parser Char
classChar = escapedChar <|> satisfy (\c => not (elem c (unpack "]\\-")))

||| One item of a class: a shorthand, a range `a-z`, or a single
||| character. Every item contributes a list of ranges.
classItem : Parser (List (Char, Char))
classItem = shorthandRanges <|> rangeOrSingle
  where
    rangeOrSingle : Parser (List (Char, Char))
    rangeOrSingle = do
      lo <- classChar
      (do _  <- char '-'
          hi <- classChar
          pure [(lo, hi)])
        <|> pure [(lo, lo)]

||| A whole class: `[...]` or negated `[^...]`.
classAtom : Parser Regex
classAtom = do
  _     <- char '['
  neg   <- (char '^' *> pure True) <|> pure False
  items <- some classItem
  _     <- char ']'
  pure (Sym (MkSet neg (concat items)))

||| A counted repetition suffix: `{n}`, `{n,}` or `{n,m}`.
counted : Parser (Regex -> Regex)
counted = do
  _ <- char '{'
  n <- natural
  f <- (do _ <- char ','
           (do m <- natural
               pure (between n m))
             <|> pure (atLeast n))
       <|> pure (exactly n)
  _ <- char '}'
  pure f

||| A postfix operator, as a *function on regexes*. `a**?` is legal
||| and pointless, exactly like in the AST.
postfix : Parser (Regex -> Regex)
postfix =
      (char '*' *> pure star)
  <|> (char '+' *> pure plus)
  <|> (char '?' *> pure opt)
  <|> counted

mutual
  ||| Lowest precedence: sequences separated by `|`.
  alternation : Parser Regex
  alternation = do
    first <- sequenceOf
    rest  <- many (char '|' *> sequenceOf)
    pure (foldl alt first rest)

  ||| Middle precedence: juxtaposition. Zero atoms is `Eps`,
  ||| which is why the empty pattern compiles.
  sequenceOf : Parser Regex
  sequenceOf = map (foldr cat Eps) (many repetition)

  ||| Highest precedence: an atom with its postfix operators,
  ||| applied left to right.
  repetition : Parser Regex
  repetition = do
    a     <- atom
    posts <- many postfix
    pure (foldl (\r, f => f r) a posts)

  ||| The atoms. `recur` delays the self-reference in `group` —
  ||| see `Regex.Parse.recur` for why.
  atom : Parser Regex
  atom = group <|> classAtom <|> wildcard <|> escapedAtom <|> plain
    where
      wildcard : Parser Regex
      wildcard = char '.' *> pure (Sym anyChar)

      plain : Parser Regex
      plain = map lit (satisfy (not . isMeta))

  group : Parser Regex
  group = char '(' *> recur alternation <* char ')'

||| Compile a pattern string into a regex — or `Nothing` when the
||| pattern is malformed. The parser must consume every character;
||| trailing garbage is a failure, not a warning.
public export
compile : String -> Maybe Regex
compile = parse alternation
