---
title: "Capstone: A Lexer"
description: Everything composes into a real tool — a maximal-munch lexer where advancing every rule by one character means deriving every rule by one character.
---

# Capstone: A Lexer

One chapter of engine left in us, and we spend it building something real on top: a lexer — the first stage of every compiler — in about a screen of code, powered by everything the book has built.

## What a lexer is

Before a compiler can parse `1 + 2*x`, it chops the text into **tokens**: a number `1`, whitespace, a plus sign, and so on. That chopper is the lexer (or tokenizer), and it is traditionally specified as a table of rules — one regex per token kind.

The strategy that makes the table unambiguous is called **maximal munch**: at each position, take the *longest* match any rule can make; when two rules tie, the one listed *first* wins. Both halves matter. Longest-match is why `12foo` lexes as one identifier rather than the number `12` followed by `foo` — and, in real languages, why `>=` is one operator instead of two. First-rule-wins is how every language handles keywords: `if` matches both the keyword rule and the identifier rule at the same length, and the keyword rule wins purely by sitting higher in the table.

Here is the payoff moment for the whole book: to run many regexes in lockstep across the input, a backtracking matcher has real trouble — but with derivatives, *advancing every rule by one character just means deriving every rule by one character*. Regexes are values; a rule table is a `List`; lexing is a fold. Watch.

## Red: the rules of the game

Commit [b057007](https://github.com/ubugeeei-prod/lets-start-functional/commit/b057007416f97d6d479907844363c104ed976bf1) adds [`regex/tests/src/Spec/Lex.idr`](https://github.com/ubugeeei-prod/lets-start-functional/blob/main/regex/tests/src/Spec/Lex.idr). First, token kinds for a tiny calculator language — with `Eq` and `Show` written by hand, which after [A Regex Is Data](./06-regex-as-data.md) is pure routine:

```idris
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
```

Then the rule table, written in the pattern syntax we spent four chapters earning:

```idris
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
```

And the specs — maximal munch, the tie-break, failure, and one last point about design:

```idris
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
```

Savor that last spec. Most lexers grow a "skip whitespace" flag; ours does not need one, because tokens come back as an ordinary `List` and `filter` already exists. When your outputs are plain data, half the features you might build are functions somebody already wrote. The red:

```
Error: Module Regex.Lex not found
```

## Green: the lexer

Commit [d551858](https://github.com/ubugeeei-prod/lets-start-functional/commit/d55185805c8cb5a4d4a7137d74cee33b91785bbb) adds [`regex/src/Regex/Lex.idr`](https://github.com/ubugeeei-prod/lets-start-functional/blob/main/regex/src/Regex/Lex.idr). (It also adds one missing `import Data.Maybe` to the spec itself — `fromMaybe` lives there, not in the prelude. Even specs get fixes.) The token type is a record, generic in the kind:

```idris
||| A token: which rule fired, and the exact text it consumed.
public export
record Token k where
  constructor MkToken
  kind : k
  text : String

||| Tokens print and compare whenever their kinds do — interface
||| implementations can have interface *constraints*.
export
Show k => Show (Token k) where
  show t = show t.kind ++ " " ++ show t.text

export
Eq k => Eq (Token k) where
  t1 == t2 = t1.kind == t2.kind && t1.text == t2.text
```

Look at those implementation headers: `Show k => Show (Token k)`. An implementation can *require other implementations* — a `Token k` knows how to print itself exactly when its kind does. Small, but lovely: it is the same constraint arrow from every function signature, now appearing on an implementation, and it is how `Show` for lists, pairs and `Maybe` has worked under your feet all along.

Then the machinery — three short functions:

```idris
||| The first rule whose regex accepts right now, if any.
firstAccepting : List (k, Regex) -> Maybe k
firstAccepting []              = Nothing
firstAccepting ((k, r) :: rest) =
  if nullable r then Just k else firstAccepting rest

||| Advance every rule by one character. Dead rules collapse to
||| `Fail` on their own — the smart constructors see to that.
step : Char -> List (k, Regex) -> List (k, Regex)
step c = map (\(k, r) => (k, deriv c r))
```

`step` is the whole payoff of regexes-as-values in one line: advancing an entire rule table by one character is `map` of `deriv`. And `firstAccepting` is the tie-break: it scans the table top to bottom, so the *earlier* rule wins by construction. The longest-match walk:

```idris
||| Find the longest match at the head of the input.
|||
||| Walk forward, deriving all rules in lockstep; every time some
||| rule accepts, remember how far we got (`best`). When the input
||| ends — or every rule is dead — the last remembered accept is
||| the answer. Structural recursion on the input: total.
longest : List (k, Regex) -> List Char ->
          (sofar : Nat) -> (best : Maybe (k, Nat)) -> Maybe (k, Nat)
longest rules cs sofar best =
  let best' = case firstAccepting rules of
                Just k  => Just (k, sofar)
                Nothing => best
  in case cs of
       []          => best'
       (c :: rest) =>
         if all (\(_, r) => r == Fail) rules
           then best'
           else longest (step c rules) rest (S sofar) best'
```

Maximal munch, made literal: keep deriving, and every time some rule's regex is `nullable` — accepting, right here — overwrite `best` with the current position. When the input runs out, or every rule has died, the last remembered accept is the longest match. The early exit deserves a nod: a rule that can no longer match anything has derived to *literally* `Fail` — not to some sprawling tree that happens to be unsatisfiable — because the smart constructors from [Smart Constructors](./10-smart-constructors.md) collapse dead branches on the spot. That is why a simple `== Fail` check suffices to notice the whole table is dead.

Finally, the driver:

```idris
||| Tokenize a whole string, or fail on the first stretch of input
||| that no rule can start a match on.
|||
||| A zero-length best match is treated as failure too: a rule that
||| matches the empty string would otherwise produce an infinite
||| stream of nothing.
|||
||| `assert_smaller` tells the totality checker what it cannot see
||| on its own: `rest` is a strict suffix of `cs`, because we only
||| recurse when the match consumed at least one character.
public export
tokenize : Eq k => List (k, Regex) -> String -> Maybe (List (Token k))
tokenize rules s = loop (unpack s)
  where
    loop : List Char -> Maybe (List (Token k))
    loop [] = Just []
    loop cs =
      case longest rules cs 0 Nothing of
        Nothing         => Nothing
        Just (_, Z)     => Nothing
        Just (k, S len) =>
          let (consumed, rest) = splitAt (S len) cs in
          map (MkToken k (pack consumed) ::) (loop (assert_smaller cs rest))
```

Two guards worth reading twice. `Just (_, Z) => Nothing` rejects zero-length matches: a rule like `pat "a*"` accepts the empty string at every position, and a lexer that emits infinitely many empty tokens is not a lexer. And `assert_smaller` is a new honesty annotation: this module is `%default total`, but the totality checker cannot see that `rest` — produced by `splitAt` — is a strict suffix of `cs`. *We* can: the `S len` pattern guarantees at least one character was consumed. `assert_smaller cs rest` is the escape hatch where the programmer signs their name to exactly that claim. Used once, with a comment, for a reason we can articulate — like `covering` before it, the annotation does not weaken the code so much as document precisely where trust enters.

```sh
make test
```

```
  ...
  ok    a single number is a single token
  ok    maximal munch: the longest match wins
  ok    ties go to the earlier rule: 12 is a number, not a word
  ok    a small expression tokenizes completely
  ok    parentheses too
  ok    a character no rule accepts fails the whole input
  ok    the empty input is an empty token list
  ok    dropping whitespace is a List problem, not a lexer problem
163/163 passed
```

> [!NOTE]
> 163, not 167: in the repo history the lexer lands *before* the benchmark commits, so the four regression specs from [The Race](./19-the-race.md) are not in the suite yet at this point. Replaying the commits in order will show the same numbers.

## The property that composes

One closing flourish. The lexer never backtracks — not because we were careful, but because it *cannot*: its only engine operations are `deriv` and `nullable`, each rule advances exactly once per input character, and `tokenize` never revisits consumed text. Lexing a string of length n with m rules costs n derivative steps per rule, full stop, whatever the rules are. The linear-time property we built into the engine did not merely survive being built upon — it composed. That is the quiet thesis of this whole book: get the core right, make everything data and functions, and the good properties travel upward for free.

## Summary

- A lexer turns text into tokens using a rule table — one regex per token kind — under maximal munch: longest match wins, ties go to the earlier rule (which is how keywords beat identifiers).
- With regexes as values, the rule table is a `List (k, Regex)`, and advancing every rule is `map (deriv c)` — one line.
- `longest` walks forward remembering the last accept; dead rules collapse to literal `Fail` thanks to smart constructors, so `== Fail` gives an early exit.
- `tokenize` rejects zero-length matches, and uses `assert_smaller` — an honesty annotation, used once and justified in a comment — to tell the totality checker that consumed input shrinks.
- Interface implementations can be constrained (`Show k => Show (Token k)`), and dropping whitespace is `filter`, because tokens are plain data.
- The lexer inherits linearity from the engine: no rule ever backtracks, so the capstone runs in one pass, always.

The engine is finished, raced, proven and put to work. All that remains is to look at what you have built — and where to take it. On to [What's Next](./21-whats-next.md).
