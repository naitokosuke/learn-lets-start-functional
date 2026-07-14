---
title: 糖衣構文はただの関数
description: エンジンに一切触れずに +、?、{n,m}、文字列リテラルを追加します — どれも 6 つのコアコンストラクタへとコンパイルされる小さな関数です。
---

# 糖衣構文はただの関数

どの正規表現方言にも `+` と `?` と `{n,m}` があるのに、私たちの AST にはどれもありません。この章ではエンジンに触れることなく、その全部を追加します — なぜなら、どれも新機能ではないからです。

## 新しいマッチ能力はない

`a+` の意味を考えてみましょう。「1 個以上の `a`」。でもそれは「`a` のあとに 0 個以上の `a`」— つまり `a·a*` そのものです。`a?` —「0 個か 1 個」— は選択 `a|ε` そのもの。`a{3}` は `a·a·a`。こうした便利な記法はどれも、すでに持っている 6 つのコンストラクタで*定義*できます。増えるのは記法であって、能力ではないのです。

ここから、機能セットを育てる意図的に関数型なやり方が見えてきます。コア言語は最小に保ち、それ以外はすべて定義にする。エンジン — `nullable`、`deriv`、`matches` — が `plus` の存在を知ることは決してなく、知る必要もありません。関数である機能には、どこにも新しいケースが要らず、マッチャの変更も要らず、あとで証明を始めたときに新しい証明も要りません。これは数学を扱いやすく保っているのと同じ設計です。一握りの公理があり、残りはすべて定理なのです。

## Red: 便利レイヤのスペック

新しいスペックファイル `regex/tests/src/Spec/Sugar.idr` です。スペックは 2 種類あります。*振る舞い*を確かめるもの(`a+` は空文字列を拒否するか?)と、*定義そのもの*を確かめるもの — `plus r` は文字どおり木 `Cat r (Star r)` であるべし、というものです:

```idris
||| Specs for `Regex.Sugar` — the convenience layer.
|||
||| `+`, `?`, `{n,m}` and string literals add no new matching power:
||| they are ordinary functions that *compile down* to the six core
||| constructors. Sugar is cheap when it is just functions.
module Spec.Sugar

import Harness
import Regex.Core
import Regex.Set
import Regex.Sugar

export
sugarSpecs : List Spec
sugarSpecs =
  [ -- plus: one or more
    shouldBe "plus r is literally r followed by r*"
      (plus (lit 'a')) (Cat (lit 'a') (Star (lit 'a')))
  , it "a+ needs at least one a"
      (not (matches (plus (lit 'a')) ""))
  , it "a+ matches one or many"
      (matches (plus (lit 'a')) "a" && matches (plus (lit 'a')) "aaaa")

    -- opt: zero or one
  , shouldBe "opt r is literally a choice between r and Eps"
      (opt (lit 'a')) (Alt (lit 'a') Eps)
  , it "a? matches zero or one a, never two"
      (matches (opt (lit 'a')) ""
        && matches (opt (lit 'a')) "a"
        && not (matches (opt (lit 'a')) "aa"))

    -- literal: a whole string, character by character
  , it "literal matches exactly its own string"
      (matches (literal "abc") "abc" && not (matches (literal "abc") "abd"))
  , shouldBe "the empty literal is Eps"
      (literal "") Eps
```

続いて回数指定の繰り返し — `{n}`、`{n,}`、`{n,m}` を、意味をそのまま名前にした関数として:

```idris
    -- counted repetition
  , it "exactly 3 means three, no more, no fewer"
      (matches (exactly 3 (lit 'a')) "aaa"
        && not (matches (exactly 3 (lit 'a')) "aa")
        && not (matches (exactly 3 (lit 'a')) "aaaa"))
  , it "atLeast 2 rejects one but accepts many"
      (not (matches (atLeast 2 (lit 'a')) "a")
        && matches (atLeast 2 (lit 'a')) "aa"
        && matches (atLeast 2 (lit 'a')) "aaaaaa")
  , it "between 2 4 accepts two through four"
      (not (matches (between 2 4 (lit 'a')) "a")
        && matches (between 2 4 (lit 'a')) "aa"
        && matches (between 2 4 (lit 'a')) "aaa"
        && matches (between 2 4 (lit 'a')) "aaaa"
        && not (matches (between 2 4 (lit 'a')) "aaaaa"))
```

そして、このファイルの主役。この章と[前の章](./11-character-classes.md)で作ったものを総動員して組み立てる、本物のパターンです。`where` ブロックで読みやすさを保ちます:

```idris
    -- sugar composes with everything else
  , it "\\d{4}-\\d{2}-\\d{2} matches a date"
      (matches datePattern "2026-07-14")
  , it "the date pattern rejects a malformed date"
      (not (matches datePattern "2026-7-14"))
  ]
  where
    datePattern : Regex
    datePattern =
      cat (exactly 4 (Sym digit))
        (cat (lit '-')
          (cat (exactly 2 (Sym digit))
            (cat (lit '-') (exactly 2 (Sym digit)))))
```

これは `\d{4}-\d{2}-\d{2}` を関数呼び出しで書いたものです。打つのが面倒なのは認めます — 本物の記法のためのパーサこそ、この本がこれから向かう先です — が、すでに存在する部品と、この章がこれから定義する部品だけで組み上がっていることに注目してください。

```sh
make test
```

```
Error: Module Regex.Sugar not found

Spec.Sugar:11:1--11:19
 07 |
 08 | import Harness
 09 | import Regex.Core
 10 | import Regex.Set
 11 | import Regex.Sugar
      ^^^^^^^^^^^^^^^^^^
```

Red です。これはコミット [fd88430](https://github.com/ubugeeei-prod/lets-start-functional/commit/fd884309997293e9d23d216b2f43448eca8f9385) です。

## Green: 定義でできたモジュール

`regex/src/Regex/Sugar.idr` は設計宣言で幕を開け、あとは 1 行定義を次々に届けます:

```idris
||| The convenience layer: `+`, `?`, `{n,m}` and string literals.
|||
||| None of these add matching power — each one is a small function
||| that builds on the six core constructors. This is a deliberately
||| functional way to design a feature: keep the core minimal, and
||| let everything else be *definitions*, not new machinery.
module Regex.Sugar

import Regex.Core
import Regex.Set

%default total

||| One or more repetitions: `r+` is `r` followed by `r*`.
public export
plus : Regex -> Regex
plus r = cat r (star r)

||| Zero or one: `r?` is a choice between `r` and the empty string.
public export
opt : Regex -> Regex
opt r = alt r Eps
```

どの定義も、仕様を声に出して読み上げたそのままの姿をしています。スマートコンストラクタ `cat`、`alt`、`star` で組み立てている点にも注目してください — 糖衣構文は [スマートコンストラクタ](./10-smart-constructors.md) の単純化の代数をタダで受け取るのです。

### 文字列リテラル: fold が木を組み立てる

```idris
||| Match a whole string, character by character.
|||
||| A right fold turns `"abc"` into `a · (b · (c · ε))` — the same
||| shape you would have written by hand.
public export
literal : String -> Regex
literal s = foldr (cat . lit) Eps (unpack s)
```

`foldr` の働きを眺めてみましょう。リストのすべての cons を `cat . lit` に、最後の nil を `Eps` に置き換えます:

```
unpack "abc"        =  'a' :: ('b' :: ('c' :: []))
literal "abc"       =  cat (lit 'a')
                          (cat (lit 'b')
                             (cat (lit 'c') Eps))
```

リスト自身の構造が、そのまま正規表現の構造*そのもの*であり、fold(畳み込み)は継ぎ目の名前を付け替えているだけです。これは fold の何度も出てくる持ち味です — 「文字列をループして木を組み上げる」と書くことはめったになく、cons と nil が何に化けるべきかを言うだけ。そして空文字列のケースには特別扱いが要りません。`[]` に対する `foldr` は種(seed)である `Eps` そのもので、それは「空文字列にマッチ」のコンパイル結果としてまさに正しい答えです。スペック `shouldBe "the empty literal is Eps"` は、作りからして自動的に通ります。

### 回数指定の繰り返し: 数もまたデータ

```idris
||| Exactly `n` repetitions: `r{n}`.
|||
||| Recursion on a `Nat` is pattern matching like any other:
||| zero repetitions match the empty string, and `S k` repetitions
||| are one `r` followed by `k` more.
public export
exactly : Nat -> Regex -> Regex
exactly Z     _ = Eps
exactly (S k) r = cat r (exactly k r)
```

[Idris 速習コース](./04-idris-crash-course.md) を思い出してください。`Nat` は普通のデータ型で、`Z`(ゼロ)か `S k`(`k` の次の数)です。だから*数*に対して、`Regex` と寸分違わぬやり方でパターンマッチできます。0 回の繰り返しは `Eps`。`S k` 回の繰り返しは、`r` 1 個のあとに `k` 回ぶん。ループカウンタもミューテーションもなし — 数が木へとほどけていき、再帰呼び出しのたびに `Nat` が確実に小さくなるので、全域性チェッカー(totality checker)も満足します。

`atLeast` は、そこから転がり出てきます:

```idris
||| At least `n` repetitions: `r{n,}` is `n` copies, then `r*`.
public export
atLeast : Nat -> Regex -> Regex
atLeast n r = cat (exactly n r) (star r)
```

### upTo: 入れ子が肝心

`{n,m}` の最後のピースは「最大 `k` 回の*省略可能な*繰り返し」で、ここには足を止める価値のある機微があります:

```idris
||| Up to `n` optional repetitions.
|||
||| The nesting matters: `upTo 2 r` is `(r (r)?)?`, so each extra
||| repetition is only allowed after the previous one appeared.
upTo : Nat -> Regex -> Regex
upTo Z     _ = Eps
upTo (S k) r = opt (cat r (upTo k r))
```

つい書きたくなる誤答は「省略可能なコピーを `k` 個並べる」、つまり `r? r? … r?` です。単にマッチさせるだけなら、たまたま同じ文字列を受理します — でも*形*が間違っています。この書き方は各繰り返しが独立だと言っていますが、`{n,m}` の真実は「3 回目の繰り返しは、2 回目が起きたときにだけ意味を持つ」です。`upTo` は代わりに入れ子にします。`upTo 2 r` は `(r (r)?)?` — `r` と、*さらにもうひとつ*の省略可能なグループを含む、省略可能なグループです。内側の繰り返しには、外側を通ってしか入れません。データの構造が繰り返し同士の依存関係をそのまま映していて、これは(たとえばプリティプリンタのような)マッチャ以外のツールがこの木を読み始めたとき、まさに欲しくなる性質です。

`upTo` に `public export` が付いていないことにも注目してください — これは非公開のヘルパです。公開の顔は `between` です:

```idris
||| Between `n` and `m` repetitions: `r{n,m}` is `n` required copies
||| followed by `m - n` optional ones. (If `m < n`, natural-number
||| subtraction truncates to zero and this means exactly `n`.)
public export
between : (n : Nat) -> (m : Nat) -> Regex -> Regex
between n m r = cat (exactly n r) (upTo (m `minus` n) r)
```

`Nat` の `minus` はゼロを下回れません — 行き先になる負の `Nat` が存在しないのです。だから `between 4 2` のような無茶な要求は、静かに `exactly 4` に切り詰められます。それを doc コメントに書いておくのが誠実というものです。(Idris の型には、そうした呼び出しを最初から*禁止*するだけの表現力があります — 引数として `n <= m` の証明を要求すればいい — でも切り詰めも立派に全域(total)な答えですし、この本は戦う場所を選びます。)

```sh
make test
```

```
  ...
  ok    plus r is literally r followed by r*
  ok    a+ needs at least one a
  ok    a+ matches one or many
  ok    opt r is literally a choice between r and Eps
  ok    a? matches zero or one a, never two
  ok    literal matches exactly its own string
  ok    the empty literal is Eps
  ok    exactly 3 means three, no more, no fewer
  ok    atLeast 2 rejects one but accepts many
  ok    between 2 4 accepts two through four
  ok    \d{4}-\d{2}-\d{2} matches a date
  ok    the date pattern rejects a malformed date
87/87 passed
```

これはコミット [1fe9416](https://github.com/ubugeeei-prod/lets-start-functional/commit/1fe941690555c604723d0b381e6e759a568ca42d) です。

## 言語がいま何をしてくれたのか

この章が*必要としなかった*ものを数えてみてください。`Regex` の変更なし。`nullable` にも `deriv` にも新しいケースなし。`matches` の変更なし。新しいインターフェースなし。新しい関数が 6 つ、コメント込みで 60 行。それでエンジンの機能リストはおよそ倍になりました。「糖衣構文はただの関数」が買ってくれるのは、これです。

この設計には、静かな保証もひとつ隠れています。`plus` や `opt` の仲間たちは 6 つのコアコンストラクタでできた木*しか*生み出さないので、コアについて今後確立するあらゆる性質 — [テストが定理になる](./18-proofs.md) でやってくる機械検証された証明も含めて — は、自動的にすべての糖衣構文をカバーします。定義である機能は、定義のよりどころから正しさを相続するのです。

> [!TIP]
> 自分のライブラリを設計するとき、このパターンは盗む価値があります。ほかのすべてをその言葉で*定義*できる最小のコアを見つけ、親しみやすい表層は、その上の素の関数として育てる。コアはテスト可能・証明可能なまま、表層は安上がりなままです。

## まとめ

- `+`、`?`、`{n}`、`{n,}`、`{n,m}`、文字列リテラルが増やすのは記法であってマッチ能力ではありません — どれも 6 つのコアコンストラクタへとコンパイルされる素の関数です。
- `literal` は、リストの継ぎ目の名前を付け替える `foldr` です。`"abc"` は `a · (b · (c · ε))` になり、空文字列はタダで `Eps` になります。
- `exactly` は `Nat` の上で再帰します — 数はデータなので、数えることはパターンマッチです。
- `upTo` は選択肢を入れ子にします — `(r (r)?)?` — ので、追加の繰り返しはひとつ前の繰り返しに依存します。`between n m` は必須のコピー `n` 個と省略可能な `m - n` 個で、`Nat` の引き算は切り詰め方式です。
- エンジンはこの一部始終をまったく知りません。そして、それこそがポイントです。

日付パターンを関数呼び出しで書くのは、やはり骨が折れました — 次は、ユーザーが `\d{4}-\d{2}-\d{2}` を直接書けるようにする道具を作ります。まずは [パーサコンビネータ](./13-parser-combinators.md) からです。
