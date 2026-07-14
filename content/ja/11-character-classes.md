---
title: 文字クラス
description: 文字の集合を記号的に — 範囲と否定フラグで — 記述し、AST のリファクタリングはコンパイラに導いてもらいます。
---

# 文字クラス

現実のパターンは `.` や `[a-z]` や `\d` だらけなのに、私たちのエンジンは「正確にこの 1 文字」しかマッチできません。この章では記号的な文字集合を作り、そのあと AST の一般化をコンパイラに先導してもらいます。

## 列挙の何が問題か

文字クラスとは文字の*集合*です。`[a-z]` は小文字の集合、`\d` は数字の集合、`.` は — そう、全部の集合。素朴な表現はメンバーのリストでしょう。`[abc]` ならそれで結構。でも `.` には絶望的です。Unicode には 100 万を超える文字があり、「任意の文字」を表すために 100 万要素のリストを組み立てるのは馬鹿げています。`[^"]` — 引用符*以外*のすべて — のような否定クラスは、なおさら悲惨です。

ここで働く関数型の直感は、メンバーを保存するのをやめて、*記述*を保存することです。文字の集合は次の 2 つで記述できます:

- 両端を含む範囲のリスト(`[a-z0-9_]` は 3 つの範囲と 1 文字ぶんの範囲)、そして
- 「実はこの範囲に*入っていない*文字すべてです」という意味のフラグ。

これなら `.` は「空の範囲リストに入っていない」— 100 万個のエントリではなく、ほんのふた言です。所属(membership)は、参照ではなく計算で答える問いになります。

## Red: 集合型のスペック

スペックは新しいファイル `regex/tests/src/Spec/Set.idr` に置きます。まずは基本から — 集合を作り、所属を尋ねる:

```idris
||| Specs for `Regex.Set` — symbolic sets of characters.
|||
||| A character class like `[a-z0-9]` or `[^"\\]` is a *set* of
||| characters. We describe sets symbolically (ranges + a negation
||| flag) instead of enumerating them, so `.` (any character) is as
||| cheap as `a`.
module Spec.Set

import Harness
import Regex.Set

export
setSpecs : List Spec
setSpecs =
  [ it "a single-character set contains its character"
      (member 'a' (single 'a'))
  , it "a single-character set contains nothing else"
      (not (member 'b' (single 'a')))
  , it "a range contains a character inside it"
      (member 'm' (range 'a' 'z'))
  , it "a range includes both of its endpoints"
      (member 'a' (range 'a' 'z') && member 'z' (range 'a' 'z'))
  , it "a range excludes characters outside it"
      (not (member 'A' (range 'a' 'z')))
  , it "oneOf builds a set from the characters of a string"
      (member 'b' (oneOf "abc") && not (member 'd' (oneOf "abc")))
```

続いて面白いところ。ワイルドカード、補集合(complement)、そして正規表現ユーザーなら誰もが期待する名前付きの略記です:

```idris
  , it "anyChar contains everything"
      (member 'x' anyChar && member '!' anyChar && member ' ' anyChar)
  , it "complement flips membership"
      (not (member 'a' (complement (single 'a')))
        && member 'b' (complement (single 'a')))
  , it "digit is 0-9"
      (member '7' digit && not (member 'x' digit))
  , it "word is letters, digits and underscore"
      (member 'k' word && member 'Z' word && member '4' word
        && member '_' word && not (member '-' word))
  , it "space is whitespace"
      (member ' ' space && member '\t' space && member '\n' space
        && not (member 'x' space))
  , it "sets compare structurally"
      (range 'a' 'z' == range 'a' 'z' && single 'a' /= single 'b')
  ]
```

`setSpecs` を `Main.idr` につないで実行します:

```sh
make test
```

```
Error: Module Regex.Set not found

Spec.Set:10:1--10:17
 06 | ||| cheap as `a`.
 07 | module Spec.Set
 08 |
 09 | import Harness
 10 | import Regex.Set
      ^^^^^^^^^^^^^^^^
```

Red です。これはコミット [3664e98](https://github.com/ubugeeei-prod/lets-start-functional/commit/3664e980fcc4826957d9f6ea8159187c83d854c3) です。

## Green: CharSet

モジュール全体、つまり `regex/src/Regex/Set.idr` は、このレコードから始まります:

```idris
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
```

所属判定は 1 行です。しかも、惚れ惚れする 1 行です:

```idris
||| Is `c` a member of the set?
|||
||| `any` does the real work: is `c` inside any of the ranges?
||| The negation flag then flips the answer — note the `/=`, which
||| on booleans is exactly "exclusive or".
public export
member : Char -> CharSet -> Bool
member c (MkSet neg rs) = neg /= any (\(lo, hi) => lo <= c && c <= hi) rs
```

この `/=` と、しばらく向き合ってみてください。欲しいのは、フラグがオフなら「範囲に入っている」、オンなら「範囲に入っていない」。`if` で書くこともできます。でもブール値に対する `/=` の真理値表を見てください — 両辺が異なるとき、ちょうどそのときだけ真になります。`False /= inRanges` は `inRanges` そのもの。`True /= inRanges` は `not inRanges`。「等しくない」は排他的論理和(XOR)*そのもの*であり、フラグとの XOR は条件付きの否定*そのもの*なのです。4 行の条件分岐が 3 文字に置き換わる。一度この技を見てしまったら、もう見なかったことにはできません。

コンストラクタたちはどれも 1 行です:

```idris
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
```

`complement` は、記号的表現のご利益をぎゅっと凝縮した見本です。列挙された集合の補集合を取るには「それ以外すべて」を実体化しなければなりません — 100 万要素の悪夢です。*記述*の補集合を取るのは、ブール値をひとつ反転するだけ。仕事はデータから `member` 関数へ移り、そこではタダ同然なのです。

略記たちは関数ですらありません — ただの値、素朴なデータです:

```idris
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
```

```sh
make test
```

```
  ...
  ok    a single-character set contains its character
  ...
  ok    sets compare structurally
  ...
68/68 passed
```

これはコミット [d308014](https://github.com/ubugeeei-prod/lets-start-functional/commit/d308014230c5b32ef497b5b1ded14b4df547cd8e) です。

## Red: 文字集合は AST に属する

`CharSet` はできましたが、エンジンはまだ使えません。AST が文字を消費する唯一の手段は `Lit Char`、つまり「正確にこの 1 文字」だからです。計画はこうです — そしてこれはコア型の本物のリファクタリング、私たちにとって初めての経験になります。`Lit Char` を `Sym CharSet` に変えます。「この集合から 1 文字だけマッチする」という意味です。リテラルは 1 文字集合という特殊ケースになり、普通の関数 `lit` を通していつでも使えます。

まずはスペックから。`Spec/Core.idr` に:

```idris
||| The `Sym` constructor generalizes single-character literals to
||| whole character sets — `.`, `[a-z]`, `\d` and friends.
export
symSpecs : List Spec
symSpecs =
  [ it "a range matches any character inside it"
      (matches (Sym (range 'a' 'z')) "q")
  , it "a range rejects characters outside it"
      (not (matches (Sym (range 'a' 'z')) "Q"))
  , it "the wildcard matches any single character"
      (matches (Sym anyChar) "!")
  , it "the wildcard still needs exactly one character"
      (not (matches (Sym anyChar) "") && not (matches (Sym anyChar) "ab"))
  , it "\\d* matches a run of digits"
      (matches (Star (Sym digit)) "2026")
  , it "a negated class matches everything but its members"
      (matches (Star (Sym (complement (oneOf "\"")))) "no quotes here")
  , it "lit is still available as a one-character set"
      (matches (lit 'a') "a" && not (matches (lit 'a') "b"))
  ]
```

```sh
make test
```

```
Error: While processing right hand side of symSpecs. Undefined name lit.

Spec.Core:99:17--99:20
 95 |       (matches (Star (Sym digit)) "2026")
 96 |   , it "a negated class matches everything but its members"
 97 |       (matches (Star (Sym (complement (oneOf "\"")))) "no quotes here")
 98 |   , it "lit is still available as a one-character set"
 99 |       (matches (lit 'a') "a" && not (matches (lit 'a') "b"))
                      ^^^
Did you mean any of: Lit, or it?
```

Red です — `Sym` も `lit` もまだ存在しません。これはコミット [18e8d25](https://github.com/ubugeeei-prod/lets-start-functional/commit/18e8d25353606318038a5e4e575579c824e2904f) です。

## Green: コンパイラに運転させる

この章の本当の主役であるリファクタリング技法がこれです。**まずデータ型を変え、それからエラーを追いかける。** `Core.idr` で、コンストラクタを差し替えます:

```idris
  ||| Matches exactly one character, drawn from a set: literals,
  ||| classes like `[a-z]`, and the wildcard `.` are all this one
  ||| constructor with different sets.
  Sym : CharSet -> Regex
```

ここでビルドすると、コンパイラが完全な to-do リストを手渡してくれます:

```
Error: While processing left hand side of showRegex. Undefined name Lit.
...
Error: While processing left hand side of ==. Undefined name Lit.
...
Error: While processing left hand side of nullable. Undefined name Lit.
...
Error: While processing left hand side of deriv. Undefined name Lit.
```

`Lit` をパターンマッチしていたすべての関数 — `showRegex`、`Eq` の `==`、`nullable`、`deriv` — が、行番号つきでコンパイルを止めます。どこかに 5 つ目の場所が隠れている、ということはありません。パターンマッチと `%default total` の誓いが合わされば、コンパイラはどの関数でも `Regex` のすべてのケースを*必ず*説明させられるので、直し忘れた関数を見逃しようがないのです。たいていの言語では、「コア型を変えた」のあとに何日もの grep と祈りが続きます。ここでは、指摘された 4 箇所を直すだけ。ファイルがコンパイルできたら、リファクタリングは完了です。

直しはこうなります。`nullable (Sym _) = False`(集合であっても、必要なのはちょうど 1 文字です)。`Show` と `Eq` のケースは `CharSet` 自身の実装に委譲。そして `deriv` には、このリファクタリング全体で唯一の、本当に新しいロジックが入ります:

```idris
deriv c (Sym s)   = if member c s then Eps else Fail
```

古い行 — `if c == x then Eps else Fail` — と見比べてください。1 文字との等価比較が、集合への所属判定になりました。これがリテラルと文字クラスの意味論上の違いのすべてであり、その幅はたった関数呼び出しひとつぶんです。

最後に、`Lit` は普通の関数として生き続けます:

```idris
||| The familiar way to ask for one specific character: a
||| one-character set. `Lit` from the earlier chapters lives on as
||| this ordinary function — the AST no longer needs a special case.
public export
lit : Char -> Regex
lit c = Sym (single c)
```

[前の章](./10-smart-constructors.md) のスマートコンストラクタと同じ一手です。かつてコンストラクタだったものが、一般的な形を組み立てる小文字の関数になりました。AST は精神においては*小さく*なりました — コンストラクタは相変わらず 6 つですが、そのうちのひとつが、リテラルもクラスもエスケープもワイルドカードも、まとめて面倒を見るようになったのです。

支払うべき代償がもうひとつあります。`Lit 'a'` と書いていた既存のスペックはすべて `lit 'a'` に直さなければなりません(それと、リテラルが `Sym (MkSet False [('a', 'a')])` と印字されるようになったので、`show` の出力を期待していたスペックもいくつか変わります)。この書き換えは機械的で、検索置換で済みます — でも、*なぜ*それが起きたのかには立ち止まる価値があります。古いスペックは「リテラル」という公開された概念を通り越して、コンストラクタそのもの、つまり実装の詳細に触れていました。詳細が変わり、テストはその馴れ馴れしさのツケを払ったのです。`lit` に対して書かれた新しいスペックは、リテラルの表現がこの先どう変わっても生き残ります。テストからコンストラクタが消えるのは雑用ではありません。設計が良くなっているのです。

```sh
make test
```

```
  ...
  ok    a range matches any character inside it
  ...
  ok    lit is still available as a one-character set
  ...
75/75 passed
```

これはコミット [4d2733d](https://github.com/ubugeeei-prod/lets-start-functional/commit/4d2733d8248bdd3bc0de79eee10ba0b79213e45f) です。

## まとめ

- クラスのメンバーを列挙する方式では `.` や `[^"]` を表現できません。集合を記号的に — 範囲と否定フラグで — 記述すれば、「すべて」も含むどんなクラスも、ほんのわずかなデータで済みます。
- `member` は範囲に対する `any` で所属を計算します。そしてブール値の `/=` は排他的論理和 — 条件付き否定が 3 文字で書けます。
- `complement` はフィールドをひとつ反転するだけ — 記号的表現のおかげで否定はタダです。
- `\d`、`\w`、`\s` は機能ではありません。`CharSet` の名前付きの値です。
- AST のリファクタリング `Lit Char` → `Sym CharSet` はコンパイラ主導でした。型を変えれば、全域性検査が新しいケースを必要とする関数をすべて列挙してくれます。`deriv` の新しいケースは `==` を `member` に替えるだけでした。
- `lit` は素の関数として残ります。スペックが `Lit` から `lit` に乗り換えたことで、テストに漏れ出していた実装の詳細がひとつ消えました。

次は `+`、`?`、`{n,m}` と文字列リテラルを追加します — そして、それらが何のコストもかからないことを発見します。[糖衣構文はただの関数](./12-sugar.md) へ。
