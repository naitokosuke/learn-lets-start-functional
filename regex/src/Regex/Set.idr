||| Symbolic sets of characters.
|||
||| Character classes like `[a-z0-9]`, the wildcard `.`, and escapes
||| like `\d` are all *sets* of characters. Enumerating every member
||| would be hopeless (`.` contains more than a million characters),
||| so we describe sets symbolically: a list of inclusive ranges,
||| plus a flag that flips the description into "everything except".
module Regex.Set

%default total

||| A set of characters, described by ranges and a negation flag.
|||
||| - `MkSet False [('a','z')]` is the class `[a-z]`.
||| - `MkSet True  [('0','9')]` is the class `[^0-9]`.
||| - `MkSet True  []` negates the empty set: *every* character.
public export
record CharSet where
  constructor MkSet
  ||| When True, the set is "every character NOT in the ranges".
  negated : Bool
  ||| Inclusive ranges; a single character is a one-element range.
  ranges : List (Char, Char)

export
Show CharSet where
  show (MkSet neg rs) = "MkSet " ++ show neg ++ " " ++ show rs

export
Eq CharSet where
  MkSet n1 r1 == MkSet n2 r2 = n1 == n2 && r1 == r2

||| Is `c` a member of the set?
|||
||| `any` does the real work: is `c` inside any of the ranges?
||| The negation flag then flips the answer — note the `/=`, which
||| on booleans is exactly "exclusive or".
public export
member : Char -> CharSet -> Bool
member c (MkSet neg rs) = neg /= any (\(lo, hi) => lo <= c && c <= hi) rs

||| The set containing exactly one character.
public export
single : Char -> CharSet
single c = MkSet False [(c, c)]

||| The set of characters from `lo` to `hi`, inclusive: `[lo-hi]`.
public export
range : Char -> Char -> CharSet
range lo hi = MkSet False [(lo, hi)]

||| The set of all characters appearing in a string: `[abc]`.
public export
oneOf : String -> CharSet
oneOf s = MkSet False (map (\c => (c, c)) (unpack s))

||| Every character — the wildcard `.` (we allow it to match
||| newlines; single-line mode is all we need).
public export
anyChar : CharSet
anyChar = MkSet True []

||| Everything *except* the members of the given set: `[^...]`.
|||
||| Because negation is just a flag, complement is one field flip —
||| no enumeration, no cost.
public export
complement : CharSet -> CharSet
complement (MkSet neg rs) = MkSet (not neg) rs

||| The digits `0-9` — the escape `\d`.
public export
digit : CharSet
digit = range '0' '9'

||| Letters, digits and underscore — the escape `\w`.
public export
word : CharSet
word = MkSet False [('a', 'z'), ('A', 'Z'), ('0', '9'), ('_', '_')]

||| Whitespace — the escape `\s`.
public export
space : CharSet
space = oneOf " \t\r\n"
