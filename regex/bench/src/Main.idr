||| The race: derivatives against backtracking.
|||
||| The pattern family `(a?){n}a{n}` matched against `n` a's is the
||| classic catastrophic-backtracking demonstration (see Russ Cox,
||| "Regular Expression Matching Can Be Simple And Fast"). A
||| backtracker has 2^n ways to distribute the a's and, on this
||| input, visits essentially all of them. The derivative engine
||| walks the input once.
|||
||| Run with: make bench
module Main

import Data.List
import System.Clock
import Regex.Core
import Regex.Set
import Regex.Sugar
import Regex.Naive

||| `(a?){n}a{n}`, built directly with the sugar combinators.
evil : Nat -> Regex
evil n = cat (exactly n (opt (lit 'a'))) (exactly n (lit 'a'))

||| n a's.
input : Nat -> String
input n = pack (replicate n 'a')

||| A fixed, friendly pattern: (a|b)*c.
fixed : Regex
fixed = cat (star (alt (lit 'a') (lit 'b'))) (lit 'c')

||| n a's followed by a single c.
inputC : Nat -> String
inputC n = pack (replicate n 'a' ++ ['c'])

||| A duration in milliseconds.
ms : Clock Duration -> Double
ms c = cast (seconds c) * 1000 + cast (nanoseconds c) / 1000000

||| Time one boolean computation. The `Lazy` argument keeps the
||| work from happening before the clock starts.
covering
timed : String -> Lazy Bool -> IO ()
timed label act = do
  t0 <- clockTime Monotonic
  let result = force act
  t1 <- clockTime Monotonic
  putStrLn $ "  " ++ label ++ ": "
          ++ show (ms (timeDifference t1 t0)) ++ " ms"
          ++ "  (matched: " ++ show result ++ ")"

covering
race : Nat -> IO ()
race n = do
  putStrLn $ "n = " ++ show n
  timed "derivatives " (matches (evil n) (input n))
  timed "backtracking" (naiveMatch (evil n) (input n))

covering
main : IO ()
main = do
  putStrLn "(a?){n}a{n} against a^n — both engines"
  traverse_ race [10, 12, 14, 16, 18, 20]
  putStrLn ""
  putStrLn "fixed pattern (a|b)*c, growing input — derivatives only"
  traverse_ (\n => timed ("length = " ++ show (S n))
                         (matches fixed (inputC n)))
            [9999, 99999, 999999]
