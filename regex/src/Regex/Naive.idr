||| The matcher we deliberately did NOT build: a backtracker.
|||
||| This is (a simplified version of) how many mainstream regex
||| engines work. To match `Alt l r`, try `l`; if the rest of the
||| match fails, rewind and try `r`. Every choice point is a fork,
||| and on adversarial patterns the forks multiply: `(a?){n}` gives
||| 2^n ways to slice a run of a's, and a failing match visits all
||| of them. That blow-up has a name — catastrophic backtracking —
||| and it has taken real services down (Cloudflare, 2019; Stack
||| Overflow, 2016).
|||
||| Meanwhile `Regex.Core.matches` walks the input once, whatever
||| the pattern. The benchmark in the book races the two.
module Regex.Naive

import Regex.Core
import Regex.Set

-- Backtracking recursion is not structural; `covering` is honest.
%default covering

||| The worker. `k` is the *continuation*: what the rest of the
||| match still expects. `go r cs k` means "match some prefix of
||| `cs` against `r`, then hand the leftovers to `k`".
|||
||| Continuations are the functional way to say "and then". Note
||| how `Alt` becomes `||` — try the left match wholesale, or start
||| over on the right — and how `Cat l r` chains: match `l`, and
||| the continuation of `l` is "now match `r`".
|||
||| The one wrinkle: `Star`. A star whose body can match the empty
||| string (think `(a|)*`) could "repeat" forever without eating
||| anything, so we only loop when the body actually consumed input
||| — that is the `length rest < length cs` guard.
go : Regex -> List Char -> (List Char -> Bool) -> Bool
go Fail      _         _ = False
go Eps       cs        k = k cs
go (Sym s)   []        _ = False
go (Sym s)   (c :: cs) k = member c s && k cs
go (Cat l r) cs        k = go l cs (\rest => go r rest k)
go (Alt l r) cs        k = go l cs k || go r cs k
go (Star r)  cs        k =
  k cs || go r cs (\rest =>
    if length rest < length cs
      then go (Star r) rest k
      else False)

||| Whole-string matching, by backtracking. Same specification as
||| `Regex.Core.matches`; very different running time.
|||
||| The final continuation answers the final question: after the
||| whole pattern has matched, is the input fully consumed?
public export
naiveMatch : Regex -> String -> Bool
naiveMatch r s = go r (unpack s) null
