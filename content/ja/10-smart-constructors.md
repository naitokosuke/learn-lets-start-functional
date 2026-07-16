---
title: スマートコンストラクタ
description: エンジンに正規表現の代数を少しだけ教えて，微分結果がガラクタを溜め込まず小さいまま保たれるようにします．
---

# スマートコンストラクタ

エンジンは動くようになりましたが，微分の結果は`Cat Fail (Star (Lit 'a'))`のようなガラクタだらけです．この章ではコンストラクタにちょっとした代数を教えて，ガラクタがそもそも生まれないようにしていきましょう．

## 絨毯の下に掃き込んでいたガラクタ

[微分](./08-derivatives.md)の章で書いたスペックのひとつに，こんな期待値がありました:

```idris
  , shouldBe "a nullable head lets the character reach the tail too"
      (deriv 'b' (Cat (Star (Lit 'a')) (Lit 'b')))
      (Alt (Cat (Cat Fail (Star (Lit 'a'))) (Lit 'b')) Eps)
```

この期待値をよく見てみてください．`a*b`を`'b'`で微分したのだから，正直な答えは「空文字列」のはずです．`b`は消費されて，あとには何も残りません．ところが実際に得られた木は，`Fail`で始まる(なので何にもマッチしえない)枝，または`Eps`，という妙に回りくどい言い方をしています．

それでもエンジンが正しい判定を返すのは，`nullable`が木全体を律儀に歩いてくれるからです．ただ，`deriv`を呼ぶたびに木は前より大きくなり，死んだ枝は決して刈り込まれません．長い文字列をマッチさせると微分は雪だるま式に膨らんでいきます．理論上は線形時間のはずなのに，木のサイズがそれを裏切っているという感じです．

## ちょっとした正規表現の代数

直し方は特に難しくありません．頭の中で確かめられる程度の，ほんの一握りの事実だけです:

- `Fail`は連接(sequencing)に対して吸収的(absorbing)です．「無」のあとに何を続けても「無」のままです．`Cat Fail r`も`Cat r Fail`も，マッチする集合は空です．
- `Eps`は連接の単位元(identity)です．空文字列に`r`を続ければ，ただの`r`です．
- `Fail`は選択(choice)の単位元です．不可能な枝は捨ててしまってOKです．`Alt Fail r`はただの`r`です．
- 「無」のスターや空文字列のスターが生み出せるのは空文字列だけです．`Star Fail`も`Star Eps`も`Eps`です．
- 二重のスターはつぶせます．`Star (Star r)`がマッチするものは`Star r`と同じです．

なんだか算術のように読めますが(ゼロに何を掛けてもゼロ，1掛ける`r`は`r`)，これは偶然ではありません．正規表現は代数をなしていて，`Fail`がゼロの役，`Eps`が1の役を演じているというわけです．

これまでのコードは，生のコンストラクタ`Cat`，`Alt`，`Star`で木を組み立てていました．これらは渡されたものを，ガラクタも含めてそっくりそのまま記録します．なので，木を普通の小文字の関数`cat`，`alt`，`star`を通して組み立てるようにしてみましょう．同じ形を作りつつ，組み立てる時点で代数を適用してしまう関数たちです．こういう「コンストラクタの役を演じつつ，先に考えることを許された関数」を**スマートコンストラクタ(smart constructor)**と呼びます．

## Red: cat・alt・starのスペック

上の代数は，そのまま1行ずつスペックに翻訳できます．`regex/tests/src/Spec/Core.idr`の末尾に追加しましょう:

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

「それ以外(anything else)」のケースに注目してください．スマートコンストラクタといえども，やはりコンストラクタでなければなりません．どの代数も当てはまらないときは，`cat`は素直に`Cat`を組み立てるだけです．

例の如く`Main.idr`のスペックの山に`++ smartSpecs`を積み増して，実行してみましょう:

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

Redです．関数がまだ存在しないので当然ですね．(コンパイラさん，`Star`のつもりではないんです．むしろそこがポイントなので．)

これはコミット[dc19adf](https://github.com/ubugeeei-prod/lets-start-functional/commit/dc19adfdc758475c87dce8f5613bb820fad1fe28)です．

## Green: 3つの関数，それぞれにパターンマッチをひとつ

実装はこんな感じです．代数の事実がひとつずつ，`regex/src/Regex/Core.idr`の等式ひとつに対応します:

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

Idrisは節(clause)を上から順に試すので，特別なケースを先に並べて，「それ以外」の節で残りを受け止めます．代数がどこかのオプティマイザの中に隠れているのではなく，この関数そのものが代数になっているという感じです．

ちなみに，greenにたどり着く途中でひとつハマったことがありました．`alt`は`==`を使うので，`Eq Regex`の実装(と，道連れで移動した`Show`)はファイル内で`alt`より上に宣言しておく必要があります．Idrisはモジュールを上から下へ読み，名前は使う前に定義されていなければなりません．宣言を巻き上げ(hoist)てくれる言語から来ると窮屈に感じるかもしれませんが，そのおかげでIdrisのモジュールはいつでも頭から一直線に読めて，まだ見たことのない名前に出会うことがない，というわけです．

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

これはコミット[56bc36b](https://github.com/ubugeeei-prod/lets-start-functional/commit/56bc36b6c01f7f8ab2ce5aeb381424eec4d46e19)です．

> [!WARNING]
> `alt`をよく見てください．`l == r`というチェックがつぶしてくれるのは，完全に同じ木である枝だけです．`Alt a (Alt b a)`の重複した`a`はそのまま残ります．比較されるどの2つの枝も，いちばん外側では等しくないからです．今のところはこの浅いチェックで問題ないのですが，覚えておいてください．[レース](./19-the-race.md)の章でベンチマークがまさにここで爆発して，`alt`を鍛え直すことになります．

## ふたたびRed:テストはまだガラクタを文書化している

スマートコンストラクタはできましたが，まだ誰も使っていません．`deriv`は相変わらず生の`Cat`，`Alt`，`Star`で組み立てていて，微分のスペックはいまだにガラクタを期待したままです．ここにテストにまつわる不都合な真実があります．テストはドキュメントであり，今のテストはこの散らかった出力を，まるで望ましい振る舞いであるかのように文書化してしまっているのです．

なので，次のredステップは新しいコードではなく，本当に欲しい出力を記述するように期待値を書き直すことです．スターのケースを，書き直す前と後で並べるとこんな感じになります:

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

続いてnullableな先頭のケースです．この章の冒頭に出てきた騒がしい木は，`Eps`ひとつにまで畳まれます:

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

期待値を先に更新するのが，誠実さを保つコツです．`deriv`とスペックをひと息に変えてしまうと，その変更が本当に何かを変えたという証拠を見る機会が永遠に失われてしまいます．

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

きちんとredになりました．失敗レポートがそのままTODOリストのように読めるのもいい感じです．これはコミット[1c1a681](https://github.com/ubugeeei-prod/lets-start-functional/commit/1c1a6815ce8d2be4ddb707030217a54af453f49d)です．

## Green: derivはスマートコンストラクタで組み立てる

直しは1ケースにつき1行です．`deriv`が大文字のコンストラクタで組み立てていた場所を，小文字の関数に置き換えるだけです．

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

再帰には手を触れていません．微分の数学は元のままで，賢くなったのは答えの組み立て方だけです．ガラクタは掃除されるようになったのではなく，そもそも生まれなくなりました．

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

これはコミット[cbf210f](https://github.com/ubugeeei-prod/lets-start-functional/commit/cbf210fa33c0691715751cfe04407bd23ed0b8a1)です．

## 言語がいま何をしてくれたのか

スマートコンストラクタが何で*ない*かに注目してください．新しい言語機能でもマクロでもコンパイラパスでもありません．`cat`は`Regex -> Regex -> Regex`型のただの関数で，`Cat`とまったく同じ型です．Idrisのコンストラクタは「たまたま大文字で始まる関数」にすぎないので，片方をもう片方に差し替えるのに摩擦がない，というわけです．データは愚直なまま，知性は普通の関数の中に住んでいて，等式ひとつずつテストできます．

2度目のred/greenのペアも，テストについて大事なことを教えてくれます．`deriv`が`Alt (Cat (Cat Fail ...) ...) Eps`を返すというスペックは，厳密には間違いではありません．エンジンは実際にそれを返していたわけですから．ただ，スペックは読み手への約束であり，あのスペックはガラクタを約束してしまっていました．振る舞いを変えるべきときは，スペックを変えるのが最初の一手，それが失敗するのを見届けるのが証拠，実装の変更は最後です．

## まとめ

- 微分は正しいものの肥大化していました．死んだ`Fail`の枝と無駄な`Eps`の接頭辞が，一歩ごとに増えていきます．
- 正規表現には代数があります．`Fail`がゼロで`Eps`が1です．一握りの恒等式で，ほとんどのガラクタは単純化できます．
- スマートコンストラクタ(`cat`，`alt`，`star`)は，同じ木を組み立てながら代数を適用する普通の関数です．どの規則も当てはまらなければ，生のコンストラクタにフォールバックします．
- Idrisは宣言の順序を気にします．`alt`が`==`を使うため，`Eq Regex`はその上で定義しておく必要がありました．
- `deriv`をスマートコンストラクタに切り替える(green)前に，まずderivのスペックを書き直した(red)ことで，テストは誠実であり続けました．テストが文書化するのは振る舞いであり，そこには「これから変えたい振る舞い」も含まれます．
- `alt`の等価チェックは浅いままです．この借金は[レース](./19-the-race.md)で取り立てられます．

次はエンジンに，「正確にこの1文字」を超えるマッチを教えていきます．`.`や`[a-z]`や`\d`です．[文字クラス](./11-character-classes.md)へ進みましょう!
