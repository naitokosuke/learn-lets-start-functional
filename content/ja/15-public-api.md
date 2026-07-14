---
title: 公開 API
description: import はひとつ、位置を運ぶエラーはデータとして、そして新しい機構の要らないアンカーなし検索 — ライブラリの正面玄関を作ります。
---

# 公開 API

エンジンは完成しました。今度はその正面玄関を設計します。この章の主役は新しいアルゴリズムではなく、あらゆるライブラリが直面する問いです。ユーザーに何を見せ、何を幕の裏に置いておくべきか?

## ユーザーに必要であるべきもの

[前の章](./14-pattern-syntax.md) の時点で、このライブラリを使うには import が 4 つ必要です(`Regex.Core`、`Regex.Set`、`Regex.Sugar`、`Regex.Syntax`)。どの名前がどのモジュールのものかという知識も必要です。そして `compile` は、不正なパターンに素っ気ない `Nothing` で答えます — 何がどこでまずかったのか、ヒントすらなし。私たち自身にはこれで十分。でもお客さまには失礼です。

正面玄関への願いごとリスト:

- **import はひとつ。** `import Regex` で、ユーザーに必要なものがすべてスコープに入る。
- **「どこで」を語るエラー。** `Nothing` でもなく、散文の文字列でもなく — 位置を運ぶ*値*。エディタが問題の文字ちょうどに下線を引けるように。
- **みんなが期待する検索。** 文字列全体の `match` と、アンカーなしの `contains` — 「この中に年号は入ってる?」と聞きたいユーザーの大半は、`.*` を自分で書きたくないからです。
- スクリプト向けの**ワンコールの便利関数**: パターン文字列を入れたら、判定が出てくる。

## Red: 正面玄関に向けたスペック

`regex/tests/src/Spec/Api.idr` を、一字一句そのまま:

```idris
||| Specs for the `Regex` module — the front door of the library.
|||
||| Users should need exactly one import. `compile` returns a
||| position-carrying error instead of a bare `Nothing`, and
||| `contains` gives the unanchored search everyone expects.
module Spec.Api

import Data.Either
import Harness
import Regex

||| Compile a pattern we trust, then apply a check to it.
withPattern : String -> (Regex -> Bool) -> Bool
withPattern pat check =
  case compile pat of
    Right r => check r
    Left _  => False

export
apiSpecs : List Spec
apiSpecs =
  [ it "compile accepts a well-formed pattern"
      (isRight (compile "(colou?r|gr[ae]y)"))
  , shouldBe "compile reports the position where parsing gave up"
      (compile "ab)")
      (Left (MkCompileError 2 "unexpected character"))
  , shouldBe "an unterminated class fails at its opening bracket"
      (compile "[oops")
      (Left (MkCompileError 0 "unexpected character"))
  , it "match is whole-string"
      (withPattern "\\d+" (\r => match r "123" && not (match r "a123")))
  , it "contains searches anywhere in the input"
      (withPattern "\\d{4}" (\r => contains r "born in 1991, maybe"))
  , it "contains still rejects when nothing matches"
      (withPattern "\\d{4}" (\r => not (contains r "no year here")))
  , shouldBe "test compiles and searches in one call"
      (test "wor\\w+" "hello world") (Right True)
  , shouldBe "test reports non-matches as Right False"
      (test "xyz" "hello world") (Right False)
  , shouldBe "test propagates compile errors"
      (test "[oops" "anything")
      (Left (MkCompileError 0 "unexpected character"))
  ]
```

このスペックで、私たちは `Either CompileError Regex` にコミットします — 成功なら `Right`、構造化されたエラーなら `Left`。そして 2 つのエラーの期待値をよく見てください。`"ab)"` は位置 2、迷い込んだ括弧のところで失敗します。`"[oops"` は位置 0 — *開き*ブラケットです。意味をなさなかったのは、クラス全体だからです。この 2 つの数字は、まもなく設計からほとんどタダで転がり出てきます。

```sh
make test
```

```
Error: Module Regex not found

Spec.Api:10:1--10:13
 06 | module Spec.Api
 07 |
 08 | import Data.Either
 09 | import Harness
 10 | import Regex
      ^^^^^^^^^^^^
```

Red です。これはコミット [225458c](https://github.com/ubugeeei-prod/lets-start-functional/commit/225458c6dedb442374bf7cc32c79c8e3f12889b2) です。

## Green: Regex モジュール

新しい `regex/src/Regex.idr` は、ユーザーに何を見せるかを決めるところから始まります:

```idris
||| The front door of the library.
|||
||| ```idris example
||| case compile "(colou?r|gr[ae]y)" of
|||   Right r  => contains r "a grey wall"   -- True
|||   Left err => ...
||| ```
|||
||| `import Regex` brings in the AST, the character sets and the
||| sugar (via `import public`), plus the functions below. The
||| parser internals stay behind the curtain.
module Regex

import public Regex.Core
import public Regex.Set
import public Regex.Sugar

import Regex.Parse
import Regex.Syntax

%default total
```

import が 2 種類あり、この違いこそ API 設計*そのもの*です。素の `import` は、モジュールの名前を*ここ*、つまり `Regex.idr` の中でだけ見えるようにします — ほかのどこでもなく。`import public` はさらに先へ行きます。再エクスポートするのです。`import Regex` と書いた人は、それらのモジュールがエクスポートするすべてを、自分で import したのと同じように受け取ります。つまり `Regex.Core`、`Regex.Set`、`Regex.Sugar` — AST、文字集合、糖衣構文、ユーザーがものを組み立てるための道具 — は、ひとつの import と一緒に旅をします。`Regex.Parse` と `Regex.Syntax` は素の import です。この下で私たちは使いますが、`satisfy` や `classItem` の仲間たちがユーザーの名前空間へ漏れ出すことはありません。公開面(public surface)は、import の 5 行で宣言されているのです。

### エラーはデータ

```idris
||| What went wrong while compiling a pattern, and where.
public export
record CompileError where
  constructor MkCompileError
  ||| Zero-based index into the pattern string.
  position : Nat
  message  : String

export
Show CompileError where
  show e = e.message ++ " at position " ++ show e.position

export
Eq CompileError where
  e1 == e2 = e1.position == e2.position && e1.message == e2.message
```

エラーを文字列にしたい誘惑はあります — `"unexpected ) at position 2"` — 文字列は印字が楽だからです。しかし文字列は、情報が死にに行く場所です。位置 2 に下線を引きたいエディタは、*私たちのエラーメッセージをパース*する羽目になります。レコードなら、位置とメッセージは別々のフィールドのまま。`Show` はそれを描画するひとつの方法にすぎず、エラーそのものではありません。エラーはまずデータ、散文はその次です。

### 位置のトリック

さて、パターンが*どこで*まずくなったかを、どうやって知ればいいのでしょう?嬉しい驚きがあります。実は、もう知っているのです。`Regex.Syntax` に小さなエクスポートをひとつ足します:

```idris
||| The whole grammar as a single parser, for callers that want to
||| run it themselves (the `Regex` module does, to report positions).
public export
patternParser : Parser Regex
patternParser = alternation
```

そして正面玄関の `compile` は、これを `parse` ではなく `runParser` で走らせ、残り物を検分できるようにします:

```idris
||| Compile a pattern, or say where it went wrong.
|||
||| The underlying parser never dies halfway — it simply stops
||| consuming. So "how far did it get" is exactly "where the
||| pattern stopped making sense", and that is the position we
||| report.
export
covering
compile : String -> Either CompileError Regex
compile s =
  case runParser patternParser (unpack s) of
    Just (r, [])   => Right r
    Just (_, rest) =>
      Left (MkCompileError (length (unpack s) `minus` length rest)
                           "unexpected character")
    Nothing        => Left (MkCompileError 0 "malformed pattern")
```

私たちのコンビネータは完全にバックトラックするので、文法のいちばん上の規則が途中でクラッシュすることはありません — 意味の取れないものにぶつかったら、ただ*消費をやめて*、手元にあるものを残り物付きで返すだけです。これでエラー位置の特定は算数になります。パーサが消費したのは `length input - length leftover` 文字。だからこの差こそ、パターンが意味をなさなくなった正確なインデックスです。コンビネータにエラー追跡の機構を通す必要も、パーサの状態に位置カウンタを持たせる必要もありません。情報は最初からずっと残り物の中にあった。私たちはただ、それを捨てるのをやめればよかったのです。

スペックと突き合わせてみましょう。`"ab)"` では、パーサは `ab` を消費し、`)` を拒み、`")"` を残します: 3 − 1 = 位置 2。`"[oops"` では、クラスのパーサが閉じの `]` を求めて失敗し、バックトラックが `[` の手前まで巻き戻します — 何ひとつ消費されません: 5 − 5 = 位置 0、開きブラケットです。期待値 2 つに、引き算 1 回。(`Nothing` の枝は念には念を、というものです。アトム 0 個の並びは `Eps` なので、いま書かれているいちばん上の規則は常に成功します — それでも `case` は網羅的でなければならず、誠実なコードは「ありえない」と断言して片付ける代わりに、そのケースを扱います。`compile` に明示的な `covering` が付いていることにも注目してください。パーサを呼ぶ以上、全域性についてのパーサの正直さも一緒に旅をするのです。)

### 表面の残り

```idris
||| Does the regex match the *whole* input? A synonym for
||| `Regex.Core.matches`, under the name users expect.
export
match : Regex -> String -> Bool
match = matches
```

たった 1 行の改名ですが、それでも持つ価値があります。API とは語彙であり、`match` はユーザーが最初に当てずっぽうで打つ単語だからです。

```idris
||| Does the regex match *somewhere inside* the input?
|||
||| No new machinery: searching for `r` is matching `.*r.*` against
||| the whole string.
export
contains : Regex -> String -> Bool
contains r = matches (cat dotStar (cat r dotStar))
  where
    dotStar : Regex
    dotStar = star (Sym anyChar)
```

アンカーなしの検索は、新しいエンジン機能のように聞こえます — パターンを入力に沿って滑らせて、開始位置を片っ端から試す必要があるのでは?ありません。「`r` のマッチを含む」は、「文字列全体が `.*r.*` にマッチする」と*完全に*同じです。何でも、それからパターン、それから何でも。`dotStar` は `star (Sym anyChar)` — 何章も前から持っている部品でできています。この機能は定義なのです — [糖衣構文の章](./12-sugar.md) の設計の教訓が、API のレベルでもまだ配当を払い続けています。

```idris
||| Compile and search in one call — for the quick, one-shot cases.
export
covering
test : (pattern : String) -> (input : String) -> Either CompileError Bool
test pattern input = map (\r => contains r input) (compile pattern)
```

`test` は前半と後半を合成します — そして*どうやって*合成しているかを見てください。`compile pattern` は `Either CompileError Regex` で、`Either e` は `Functor` です。`Parser` がそうだったのと同じように。その `map` は `Right` の値を変換し、`Left` は手つかずのまま素通しします。だから `map (\r => contains r input)` はこう読めます。コンパイルが成功したら、その正規表現で検索を走らせる。失敗したら、エラーはそのまま伝わる。スペック `test "[oops" "anything"` は、`case` がひとつも見当たらないのに `Left (MkCompileError 0 ...)` を受け取ります。一度学んだインターフェースは、予定していなかった場所に現れ続けるのです。

```sh
make test
```

```
  ...
  ok    compile accepts a well-formed pattern
  ok    compile reports the position where parsing gave up
  ok    an unterminated class fails at its opening bracket
  ok    match is whole-string
  ok    contains searches anywhere in the input
  ok    contains still rejects when nothing matches
  ok    test compiles and searches in one call
  ok    test reports non-matches as Right False
  ok    test propagates compile errors
130/130 passed
```

これはコミット [36533d1](https://github.com/ubugeeei-prod/lets-start-functional/commit/36533d12bbf392e6973789e96ecd124d8cd295ef) です。

## 書いたものではなく、設計したもの

この章にあるものは、ほとんど何ひとつアルゴリズムではありません。あるのは決断の集まりです:

- **境界は明示的。** `import public` と `import` の違いが、ユーザーの語彙と私たちの配管とのあいだに線を引きます。いつかパーサを書き直しても、ユーザーのコードが気づくことはありえません — 内部への扉は、最初から開いていないのですから。
- **エラーは値。** `position` フィールドを持つレコードなら、エディタにも REPL にも言語サーバにも食わせられます。整形済みの文字列を食わせられる先は `putStrLn` だけ。人間のために `Show` を実装しつつ、それ以外のみんなのために構造を残しました。
- **位置は努力ではなく設計から出てきた。** 私たちのコンビネータの失敗が「例外を投げる」ではなく「止まって残り物を返す」だったから、エラー位置は引き算で復元できました。単純な意味論は複利で効きます。2 章前の決断が、この章の目玉機能を手渡してくれたのです。
- **機能は定義のまま。** `contains` は `.*r.*`。`test` は `map` ひとつ。`match` は改名。コアは 1 ミリも動いていません。

## まとめ

- ユーザーにとっては、いまや `import Regex` が話のすべてです。`import public` が AST・文字集合・糖衣構文を再エクスポートし、パーサのモジュールは非公開の配管にとどまります。
- `CompileError` はレコード — 位置とメッセージ — です。エラーはまずツールのためのデータであり、人間のための散文はその次だからです。
- 位置のトリック: バックトラックするパーサは途中で死なず、消費をやめるだけ。`length input - length leftover` が*そのまま*エラー位置です。`"ab)"` は 2 で、`"[oops"` は 0 で失敗します。
- `match` は `matches` の改名。`contains r` はただの `.*r.*` — 新しいエンジンコードがゼロの、アンカーなし検索です。
- `test` は `Either` の上に map します。`Either` は `Parser` と同じく `Functor` — コンパイルエラーは `case` なしで `map` を素通りして伝わります。

エンジンに正面玄関ができました — そして `Show` や `Eq` や `Functor` の仲間たちをずいぶん使い込んできたので、そろそろこの機構ときちんと対面するときです。[インターフェースとふたつのモノイド](./16-interfaces.md) へ。
