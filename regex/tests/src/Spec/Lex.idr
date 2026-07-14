||| Specs for `Regex.Lex` — the capstone: a lexer built on the engine.
|||
||| A lexer is a list of (token kind, regex) rules applied with the
||| *maximal munch* strategy: at each position, take the longest
||| match any rule can make; on a tie, the earlier rule wins.
||| Thanks to derivatives, all rules advance together in one pass.
module Spec.Lex

import Harness
import Regex.Core
import Regex.Set
import Regex.Sugar
import Regex.Syntax
import Regex.Lex

||| Token kinds for a tiny calculator language.
data Tok = TNum | TIdent | TPlus | TTimes | TLParen | TRParen | TSpace

Eq Tok where
  TNum    == TNum    = True
  TIdent  == TIdent  = True
  TPlus   == TPlus   = True
  TTimes  == TTimes  = True
  TLParen == TLParen = True
  TRParen == TRParen = True
  TSpace  == TSpace  = True
  _       == _       = False

Show Tok where
  show TNum    = "TNum"
  show TIdent  = "TIdent"
  show TPlus   = "TPlus"
  show TTimes  = "TTimes"
  show TLParen = "TLParen"
  show TRParen = "TRParen"
  show TSpace  = "TSpace"

||| Compile a pattern we wrote ourselves; a typo is a broken rule,
||| and a broken rule should match nothing.
pat : String -> Regex
pat s = fromMaybe Fail (compile s)

||| The rule table. Order matters only for ties: TNum comes before
||| TIdent so that "12" is a number even though \w+ also matches it.
rules : List (Tok, Regex)
rules =
  [ (TSpace,  pat "\\s+")
  , (TNum,    pat "\\d+")
  , (TIdent,  pat "\\w+")
  , (TPlus,   pat "\\+")
  , (TTimes,  pat "\\*")
  , (TLParen, pat "\\(")
  , (TRParen, pat "\\)")
  ]

||| Shorthand for expected tokens.
tok : Tok -> String -> Token Tok
tok = MkToken

export
covering
lexSpecs : List Spec
lexSpecs =
  [ shouldBe "a single number is a single token"
      (tokenize rules "42")
      (Just [tok TNum "42"])
  , shouldBe "maximal munch: the longest match wins"
      (tokenize rules "12foo")
      (Just [tok TIdent "12foo"])
  , shouldBe "ties go to the earlier rule: 12 is a number, not a word"
      (tokenize rules "12")
      (Just [tok TNum "12"])
  , shouldBe "a small expression tokenizes completely"
      (tokenize rules "1 + 2*x")
      (Just [ tok TNum "1", tok TSpace " ", tok TPlus "+", tok TSpace " "
            , tok TNum "2", tok TTimes "*", tok TIdent "x"])
  , shouldBe "parentheses too"
      (tokenize rules "(a+1)")
      (Just [ tok TLParen "(", tok TIdent "a", tok TPlus "+"
            , tok TNum "1", tok TRParen ")"])
  , shouldBe "a character no rule accepts fails the whole input"
      (tokenize rules "1 $ 2")
      Nothing
  , shouldBe "the empty input is an empty token list"
      (tokenize rules "")
      (Just [])
  , it "dropping whitespace is a List problem, not a lexer problem"
      (map (filter (\t => t.kind /= TSpace)) (tokenize rules "1 + 2")
        == Just [tok TNum "1", tok TPlus "+", tok TNum "2"])
  ]
