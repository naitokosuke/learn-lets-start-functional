---
title: パーサコンビネータ
description: パーサコンビネータライブラリをゼロから作り、Functor・Applicative・Monad・Alternative をひとつの具体的な型の上で自分のものにします。
---

# パーサコンビネータ

ユーザーは正規表現を文字列で書きます — `(colou?r|gr[ae]y)` — そして私たちは、その文字列を木に変えなければなりません。ひとつの大きなパーサを書く代わりに、パーサの*部品*の小さなライブラリを作ります。そしてその過程で、あの怖い名前のインターフェースたちを、ついに自分のものにします。

## パーサはただの関数

すべてを剥ぎ取って、問うてみましょう。パーサは何を*する*のか?入力の文字たちを受け取ります。そして失敗するか、値を生み出すか — さらに肝心なことに、消費しなかった残りの入力も一緒に返します。次のパーサが続きから拾えるように。型で書くと:

```idris
||| A parser of `a`s: consume characters, maybe produce an `a`
||| and the unconsumed rest.
public export
record Parser a where
  constructor MkParser
  runParser : List Char -> Maybe (a, List Char)
```

秘密はこれで全部です。`Parser Char` は関数 `List Char -> Maybe (Char, List Char)` です。状態を持つオブジェクトでもなければ、生成されたテーブルでもない — 関数です。インターフェースの実装をぶら下げられるように、レコードで包んであるだけ。

この章の計画こそ、コンビネータを有名にしたものです。ごく*小さな*パーサをいくつか書き(1 文字、述語を満たす 1 文字)、そのあと `Parser` に 4 つの標準インターフェースを実装することで、連接・選択・繰り返し — 文法の道具一式 — を手に入れます。`Functor` や `Monad` という単語に追い払われて関数型プログラミングから遠ざかったことがあるなら、この章でそれらは単語であることをやめ、「残りの入力」にまつわる 4 つの短いコード片になります。

## Red: インターフェースを要求するスペック

`regex/tests/src/Spec/Parse.idr` を、一字一句そのまま:

```idris
||| Specs for `Regex.Parse` — a parser-combinator library from scratch.
|||
||| A `Parser a` is just a function from input to "maybe a result and
||| the leftover input". Everything else — sequencing, choice,
||| repetition — falls out of implementing the standard interfaces.
module Spec.Parse

import Harness
import Regex.Parse

export
parseSpecs : List Spec
parseSpecs =
  [ shouldBe "char consumes exactly its character"
      (parse (char 'a') "a") (Just 'a')
  , shouldBe "char rejects the wrong character"
      (parse (char 'a') "b") Nothing
  , shouldBe "parse demands that all input is consumed"
      (parse (char 'a') "ab") Nothing
  , shouldBe "map transforms a result (Functor)"
      (parse (map toUpper (char 'a')) "a") (Just 'A')
  , shouldBe "sequencing keeps both results (Applicative)"
      (parse [| MkPair (char 'a') (char 'b') |] "ab") (Just ('a', 'b'))
  , shouldBe "choice takes the first branch that succeeds (Alternative)"
      (parse (char 'a' <|> char 'b') "b") (Just 'b')
  , shouldBe "many matches zero occurrences"
      (parse (many (satisfy isDigit)) "") (Just [])
  , shouldBe "many matches as many occurrences as it can"
      (parse (many (satisfy isDigit)) "123") (Just ['1', '2', '3'])
  , shouldBe "some demands at least one occurrence"
      (parse (some (satisfy isDigit)) "") Nothing
  , shouldBe "natural reads a number (Monad, do-notation inside)"
      (parse natural "2026") (Just 2026)
  , shouldBe "combinators compose: a natural between parentheses"
      (parse (char '(' *> natural <* char ')') "(42)") (Just 42)
  ]
```

このリストは願いごとリストとして読んでください。願いひとつにつき、インターフェースひとつです:

- 最初の 3 つが求めているのはプリミティブです。`char` と、残った入力を失敗として扱う `parse`。
- 「map transforms a result」が求めるのは **Functor**: パーサを走らせ、生み出されたものに関数を適用する。
- 「sequencing keeps both results」が求めるのは **Applicative**: 2 つのパーサを順に走らせ、1 つ目の残り入力を 2 つ目へ食わせる。(`[| MkPair p q |]` は新しい構文です — 追って説明します。)
- 「choice takes the first branch that succeeds」が求めるのは **Alternative** と、その演算子 `<|>`。
- `many` と `some` が求めるのは繰り返し — パース界の `*` と `+`、0 回以上と 1 回以上です。
- `natural` が求めるのは **Monad**: 複数のパース手順を `do` で貼り合わせ、あとの手順が前の結果を見られるようにする。
- 最後のスペックはご褒美です。`char '(' *> natural <* char ')'` は、それがパースする文法そのものにほとんど読めます。`*>` と `<*` は「順に実行し、矢印の指す側の結果を残す」— どちらも Applicative から自動で付いてきます。

```sh
make test
```

```
Error: Module Regex.Parse not found

Spec.Parse:9:1--9:19
 5 | ||| repetition — falls out of implementing the standard interfaces.
 6 | module Spec.Parse
 7 |
 8 | import Harness
 9 | import Regex.Parse
     ^^^^^^^^^^^^^^^^^^
```

Red です。これはコミット [2f2adb1](https://github.com/ubugeeei-prod/lets-start-functional/commit/2f2adb1c70dceb08238d9831b5be61e722d046ce) です。

## Green: プリミティブ

`regex/src/Regex/Parse.idr` は、すでに見たレコードで始まり、続いてランナーが来ます:

```idris
||| Run a parser against a whole string. Succeeds only when every
||| character is consumed — leftovers mean the parse failed.
public export
parse : Parser a -> String -> Maybe a
parse p s =
  case runParser p (unpack s) of
    Just (a, []) => Just a
    _            => Nothing
```

`Just (a, [])` というパターンが取り締まりをしています。結果*と*空の残りリスト、それ以外は取引不成立。`parse (char 'a') "ab"` が `Nothing` になるのはこのためです — `'b'` は消費されずじまいで、末尾のゴミは肩をすくめて流すものではなく、パースの失敗なのです。

手書きするプリミティブなパーサは、この 2 つが最初で最後です:

```idris
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
```

この章の残りすべて — そして次章のパターンパーサ全体 — は、この 2 つを*組み合わせて(combine)*作られます。コンビネータという名前の由来です。

## インターフェースのはしご

ここからは 4 つの実装を、力の増す順に見ていきます。それぞれについて、コードと、それがスペックの中で買ってくれるものをひとつずつ。

### Functor: 結果を変換する

```idris
public export
Functor Parser where
  map f p = MkParser $ \cs =>
    case runParser p cs of
      Just (a, rest) => Just (f a, rest)
      Nothing        => Nothing
```

`p` を走らせ、成功していたら値に `f` を適用し、残り入力はそのままにする。`Functor` の意味はこれだけです。「この型には `map` がある」。リストにもあり、`Maybe` にもあり、いまやパーサにもある — だからこそスペックは `map toUpper (char 'a')` と書くだけで、新しい仕掛けなしに大文字のパーサを手にできるのです。

### Applicative: 連接

```idris
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
```

部品は 2 つ。`pure a` は何も消費せず `a` で成功するパーサです — これがどれほど頻繁に役立つか、きっと驚きますよ。`<*>` が連接です。最初のパーサを走らせ、*その残り入力を 2 つ目へ糸のように通し*、最初の結果(関数)を 2 つ目の結果に適用する。この `rest` の糸通しこそ、パースという営みの規律を明示的に書き下したものです — グローバルなカーソルもミュータブルな位置もなく、ただ値が受け渡されていくだけ。

スペックの見慣れない `[| MkPair (char 'a') (char 'b') |]` が必要としていたのがこれです。`[| ... |]` は**イディオムブラケット(idiom brackets)**という、Applicative の連接のための Idris の糖衣構文です。`[| f p q |]` は `pure f <*> p <*> q` の意味 — `p` を走らせ、次に `q`、そして両者の結果を `f` で組み合わせる。`f` を `MkPair` にすれば、`'a'` を、次に `'b'` をパースして両方を残せます。そして Applicative がありさえすれば、標準ライブラリが `*>` と `<*`(順に実行し、片側を捨てる)をおまけに付けてくれます — 最後のスペックの、括弧に挟まれた自然数は、丸ごとこのブロックの力で動いているのです。

### Monad: 次のパーサが直前の結果に依存できる

```idris
public export
Monad Parser where
  p >>= f = MkParser $ \cs =>
    case runParser p cs of
      Nothing        => Nothing
      Just (a, rest) => runParser (f a) rest
```

第 2 引数の型を見てください。`f` は*パーサを返す関数*です。Applicative が走らせるのは、あらかじめ決められたパーサの固定パイプライン。Monad は、ひとつのパースの結果に、次に何をパースするかを**選ばせて**くれます。これは厳密に大きな力であり、`do` 記法が脱糖される先の形そのものでもあります — `do` ブロックの `x <- p` の行は、一行一行が `>>=` なのです。[次の章](./14-pattern-syntax.md) では、`{` の後に続くものがその中身次第で変わる場面で、これに思い切り寄りかかります。

### Alternative: だめならこっち

```idris
public export
Alternative Parser where
  empty = MkParser $ \_ => Nothing
  p <|> q = MkParser $ \cs =>
    case runParser p cs of
      Just res => Just res
      Nothing  => runParser q cs
```

`empty` は常に失敗するパーサです。`<|>` は `p` を試し、失敗したら `q` を試します — ここで注目してほしいのは、`p` が息絶える前に食い散らかした入力ではなく、*元の*入力 `cs` に対して試すことです。私たちのパーサはすべての選択点で完全にバックトラックし、おかげで意味論は徹底的に単純に保たれます。失敗した枝は決して足跡を残さない。これがスペックの `char 'a' <|> char 'b'` を買い、次章の文法の選択肢を買ってくれます。

> [!NOTE]
> Haskell を知っているなら: いま目撃したのは、Parsec の曽祖父母の誕生です。産業用のコンビネータライブラリはエラーメッセージやストリーミングや性能の技を積み増しますが、その土台は上とまったく同じ 4 つのインスタンス — およそ 100 行の世界です。

## 繰り返し、そして告白

```idris
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
```

互いに寄りかかり合う 2 つの定義です。*1 回以上*は、1 回、そのあと 0 回以上。*0 回以上*は、1 回以上、さもなくば空リスト。`[| p :: many p |]` はまたイディオムブラケットです — `p` をひとつパースし、残りをパースし、cons でつなぎます。

さて、告白です。これらの関数には `total` ではなく `covering` の印が付いています — そう書けと Idris に言われたのです。理由はこうです。`many p` が停止するのは、`p` が成功のたびに入力を消費する場合だけ。消費*せずに*成功するパーサ — たとえば `pure ()` — を食わせれば、`many (pure ())` は永遠にループします。常に成功し、一歩も進まずに。Idris の全域性チェッカーは、与えた型からそれを排除できないので、`total` の判を押すことを拒みます。`covering` は、それを声に出して認めるための言葉です。「すべてのケースは扱っている。ただし停止性はこちらの責任」。実際に `many` へ渡すパーサはどれも最低 1 文字は消費するので、実用上は安全です — でもその誠実さは、誰も確認しないコメントの中ではなく、読者の目に見えるソースの中にあります。(型で入力の消費を追跡すれば、コンビネータによるパースを完全に `total` にすることもできます。美しいうさぎの穴ですが、この本の守備範囲からはきっぱり外れます。)

最後に、Monad を要求したスペックです:

```idris
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
```

`some (satisfy isDigit)` が数字の文字たちを集め、`digitsToNat` が学校で習ったとおりのやり方でそれを数へ畳み込みます — アキュムレータを 10 倍して桁を足す。これはまさしく左畳み込み(left fold)です。位取りは、左から右へ読むことに依存しているからです。

```sh
make test
```

```
  ...
  ok    char consumes exactly its character
  ok    char rejects the wrong character
  ok    parse demands that all input is consumed
  ok    map transforms a result (Functor)
  ok    sequencing keeps both results (Applicative)
  ok    choice takes the first branch that succeeds (Alternative)
  ok    many matches zero occurrences
  ok    many matches as many occurrences as it can
  ok    some demands at least one occurrence
  ok    natural reads a number (Monad, do-notation inside)
  ok    combinators compose: a natural between parentheses
98/98 passed
```

これはコミット [f42babe](https://github.com/ubugeeei-prod/lets-start-functional/commit/f42babe98d53628594789591671542e4fca2419b) です。

## 言語がいま何をしてくれたのか

怖い名前たちの正体は、ひとつの具体的な型に対する能力のはしごでした:

| インターフェース | `Parser` にとっての意味…                          | 買ってくれたもの…              |
|-------------|--------------------------------------------------|--------------------------------|
| Functor     | 結果を変換する                                   | `map toUpper (char 'a')`       |
| Applicative | 残り入力を糸通ししながら順に走らせる             | `[\| ... \|]`、`*>`、`<*`      |
| Monad       | 結果に「次に何をパースするか」を選ばせる         | `do` 記法、`natural`           |
| Alternative | 一方を試し、だめならもう一方(完全バックトラック) | `<\|>`、`many`、`some`         |

どれもパーサ専用の機能ではありません。`List` や `Maybe` や `IO` が実装しているのと*同じ*インターフェースです。だからこそ、インスタンスを書いた瞬間から `map` も `do` もイディオムブラケットもパーサの上で動いたのです。インターフェースを一度学べば、それを実装するすべての型には、あなたがすでに話せる語彙が最初から備わっています。この仕組み自体は、専用の章 [インターフェースとふたつのモノイド](./16-interfaces.md) でじっくり掘り下げます — でもあなたはもう、それを*使った*のです。チュートリアルがたいてい飛ばす部分を。

## まとめ

- `Parser a` は関数ひとつを包んだレコードです: `List Char -> Maybe (a, List Char)` — 結果と残り入力、さもなくば失敗。
- `parse` は完全消費を要求します: `Just (a, [])` か `Nothing` か。
- 手書きのパーサは `satisfy` と `char` だけ。残りはすべて組み合わせです。
- Functor は結果を写し、Applicative は残り入力を糸通ししながら連接し(イディオムブラケット `[| ... |]` はその糖衣構文)、Monad は結果に次のパーサを選ばせ(`do`)、Alternative は元の入力からの完全バックトラック付きの `<|>` をくれます。
- `many`/`some` は相互再帰で、正直に `covering` です。消費しないパーサはループしうるし、Idris はそう言わせました。
- `natural` = `some` で数字を集めて左畳み込み。位取りは左から右へ読むものだからです。

これでパーサ部品の袋が手に入りました。次はそれを組み立てて、正規表現の記法そのもののための完全な文法にします。[パターン構文をパースする](./14-pattern-syntax.md) へ。
