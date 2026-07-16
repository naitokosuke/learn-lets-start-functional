---
title: インターフェースと2つのモノイド
description: ShowやEq，パーサの階段の背後にあった契約に名前を付けます．そしてIdrisの名前付き実装で，ひとつの型の上にモノイドをふたつ共存させてみましょう．
---

# インターフェースと2つのモノイド

実は[正規表現はデータである](./06-regex-as-data.md)の章から，インターフェースはずっと使ってきています．ただ，立ち止まって名前を確認したことは一度もありませんでした．この章ではそこをきちんと整理します．そしてそのまま，Haskellは回避策(workaround)で答え，Idrisは言語機能で答える，という問いにぶつかっていきます．

## インターフェースはもう使っている

[正規表現はデータである](./06-regex-as-data.md)の章で，こういうコードを書いてそのまま先へ進みました．

```idris
export
Show Regex where
  show = showRegex
```

そして[TDDと小さなテストハーネス](./05-tdd.md)のテストハーネスは，ここまでずっとこのシグネチャを持ち続けています．

```idris
shouldBe : Show a => Eq a => String -> (actual : a) -> (expected : a) -> Spec
```

[パーサコンビネータ](./13-parser-combinators.md)では`Functor`から`Alternative`へと階段を登りました．つまり，仕組み自体はもうおなじみのはずです．ただ，登場人物がそれぞれ正確には何者なのかを言葉にしたことはなかったので，ここで整理しておきましょう．

- **インターフェース(interface)**は契約です．型が「提供します」と約束できる，名前付きの関数シグネチャの集まりです．`Show`は「`String`として表示できます」という契約で，`Eq`は「比較できます」という契約です．
- **実装(implementation)**は，その契約をひとつの具体的な型について果たすものです．ここが大事なところなのですが，実装は*値*です．コンパイラが一度だけ組み立てて，あとは勝手に引き回してくれる関数のレコード，という感じです．上の`Show Regex where ...`ブロックは，その値を構築しています．
- シグネチャに現れる`Show a =>`のような**制約(constraint)**は，その値の*リクエスト*です．`shouldBe "..." actual expected`を`Regex`型で呼ぶと，コンパイラは黙って`Show Regex`と`Eq Regex`の実装を探し出し，追加の引数として渡してくれます．レジストリも実行時の検索もなく，すべてコンパイル時に解決されます．

ちなみに，Haskellを知っている方はインターフェース = 型クラス，実装 = インスタンスという対応でOKです．Rustならtraitとimplです．考え方は同じで，Idrisが何を足してくれるのかはこの章の最後に出てきます．

## 最小の役に立つ契約: Semigroup

プレリュードには，冗談かと思うくらい小さい契約が入っています．

```idris
interface Semigroup ty where
  (<+>) : ty -> ty -> ty

interface Semigroup ty => Monoid ty where
  neutral : ty
```

(docコメントは省いていますが，形としてはこれで全部です．)**半群(semigroup)**は，二項演算`<+>`をひとつ持つ型のことです．この演算は*結合的*でなければなりません．つまり`a <+> (b <+> c)`と`(a <+> b) <+> c`が等しい，ということです．**モノイド(monoid)**は，半群に*単位元(neutral element)*，つまりどちら側から結合しても何も変えない値を加えたものです．

モノイドの実例は，実はもういくつも知っています．文字列は，連結を演算に，`""`を単位元にしたモノイドです．

```repl
Main> "fun" <+> "ctional"
"functional"
Main> the String neutral
""
```

そして数は，*二重に*モノイドです．加算は結合的で`0`は何も変えません．乗算も結合的で`1`は何も変えません．同じ型の上に，どちらも申し分のないモノイドがふたつあるわけです．

さて，ここが厄介なところです．インターフェースの実装は型ごとにひとつしか持てません(だからこそコンパイラが黙って選べるのでした)．では，整数の上で「これぞ`Monoid`」の座に着くのはどちらでしょう?和でしょうか，積でしょうか? Haskellの答えは回避策です．数を`newtype`(`Sum`か`Product`)で包んでラッパー型ごとに別のインスタンスを持たせ，あとで取り出します．一方Idrisのプレリュードは，そもそも選びません．数値の`Monoid`は存在しないのです．というのも，Idrisにはもっと良い道具があるからです．実装には**名前を付ける**ことができて，ひとつの型は名前付き実装をいくつでも持てます．

## 正規表現は二重のモノイド

`Regex`型も，まったく同じ「モノイドふたつ問題」を抱えています．しかもこれは珍しい話ではなく，本書でずっと使ってきたあの代数そのものです．

| 演算 | 結合 | 単位元 | なぜ単位元か |
|-----------|---------|---------|-------------|
| 連接 | `cat` | `Eps` | `r`の前後に空文字列を置いても`r`のまま |
| 選択 | `alt` | `Fail` | 不可能な分岐はいつでも捨てられる |

このふたつの事実は，[スマートコンストラクタ](./10-smart-constructors.md)の章でスマートコンストラクタに組み込み済みです．`cat Eps r = r`と`alt Fail r = r`は，単位元の法則をそのままコードにしたものでした．なので，この代数を公式なものにしていきましょう．例の如く，まずはスペックからです．

## Red:ふたつのモノイドを一度に求める

スペックは[`regex/tests/src/Spec/Pretty.idr`](https://github.com/ubugeeei-prod/lets-start-functional/blob/main/regex/tests/src/Spec/Pretty.idr)の末尾に，コミット[114a177](https://github.com/ubugeeei-prod/lets-start-functional/commit/114a1772565ccf9bdabe3c24099150ed6052f252)で追加します．

```idris
    -- the two monoids
  , shouldBe "sequencing: <+> under SeqSemigroup is cat"
      ((<+>) @{SeqSemigroup} (lit 'a') (lit 'b'))
      (Cat (lit 'a') (lit 'b'))
  , shouldBe "sequencing: the neutral element is Eps"
      (the Regex (neutral @{SeqMonoid})) Eps
  , shouldBe "choice: <+> under AltSemigroup is alt"
      ((<+>) @{AltSemigroup} (lit 'a') (lit 'b'))
      (Alt (lit 'a') (lit 'b'))
  , shouldBe "choice: the neutral element is Fail"
      (the Regex (neutral @{AltMonoid})) Fail
  , it "anyOf folds a whole list of alternatives"
      (matches (anyOf [literal "let", literal "in", literal "where"]) "in")
  , shouldBe "anyOf of nothing is Fail — you can match none of no things"
      (anyOf []) Fail
  ]
```

新しい構文がふたつ出てきましたが，どちらも見た目どおりの働きをします．

- `@{SeqSemigroup}`は，実装を*名前で明示的に*渡します．制約はふつう黙って埋められますが，`@{...}`は「これを使ってください」という指定です．
- `the Regex (...)`はプレリュードの型指定(type ascription)関数です．裸の`neutral`はどの型のどのモノイドのものでもありえるので，ここで固定しておきます．

スイートは走り出す前からredです．このスペックモジュールが，まだ存在しないモジュールをimportしているからです．

```
Error: Module Regex.Pretty not found
```

(仮にそのモジュールを用意できたとしても，`SeqSemigroup`とその仲間たちは未定義の名前です．`Regex.Core`にはまだ何もありません．)

## Green:名前付き実装

コミット[bd405ed](https://github.com/ubugeeei-prod/lets-start-functional/commit/bd405eda8e87a78a1716c306df0286a221d3ccd2)の[`regex/src/Regex/Core.idr`](https://github.com/ubugeeei-prod/lets-start-functional/blob/main/regex/src/Regex/Core.idr)から，実装はこんな感じです．

```idris
-- ---------------------------------------------------------------
-- The regex algebra, made official.
--
-- Regex is a monoid twice over: once under sequencing (Eps is the
-- do-nothing element) and once under choice (Fail is the
-- nothing-to-choose element). In Haskell you would pick one and
-- wrap the other in a newtype; Idris lets both coexist as *named*
-- implementations, chosen explicitly with @{...}.
-- ---------------------------------------------------------------

public export
[SeqSemigroup] Semigroup Regex where
  (<+>) = cat

public export
[SeqMonoid] Monoid Regex using SeqSemigroup where
  neutral = Eps

public export
[AltSemigroup] Semigroup Regex where
  (<+>) = alt

public export
[AltMonoid] Monoid Regex using AltSemigroup where
  neutral = Fail

||| Accept any of the given regexes: fold with the choice monoid.
||| `anyOf []` is `Fail` — offered no options, match nothing.
public export
anyOf : List Regex -> Regex
anyOf = foldr alt Fail
```

構文を読み解いていきましょう．

- `[SeqSemigroup] Semigroup Regex where ...`は，頭に名前が付いただけのごくふつうの実装です．名前が付いているのでデフォルトにはならず，同じ型の上で`AltSemigroup`と平和に共存できます．
- `Monoid`は`Semigroup`を*親*の制約として持ちます．親の候補がスコープにふたつあると，コンパイラには推測できません．`using SeqSemigroup`が，このモノイドがどちらの親を拡張するのかを指定します．`SeqMonoid`の`<+>`は`cat`で，`AltMonoid`のそれは`alt`です．
- 名前なしの実装は，意図的に用意していません．`@{...}`なしで`lit 'a' <+> lit 'b'`と書くとコンパイルエラーになります．一度にふたつのモノイドである型にとって「とにかく結合して」は答えようのない指示なので，Idrisは呼び出し側に選ばせる，というわけです．

`anyOf`は選択モノイドの実戦投入です．選択肢のリストを`alt`で畳み込んで，種としてその単位元を置きます．`anyOf []`が`Fail`を返すのは，エッジケースとして特別扱いしたからではなく，代数から勝手に転がり出てきたものです．選択肢がひとつもなければ，どれにもマッチできない，というわけです．

```sh
make test
```

```
  ...
  ok    sequencing: <+> under SeqSemigroup is cat
  ok    sequencing: the neutral element is Eps
  ok    choice: <+> under AltSemigroup is alt
  ok    choice: the neutral element is Fail
  ok    anyOf folds a whole list of alternatives
  ok    anyOf of nothing is Fail — you can match none of no things
148/148 passed
```

> [!NOTE]
> このコミットのペアが届けるのはモノイドだけではありません．同じスペックファイルは，`Regex`をパターン構文へ印字し直すプリティプリンタ`toPattern`のテストで始まっていて，greenのコミットはその実装も含んでいます．これはこれでひとつの物語なので，[次章](./17-pretty-printing.md)でまるごと扱います．

## コンパイラが検査しない法則

`Semigroup`と`Monoid`には法則が付いてきます．結合法則と，左右両側の単位元性です．ただ，上のコードにはそれを証明するものは何もありません．コンパイラが検査するのは`(<+>)`と`neutral`が正しい*型*を持つことだけで，`cat`が本当に結合的かどうかはこちらが立てる約束であって，ここでIdrisが検証してくれるわけではないのです．

では，その約束はそもそも真なのでしょうか?ざっくり言うと，ほぼ真です．`cat`と`alt`は，*マッチャとしては*結合的で単位元も持ちます(どちらの順で結合しても，受理する文字列は同じです)．ただし木として額面どおりに見ると，スマートコンストラクタの簡約のせいで，隅のケースでは法則の両辺の形が食い違うことがあります．スペックでは法則を例で抜き打ち検査していますが，まあ，これはあらゆるHaskellの型クラスが受け入れているのと同じ取引です．

ここで，法則がどんな種類の文なのかに注目してみてください．「**すべての** `a`，`b`，`c`について……」という形です．テストにできるのは，その有限個の実例を確かめることだけです．しかしIdrisはもっとうまくやれます．for-allの文を*型*として書いて，その証明をコンパイル時に検査できるのです．これは言葉のあやではなく，[2章先](./18-proofs.md)で実際にやります．

## 言語がいま何をしてくれたか

この章のひとつの大きなアイデアをおさらいしましょう．型クラス風のインターフェースを持つたいていの言語では「実装は型ごとにひとつ」が固い規則で，逃げ道はラッパー型の発明です．Idrisでは実装はふつうの名前付きの値なので，規則は「型ごとに*デフォルト*はひとつ，名前付きの代替はいくらでも」まで柔らかくなり，`@{name}`が呼び出し側で選びます．包むことも剥がすこともありません．型は最初から最後まで`Regex`のままで，帽子をかぶり替えるのは代数だけ，という感じです．

## まとめ

- インターフェースは契約です．実装はそれを果たす，コンパイラが組み立てる値です．`Show a =>`のような制約は，その値をコンパイル時に黙って要求します．
- 半群は結合的な`<+>`を持つ型で，モノイドはそこに単位元を加えたものです．文字列はモノイドをひとつ，数はふたつ持ちます(それこそが厄介の種でした)．
- `Regex`もまた二重のモノイドです．単位元`Eps`の連接と，単位元`Fail`の選択です．
- Idrisの名前付き実装(`[SeqMonoid] Monoid Regex using SeqSemigroup where ...`)は両者をひとつの型の上に共存させ，`@{SeqMonoid}`で明示的に選ばせます．Haskellがnewtypeラッパーに手を伸ばすところです．
- `anyOf = foldr alt Fail`は選択モノイドの実践で，`anyOf [] = Fail`はタダで付いてきます．
- モノイドの法則は，ここではコンパイラが検査しない契約です．しかしIdrisには検査できます．[テストが定理になる](./18-proofs.md)で実際にやってみましょう．

同じgreenのコミットは，エンジンに自分のパターンを印字し直すことも教えていました．その話は[パターンを印字し直す](./17-pretty-printing.md)で扱います．
