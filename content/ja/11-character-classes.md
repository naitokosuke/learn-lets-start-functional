---
title: 文字クラス
description: 文字の集合を範囲と否定フラグで記号的に記述し，ASTのリファクタリングはコンパイラに導いてもらいます．
---

# 文字クラス

現実のパターンは`.`や`[a-z]`や`\d`だらけなのに，今のエンジンは「正確にこの1文字」しかマッチできません．この章では記号的な文字集合を作り，そのあとASTの一般化をコンパイラに先導してもらいましょう．

## 列挙の何が問題か

文字クラスとは文字の集合です．`[a-z]`は小文字の集合，`\d`は数字の集合，`.`は，まあ，全部の集合です．素朴に表現するならメンバーのリストでしょう．`[abc]`ならそれで問題ないです．ただ`.`には絶望的です．Unicodeには100万を超える文字があり，「任意の文字」のために100万要素のリストを組み立てるのはさすがに馬鹿げています．`[^"]`(引用符以外のすべて)のような否定クラスは，なおさら悲惨です．

ここで働く関数型の直感は，メンバーを保存するのをやめて，記述を保存することです．文字の集合は次の2つで記述できます:

- 両端を含む範囲のリスト(`[a-z0-9_]`は3つの範囲と1文字ぶんの範囲)，そして
- 「実はこの範囲に入っていない文字すべてです」という意味のフラグ．

これなら`.`は「空の範囲リストに入っていない」というだけで表せます．100万個のエントリではなく，ほんのふた言です．つまり，所属(membership)は参照ではなく計算で答える問いになります．

## Red:集合型のスペック

スペックは新しいファイル`regex/tests/src/Spec/Set.idr`に置きます．まずは基本からです．集合を作って，所属を尋ねます:

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

続いて面白いところです．ワイルドカード，補集合(complement)，そして正規表現ユーザーなら誰もが期待する名前付きの略記たちです:

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

例の如く`setSpecs`を`Main.idr`につないで実行します:

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

Redです．これはコミット[3664e98](https://github.com/ubugeeei-prod/lets-start-functional/commit/3664e980fcc4826957d9f6ea8159187c83d854c3)です．

## Green: CharSet

モジュール全体，つまり`regex/src/Regex/Set.idr`は，このレコードから始まります:

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

所属判定は1行です:

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

この`/=`は少し面白いので，じっくり見てみてください．欲しい挙動は，フラグがオフなら「範囲に入っている」，オンなら「範囲に入っていない」です．`if`で書いてもいいのですが，ブール値に対する`/=`の真理値表を見ると，両辺が異なるとき，ちょうどそのときだけ真になります．つまり`False /= inRanges`は`inRanges`そのもの，`True /= inRanges`は`not inRanges`です．「等しくない」は排他的論理和(XOR)そのものであり，フラグとのXORは条件付きの否定そのものというわけです．4行の条件分岐が3文字に置き換わります．一度この技を見てしまうと，もう戻れないかと思います．

コンストラクタたちはどれも1行です:

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

`complement`は，記号的表現のご利益をぎゅっと凝縮した見本です．列挙された集合の補集合を取るには「それ以外すべて」を実体化しなければなりません(例の100万要素の悪夢です)．一方，記述の補集合を取るのはブール値をひとつ反転するだけです．仕事はデータから`member`関数へ移り，そこではタダ同然というわけです．

略記たちは関数ですらありません．ただの値，素朴なデータです:

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

これはコミット[d308014](https://github.com/ubugeeei-prod/lets-start-functional/commit/d308014230c5b32ef497b5b1ded14b4df547cd8e)です．

## Red:文字集合はASTに属する

`CharSet`はできましたが，エンジンはまだ使えません．ASTが文字を消費する唯一の手段は`Lit Char`，つまり「正確にこの1文字」だからです．なので，ここでコア型の本物のリファクタリングを初めて経験することになります．`Lit Char`を`Sym CharSet`に変えます．「この集合から1文字だけマッチする」という意味です．リテラルは1文字集合という特殊ケースになり，普通の関数`lit`を通していつでも使えます．

まずはスペックからです．`Spec/Core.idr`に追加します:

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

Redです．`Sym`も`lit`もまだ存在しません．これはコミット[18e8d25](https://github.com/ubugeeei-prod/lets-start-functional/commit/18e8d25353606318038a5e4e575579c824e2904f)です．

## Green:コンパイラに運転させる

この章の本当の主役は，このリファクタリング技法です．**まずデータ型を変え，それからエラーを追いかける．** `Core.idr`で，コンストラクタを差し替えます:

```idris
  ||| Matches exactly one character, drawn from a set: literals,
  ||| classes like `[a-z]`, and the wildcard `.` are all this one
  ||| constructor with different sets.
  Sym : CharSet -> Regex
```

ここでビルドすると，コンパイラが完全なTODOリストを手渡してくれます:

```
Error: While processing left hand side of showRegex. Undefined name Lit.
...
Error: While processing left hand side of ==. Undefined name Lit.
...
Error: While processing left hand side of nullable. Undefined name Lit.
...
Error: While processing left hand side of deriv. Undefined name Lit.
```

`Lit`をパターンマッチしていたすべての関数(`showRegex`，`Eq`の`==`，`nullable`，`deriv`)が，行番号つきでコンパイルを止めます．どこかに5つ目の場所が隠れている，ということはありえません．パターンマッチと`%default total`の誓いが合わされば，コンパイラはどの関数にも`Regex`のすべてのケースを必ず説明させるので，直し忘れた関数を見逃しようがないのです．たいていの言語では「コア型を変えた」のあとに何日ものgrepと祈りが続きますが，ここでは指摘された4箇所を直すだけです．ファイルがコンパイルできたら，リファクタリングは完了です．

直しはこんな感じです．`nullable (Sym _) = False`(集合であっても，必要なのはちょうど1文字です)．`Show`と`Eq`のケースは`CharSet`自身の実装に委譲します．そして`deriv`には，このリファクタリング全体で唯一の，本当に新しいロジックが入ります:

```idris
deriv c (Sym s)   = if member c s then Eps else Fail
```

古い行`if c == x then Eps else Fail`と見比べてみてください．1文字との等価比較が，集合への所属判定になりました．これがリテラルと文字クラスの意味論上の違いのすべてで，その幅はたった関数呼び出しひとつぶんです．

最後に，`Lit`は普通の関数として生き続けます:

```idris
||| The familiar way to ask for one specific character: a
||| one-character set. `Lit` from the earlier chapters lives on as
||| this ordinary function — the AST no longer needs a special case.
public export
lit : Char -> Regex
lit c = Sym (single c)
```

[前の章](./10-smart-constructors.md)のスマートコンストラクタと同じ一手ですね．かつてコンストラクタだったものが，一般的な形を組み立てる小文字の関数になりました．ASTは精神的には小さくなりました．コンストラクタは相変わらず6つですが，そのうちのひとつが，リテラルもクラスもエスケープもワイルドカードも，まとめて面倒を見るようになったのです．

支払うべき代償がもうひとつあります．`Lit 'a'`と書いていた既存のスペックはすべて`lit 'a'`に直さなければなりません(それと，リテラルが`Sym (MkSet False [('a', 'a')])`と印字されるようになったので，`show`の出力を期待していたスペックもいくつか変わります)．この書き換え自体は機械的で，検索置換で済みます．ただ，なぜそれが起きたのかは立ち止まる価値があります．古いスペックは「リテラル」という公開された概念を通り越して，コンストラクタそのもの，つまり実装の詳細に触れていました．詳細が変わり，テストがそのツケを払ったわけです．`lit`に対して書かれた新しいスペックは，リテラルの表現がこの先どう変わっても生き残ります．なので，テストからコンストラクタが消えるのは雑用ではなく，設計が良くなっている証拠です．

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

これはコミット[4d2733d](https://github.com/ubugeeei-prod/lets-start-functional/commit/4d2733d8248bdd3bc0de79eee10ba0b79213e45f)です．

## まとめ

- クラスのメンバーを列挙する方式では`.`や`[^"]`を表現できません．集合を範囲と否定フラグで記号的に記述すれば，「すべて」も含むどんなクラスも，ほんのわずかなデータで済みます．
- `member`は範囲に対する`any`で所属を計算します．そしてブール値の`/=`は排他的論理和です．条件付き否定が3文字で書けます．
- `complement`はフィールドをひとつ反転するだけです．記号的表現のおかげで否定はタダです．
- `\d`，`\w`，`\s`は機能ではなく，`CharSet`の名前付きの値です．
- ASTのリファクタリング`Lit Char` → `Sym CharSet`はコンパイラ主導でした．型を変えれば，全域性検査が新しいケースを必要とする関数をすべて列挙してくれます．`deriv`の新しいケースは`==`を`member`に替えるだけでした．
- `lit`は素の関数として残ります．スペックが`Lit`から`lit`に乗り換えたことで，テストに漏れ出していた実装の詳細がひとつ消えました．

次は`+`，`?`，`{n,m}`と文字列リテラルを追加します．そして，それらが何のコストもかからないことを発見します．[糖衣構文はただの関数](./12-sugar.md)へ進みましょう!
