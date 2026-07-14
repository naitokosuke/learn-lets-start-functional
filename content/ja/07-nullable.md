---
title: "nullable:空文字列とのマッチ"
description: エンジン最初の問い——この正規表現は空文字列にマッチするか?——に、コンストラクタごとに 1 本の等式で答えます。
---

# nullable:空文字列とのマッチ

組み立てて、表示して、比較できる[データの木](./06-regex-as-data.md)が手に入りました。ここでエンジンに最初の本物の能力が備わります。それも、一風変わった能力です。正規表現が空文字列にマッチするかどうかを判定する、というものです。

## なぜ、よりによってこの問いなのか?

雑学クイズのように聞こえます。わざわざ空文字列にマッチさせたい人なんているのでしょうか?

種明かしをすると、これから作るマッチングアルゴリズムの可動部品はちょうど 2 つで、これはその片方なのです。もう片方——[次の章](./08-derivatives.md)で登場します——は、入力を 1 文字ずつ消費しながら、パターンを変形していきます。入力が尽きたとき、残る問いはひとつ。*手元に残ったパターンは、ここで止まって満足だろうか?* そして「入力が残っていない状態で止まって満足」とは、まさしく「空文字列にマッチする」ことなのです。

つまり、この風変わりな小さい述語は準備運動ではありません。エンジン全体の半分です。文献での伝統的な名前に従って `nullable` と呼ぶことにしましょう。マッチする文字列の中に空文字列が含まれるとき、その正規表現は *nullable* である、といいます。

葉については、すでに手で答えられます。`Eps` は空文字列にマッチします——それが仕事のすべてですから。`Lit 'a'` はマッチしません。本物の文字が 1 つ必要です。`Fail` は何にもマッチしないので、当然 `""` にもマッチしません。面白いのは、他の正規表現を中に含む 3 つのコンストラクタです。文章でこねくり回すより、スペックで全ケースを釘付けにしてしまいましょう。

## red:スペック

コミット [2712951](https://github.com/ubugeeei-prod/lets-start-functional/commit/271295156419e42c3577eed84e1e0330058b93f5) より、`regex/tests/src/Spec/Core.idr` への追記です。まずは葉とスター(star)から。

```idris
||| `nullable r` answers one question: does `r` match the empty string?
export
nullableSpecs : List Spec
nullableSpecs =
  [ shouldBe "Fail never matches, so not the empty string either"
      (nullable Fail) False
  , shouldBe "Eps matches exactly the empty string"
      (nullable Eps) True
  , shouldBe "a literal needs one character, empty is not enough"
      (nullable (Lit 'a')) False
  , shouldBe "a star matches zero repetitions, i.e. the empty string"
      (nullable (Star (Lit 'a'))) True
```

`Star` は常に `True` です。`a*` は「*0 個*以上の `a`」を意味し、0 回の繰り返しとはすなわち空文字列です。スターの下に何が入っているかは、関係すらありません。

続いて連接(sequencing)と選択(choice)。こちらは答えが子に依存します。

```idris
  , shouldBe "a sequence is nullable only when both halves are"
      (nullable (Cat Eps (Star (Lit 'a')))) True
  , shouldBe "a sequence with a non-nullable half is not nullable"
      (nullable (Cat (Star (Lit 'a')) (Lit 'b'))) False
  , shouldBe "a choice is nullable when either branch is"
      (nullable (Alt (Lit 'a') Eps)) True
  , shouldBe "a choice of two literals is not nullable"
      (nullable (Alt (Lit 'a') (Lit 'b'))) False
  ]
```

先へ進む前に、2 つの `Cat` のスペックを自分で納得しておいてください。`Cat l r` が `""` にマッチするのは、文字列を `l` の部分と `r` の部分に分割でき、その両方を空にできるときだけ——つまり*両方の*半分が nullable でなければなりません。2 つ目のスペックの `a*b` は決して `""` にマッチしません。前の `a*` がどれだけ気前よくても、最後の `b` が 1 文字を要求するからです。

`Alt` は、どちらかの枝が `""` にマッチすれば十分です。`Alt (Lit 'a') Eps`——`a` が 1 つ、または何もなし——は nullable ですが、`a|b` はそうではありません。

スイートを走らせると、もうおなじみになった色合いの red が出ます——`nullable` が存在しないのです。

```
2/3: Building Spec.Core (src/Spec/Core.idr)
Error: While processing right hand side of nullableSpecs. Undefined name nullable.

Spec.Core:50:8--50:16
 50 |       (nullable (Alt (Lit 'a') (Lit 'b'))) False
             ^^^^^^^^
```

## green:コンストラクタごとに 1 本の等式

コミット [3b1516d](https://github.com/ubugeeei-prod/lets-start-functional/commit/3b1516ddb2ecf05f2ce671efee5257370a2c0bcf) が、`regex/src/Regex/Core.idr` に次を追加します。

```idris
||| Does this regex match the empty string?
|||
||| This tiny function is one half of the whole matching algorithm
||| (the other half is `deriv`). Read each line as a fact about the
||| empty string:
|||
||| - `Fail` matches nothing, so certainly not the empty string.
||| - `Eps` is *defined* as matching the empty string.
||| - A literal needs one real character.
||| - A sequence matches "" only if both halves can match "".
||| - A choice matches "" if either branch does.
||| - A star matches zero repetitions, which is exactly "".
|||
||| There is no algorithm here to memorize — the function is just the
||| definition of "matches the empty string", written case by case.
public export
nullable : Regex -> Bool
nullable Fail      = False
nullable Eps       = True
nullable (Lit _)   = False
nullable (Cat l r) = nullable l && nullable r
nullable (Alt l r) = nullable l || nullable r
nullable (Star _)  = True
```

たった 6 行。そしてオチはこうです。**この中にアルゴリズムはありません**。何も探索せず、何も蓄積せず、状態の引き回しもありません。各等式は、その形の木にとっての「空文字列にマッチする」の定義*そのもの*です。`Cat` が `&&` なのは、連接では両方の半分が消えてなくなる必要があるから。`Alt` が `||` なのは、選択では片方の枝で足りるから。この関数は暗記するものではありません——1 行ずつ読んで、うなずいて、先へ進むだけです。

これこそ「正規表現はデータである」ことの配当です。パターンが 6 種類の既知の形を持つ木だからこそ、パターンについての問いは、形ごとにひとつずつ、6 つの小さな事実になります。本書に登場する関数の大半が、まさにこの手触りをしています。

```sh
make test
```

```
  ok    true is true
  ...
  ok    different shapes are not equal
  ok    Fail never matches, so not the empty string either
  ok    Eps matches exactly the empty string
  ok    a literal needs one character, empty is not enough
  ok    a star matches zero repetitions, i.e. the empty string
  ok    a sequence is nullable only when both halves are
  ok    a sequence with a non-nullable half is not nullable
  ok    a choice is nullable when either branch is
  ok    a choice of two literals is not nullable
19/19 passed
```

## 安全網:網羅性と %default total

さて、私たちが 6 本の等式を打ち込んでいる間に、言語が静かにやってくれていたことの話をしましょう。

足場づくりのときに書いた `Regex.Core` の最初の 1 行、`%default total` を思い出してください。これは、このモジュールのすべての関数が*全域(total)*——あり得るすべての入力に対して定義されていて、必ず処理が終わることが保証されている——でなければならない、と Idris に伝えるものです。`nullable` にとって、この約束は 2 つに分かれます。

1 つ目は**網羅性(coverage)**です。`Regex` の作り方はちょうど 6 通りあり、`nullable` はその 6 通りすべてを扱わなければなりません。将来のリファクタリング中に、`Star` のケースをうっかり消してしまったとしましょう。モジュールは端的にコンパイルできなくなります。

```
Error: nullable is not covering.

Regex.Core:48:1--64:25
 48 | ||| Does this regex match the empty string?
 ...

Missing cases:
    nullable (Star _)
```

コンパイラはただ文句を言うだけではありません——*足りないケースの名前を挙げて*くれます。これが、この先のすべてを支える安全網です。本書の後半では `Regex` 自体にコンストラクタを追加します([文字クラス](./11-character-classes.md)の章です)。その瞬間、`Regex` をパターンマッチするすべての関数は、新しい形を扱うまでコンパイルに失敗し、それぞれが「何が足りないのか」を正確に指差してくれます。たいていの言語では、「バリアントを追加したから、switch 文を全部 grep しなきゃ」は祈りにすぎません。ここでは、TODO リスト付きのコンパイルエラーになるのです。

2 つ目は**停止性(termination)**です。`nullable` は自分自身を呼んでいます——永遠に再帰し続けないと、Idris はどうして分かるのでしょうか?再帰の*対象*を見てください。`nullable (Cat l r)` は `nullable l` と `nullable r` を呼びますが、`l` と `r` は入力の真部分木です。どの再帰呼び出しも、コンストラクタを少なくとも 1 枚は剥がしています。木は有限なので、再帰は必ず葉で底を打ちます。

このパターンは**構造的再帰(structural recursion)**——すべての呼び出しが入力の一部分に対して行われる再帰——と呼ばれ、全域性チェッカーの大好物です。再帰を構造的に書けば、全域性チェックはタダでついてきます。以後、意識することはほとんどなくなるでしょう。本書のほぼすべての関数が、マッチャー全体も含めて、構造的再帰で書かれています。

> [!TIP]
> ADT 上の関数を書くときは、コンストラクタに主導権を握らせましょう。コンストラクタごとに 1 本の等式を書き、それぞれの右辺にホール(`?rhs`)を置いて、ひとつずつ埋めていきます。残りのケースはコンパイラが追跡してくれます。これは単なる構文としてではなく、ワークフローとしてのパターンマッチです。

## まとめ

- `nullable r` が答える問いはひとつ、「`r` は空文字列にマッチするか?」。雑学に見えて、マッチングアルゴリズム全体の半分です——残りの半分は次の章で登場します。
- 関数はコンストラクタごとに 1 本、計 6 本の等式で、暗記すべきアルゴリズムはありません。各行が、その形にとっての「空文字列にマッチする」の*定義*です。
- `Cat` は `&&`(両方の半分が消えられること)、`Alt` は `||`(片方の枝で十分)、`Star` は常に `True`(0 回の繰り返し)。
- `%default total` は網羅性をコンパイル時の保証にします。ケースを消せば、コンパイラがその名前を挙げてくれます——`Missing cases: nullable (Star _)`。
- 構造的再帰——部分木に対してのみ再帰すること——が、関数が停止することを全域性チェッカーに納得させます。
- スイートは 19/19、すべて green です。

次はアルゴリズムのもう半分、そして本書全体の心臓部です。[微分(derivative)](./08-derivatives.md)——パターンが 1 文字を食べたあとに、何が残るのでしょうか?
