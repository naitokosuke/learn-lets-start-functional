---
title: スマートコンストラクタ
description: エンジンに正規表現の代数を少しだけ教えて、微分がガラクタを溜め込まず小さいまま保たれるようにします。
---

# スマートコンストラクタ

エンジンは動いています。しかしその微分結果は `Cat Fail (Star (Lit 'a'))` のようなガラクタだらけです。この章ではコンストラクタにちょっとした代数を教えます。すると、ガラクタはそもそも存在しなくなります。

## 絨毯の下に掃き込んでいたガラクタ

[微分](./08-derivatives.md) の章で、私たち自身のスペックのひとつがこんな期待値を固定していました:

```idris
  , shouldBe "a nullable head lets the character reach the tail too"
      (deriv 'b' (Cat (Star (Lit 'a')) (Lit 'b')))
      (Alt (Cat (Cat Fail (Star (Lit 'a'))) (Lit 'b')) Eps)
```

この期待値をよく見てください。`a*b` を `'b'` で微分したのですから、正直な答えは「空文字列」です — `b` は消費され、あとには何も残りません。ところが得られた木は、それをこれ以上ないほど回りくどく言っています。`Fail` で始まる(したがって何にもマッチしえない)枝、*または* `Eps`、と。

それでもエンジンは正しい判定を返します。`nullable` が木全体を辛抱強く歩いてくれるからです。しかし `deriv` を呼ぶたびに木は前より大きくなり、死んだ枝は決して刈り込まれません。長い文字列をマッチさせれば、微分は雪だるま式に膨らみます。理論は線形時間だと言っている。木はそうは言っていない。

## ちょっとした正規表現の代数

直し方は少しも巧妙ではありません。頭の中で確かめられる、ほんの一握りの事実だけです:

- `Fail` は連接(sequencing)に対して*吸収的(absorbing)*です。「無」のあとに何を続けても「無」のまま。`Cat Fail r` も `Cat r Fail` も、マッチする集合は空です。
- `Eps` は連接の*単位元(identity)*です。空文字列に `r` を続ければ、それはただの `r`。
- `Fail` は選択(choice)の*単位元*です。不可能な枝は捨ててかまいません。`Alt Fail r` はただの `r`。
- 「無」のスター — あるいは空文字列のスター — が生み出せるのは空文字列だけです。`Star Fail` も `Star Eps` も `Eps`。
- 二重のスターはつぶれます。`Star (Star r)` がマッチするものは `Star r` と寸分違いません。

これが算術のように読めたなら — ゼロに何を掛けてもゼロ、1 掛ける `r` は `r` — それは偶然ではありません。正規表現は代数をなしていて、`Fail` がゼロの役、`Eps` が 1 の役を演じているのです。

これまでのコードは、生のコンストラクタ `Cat`、`Alt`、`Star` で木を組み立てていました。これらは渡されたものを、ガラクタも含めてそっくりそのまま記録します。関数型らしい一手は、木を普通の小文字の関数 — `cat`、`alt`、`star` — を通して組み立てることです。同じ形を作りつつ、*組み立てながら*代数を適用する関数たちです。コンストラクタの役を演じながら、先に考えることを許された関数 — これを**スマートコンストラクタ(smart constructor)**と呼びます。

## Red: cat・alt・star のスペック

上の代数は、一行ずつそのままスペックに翻訳できます。`regex/tests/src/Spec/Core.idr` の末尾に追加します:

```idris
||| Smart constructors: `cat`, `alt` and `star` build the same six
||| shapes, but simplify the obvious algebra on the way —
||| so derivatives stay small instead of accumulating junk.
export
smartSpecs : List Spec
smartSpecs =
  [ shouldBe "Fail swallows a sequence from the left"
      (cat Fail (Lit 'a')) Fail
  , shouldBe "Fail swallows a sequence from the right"
      (cat (Lit 'a') Fail) Fail
  , shouldBe "sequencing with the empty string is a no-op (left)"
      (cat Eps (Lit 'a')) (Lit 'a')
  , shouldBe "sequencing with the empty string is a no-op (right)"
      (cat (Lit 'a') Eps) (Lit 'a')
  , shouldBe "anything else still nests as Cat"
      (cat (Lit 'a') (Lit 'b')) (Cat (Lit 'a') (Lit 'b'))
  , shouldBe "a choice against Fail picks the live branch (left)"
      (alt Fail (Lit 'a')) (Lit 'a')
  , shouldBe "a choice against Fail picks the live branch (right)"
      (alt (Lit 'a') Fail) (Lit 'a')
  , shouldBe "identical branches collapse"
      (alt (Lit 'a') (Lit 'a')) (Lit 'a')
  , shouldBe "anything else still nests as Alt"
      (alt (Lit 'a') (Lit 'b')) (Alt (Lit 'a') (Lit 'b'))
  , shouldBe "the star of Fail can only match the empty string"
      (star Fail) Eps
  , shouldBe "the star of Eps is just Eps"
      (star Eps) Eps
  , shouldBe "a double star collapses to a single one"
      (star (Star (Lit 'a'))) (Star (Lit 'a'))
  , shouldBe "anything else still wraps in Star"
      (star (Lit 'a')) (Star (Lit 'a'))
  ]
```

「それ以外(anything else)」のケースに注目してください。スマートコンストラクタも、やはりコンストラクタでなければなりません。どの代数も当てはまらないとき、`cat` は素の `Cat` を組み立てる。それだけです。

`Main.idr` のスペックの山に `++ smartSpecs` を積み増して、実行します:

```sh
make test
```

```
Error: While processing right hand side of smartSpecs. Undefined name star.

Spec.Core:111:8--111:12
 107 |       (star Eps) Eps
 108 |   , shouldBe "a double star collapses to a single one"
 109 |       (star (Star (Lit 'a'))) (Star (Lit 'a'))
 110 |   , shouldBe "anything else still wraps in Star"
 111 |       (star (Lit 'a')) (Star (Lit 'a'))
              ^^^^
Did you mean: Star?
```

Red です — 関数はまだ存在しません。(ええコンパイラさん、でも `Star` のつもりでは*なかった*んです。むしろそこがポイントなので。)

これはコミット [dc19adf](https://github.com/ubugeeei-prod/lets-start-functional/commit/dc19adfdc758475c87dce8f5613bb820fad1fe28) です。

## Green: 3 つの関数、それぞれにパターンマッチをひとつ

代数の事実がひとつずつ、`regex/src/Regex/Core.idr` の等式ひとつになります:

```idris
||| Sequence two regexes — but simplify the obvious cases.
|||
||| These "smart constructors" use two bits of regex algebra:
|||
||| - `Fail` is *absorbing*: nothing followed by anything is nothing.
||| - `Eps` is the *identity*: the empty string followed by `r` is `r`.
|||
||| Why bother? `deriv` builds new regexes out of old ones, and
||| without simplification the results grow junk like
||| `Alt (Cat Fail r) Eps` at every step. Simplifying while building
||| keeps every derivative small — which is what makes the engine
||| fast in practice, not just in theory.
public export
cat : Regex -> Regex -> Regex
cat Fail _   = Fail
cat _   Fail = Fail
cat Eps r    = r
cat r   Eps  = r
cat l   r    = Cat l r

||| Choose between two regexes — but simplify the obvious cases.
|||
||| `Fail` is the identity of choice (an impossible branch can be
||| dropped), and choosing between two identical regexes is no
||| choice at all.
public export
alt : Regex -> Regex -> Regex
alt Fail r    = r
alt l    Fail = l
alt l    r    = if l == r then l else Alt l r

||| Repeat a regex — but simplify the obvious cases.
|||
||| Repeating the impossible (or the empty string) zero-or-more
||| times can only ever produce the empty string, and a double star
||| adds nothing a single star does not.
public export
star : Regex -> Regex
star Fail       = Eps
star Eps        = Eps
star (Star r)   = Star r
star r          = Star r
```

Idris は節(clause)を上から順に試すので、特別なケースを先に並べ、「それ以外」の節が残りを受け止めます。代数はどこかのオプティマイザの中に隠れているのではありません — 関数*そのもの*が代数なのです。

green にたどり着く途中で、ひとつ噛みつかれたことがありました。`alt` は `==` を使うので、`Eq Regex` の実装(と、道連れで移動した `Show`)はファイル内で `alt` より*上*に宣言しておく必要があったのです。Idris はモジュールを上から下へ読み、名前は使う前に定義されていなければなりません。宣言を巻き上げ(hoist)てくれる言語から来ると窮屈に感じますが、見返りとして、Idris のモジュールはいつでも頭から一直線に読めて、まだ見たことのない名前に出会うことがありません。

```sh
make test
```

```
  ok    true is true
  ...
  ok    a double star collapses to a single one
  ok    anything else still wraps in Star
  ...
56/56 passed
```

これはコミット [56bc36b](https://github.com/ubugeeei-prod/lets-start-functional/commit/56bc36b6c01f7f8ab2ce5aeb381424eec4d46e19) です。

> [!WARNING]
> `alt` をよく見てください。`l == r` というチェックがつぶしてくれるのは、*完全に*同じ木である枝だけです。`Alt a (Alt b a)` の重複した `a` はそのまま残ります。比較されるどの 2 つの枝も、いちばん外側では等しくないからです。この浅いチェックは今のところ十分です — でも覚えておいてください。[レース](./19-the-race.md) の章で、ベンチマークがまさにここで爆発し、`alt` は大人にならざるを得なくなります。

## ふたたび Red: テストはまだガラクタを文書化している

スマートコンストラクタはできましたが、まだ誰も使っていません。`deriv` は相変わらず生の `Cat`、`Alt`、`Star` で組み立てていて — そして微分のスペックは、いまだにガラクタを*期待して*います。ここにテストにまつわる不都合な真実があります。テストはドキュメントであり、いまのテストは、この散らかりようをまるで望ましい振る舞いであるかのように文書化しているのです。

というわけで、次の red ステップは新しいコードではありません — 本当に欲しい出力を記述するように、期待値を書き直すことです。スターのケースを、書き直す前と後で:

```idris
  , shouldBe "a star unrolls one repetition and keeps going"
      (deriv 'a' (Star (Lit 'a')))
      (Cat Eps (Star (Lit 'a')))
```

```idris
  , shouldBe "a star unrolls one repetition, with no Eps junk in front"
      (deriv 'a' (Star (Lit 'a')))
      (Star (Lit 'a'))
```

そして nullable な先頭のケース — この章の冒頭に出てきた騒がしい木は、`Eps` ひとつにまで畳まれます:

```idris
  , shouldBe "a nullable head lets the character reach the tail too"
      (deriv 'b' (Cat (Star (Lit 'a')) (Lit 'b')))
      (Alt (Cat (Cat Fail (Star (Lit 'a'))) (Lit 'b')) Eps)
```

```idris
  , shouldBe "a nullable head lets the character reach the tail — cleanly"
      (deriv 'b' (Cat (Star (Lit 'a')) (Lit 'b')))
      Eps
```

期待値を*先に*更新するのが、誠実さを保つコツです。`deriv` とスペックをひと息に変えてしまったら、その変更が本当に何かを変えたという証拠を目にする機会は永遠に失われます。

```sh
make test
```

```
  ...
  FAIL  a choice derives both branches — and drops the dead one
        expected Eps, got Alt Eps Fail
  FAIL  a star unrolls one repetition, with no Eps junk in front
        expected Star (Lit 'a'), got Cat Eps (Star (Lit 'a'))
  FAIL  a sequence derives its head first, simplified
        expected Lit 'b', got Cat Eps (Lit 'b')
  FAIL  a nullable head lets the character reach the tail — cleanly
        expected Eps, got Alt (Cat (Cat Fail (Star (Lit 'a'))) (Lit 'b')) Eps
  ...
52/56 passed
```

きちんと red です — そして失敗レポートは、そのまま to-do リストのように読めます。これはコミット [1c1a681](https://github.com/ubugeeei-prod/lets-start-functional/commit/1c1a6815ce8d2be4ddb707030217a54af453f49d) です。

## Green: deriv はスマートコンストラクタで組み立てる

直しは 1 ケースにつき 1 行。`deriv` が大文字のコンストラクタで組み立てていた場所を、小文字の関数に置き換えるだけです。

```idris
public export
deriv : Char -> Regex -> Regex
deriv _ Fail      = Fail
deriv _ Eps       = Fail
deriv c (Lit x)   = if c == x then Eps else Fail
deriv c (Cat l r) =
  if nullable l
    then alt (cat (deriv c l) r) (deriv c r)
    else cat (deriv c l) r
deriv c (Alt l r) = alt (deriv c l) (deriv c r)
deriv c (Star r)  = cat (deriv c r) (Star r)
```

再帰には手を触れていません。微分の数学は元のまま。賢くなったのは答えの*組み立て方*だけです。ガラクタは、掃除されるようになったのではなく — そもそも生まれなくなったのです。

```sh
make test
```

```
  ...
  ok    a choice derives both branches — and drops the dead one
  ok    a star unrolls one repetition, with no Eps junk in front
  ok    a sequence derives its head first, simplified
  ok    a nullable head lets the character reach the tail — cleanly
  ...
56/56 passed
```

これはコミット [cbf210f](https://github.com/ubugeeei-prod/lets-start-functional/commit/cbf210fa33c0691715751cfe04407bd23ed0b8a1) です。

## 言語がいま何をしてくれたのか

スマートコンストラクタが*何でないか*に注目してください。新しい言語機能ではない。マクロでもない。コンパイラパスでもない。`cat` は `Regex -> Regex -> Regex` 型の関数で、`Cat` とまったく同じ型です。Idris のコンストラクタは「たまたま大文字で始まる関数」にすぎないので、片方をもう片方に差し替えるのに摩擦がありません。データは愚直なまま。知性は普通の関数の中に住んでいて、等式ひとつずつテストできます。

そして 2 度目の red/green のペアが、テストについて教えてくれたことにも注目です。`deriv` が `Alt (Cat (Cat Fail ...) ...) Eps` を返すというスペックは、厳密には間違いではありません — エンジンは実際にそれを返していたのですから。しかしスペックは読み手への約束であり、あのスペックはガラクタを約束していました。振る舞いを変える*べき*ときは、スペックを変えるのが最初の一手、それが失敗するのを見届けるのが証拠、実装の変更は最後です。

## まとめ

- 微分は正しかったものの肥大化していました。死んだ `Fail` の枝と無駄な `Eps` の接頭辞が、一歩ごとに増えていきます。
- 正規表現には代数があります — `Fail` がゼロで `Eps` が 1 — そして一握りの恒等式で、ほとんどのガラクタは単純化できます。
- スマートコンストラクタ(`cat`、`alt`、`star`)は、同じ木を組み立てながら代数を適用する普通の関数です。どの規則も発火しなければ、生のコンストラクタにフォールバックします。
- Idris は宣言の順序を気にします。`alt` が `==` を使うため、`Eq Regex` はその上で定義しておく必要がありました。
- `deriv` をスマートコンストラクタに切り替える(green)前に、まず deriv のスペックを書き直した(red)ことで、テストは誠実であり続けました — テストは振る舞いを文書化するものであり、そこには「これから変えたい振る舞い」も含まれます。
- `alt` の等価チェックは浅いままです。その借金は [レース](./19-the-race.md) で取り立てられます。

次はエンジンに、「正確にこの 1 文字」を超えるマッチ — `.`、`[a-z]`、`\d` — を教えます。[文字クラス](./11-character-classes.md) へ。
