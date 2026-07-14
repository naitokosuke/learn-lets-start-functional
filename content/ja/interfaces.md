---
title: インターフェースと2つのモノイド
description: Show や Eq、パーサの階段の背後にある契約に名前を与え、Idris の名前付き実装で、ひとつの型を二重のモノイドに仕立てます。
---

# インターフェースと2つのモノイド

あなたは [正規表現はデータである](./regex-as-data.md) の章からずっとインターフェースを使ってきました — 立ち止まって名前を呼ぶことのないままに。この章ではその名前をきちんと呼びます。そしてそのまま、Haskell は回避策(workaround)で答え、Idris は言語機能で答える、ある問いへとまっすぐ突き当たります。

## インターフェースはもう使っている

[正規表現はデータである](./regex-as-data.md) の章で、私たちはこう書いて先へ進みました:

```idris
export
Show Regex where
  show = showRegex
```

そして [TDD と小さなテストハーネス](./tdd.md) のテストハーネスは、ここまでずっとこのシグネチャを携えてきました:

```idris
shouldBe : Show a => Eq a => String -> (actual : a) -> (expected : a) -> Spec
```

[パーサコンビネータ](./parser-combinators.md) では `Functor` から `Alternative` へと階段を登りました。つまり、仕組み自体はもうおなじみです。ただ、3 つの登場人物がそれぞれ正確には何者なのか、言葉にしたことは一度もありませんでした:

- **インターフェース(interface)** は契約です:型が「提供します」と約束できる、名前付きの関数シグネチャの集まり。`Show` は「私は `String` として表示できます」と言い、`Eq` は「私は比較できます」と言います。
- **実装(implementation)** は、その契約をひとつの具体的な型について果たすものです — そしてここが胸に刻むべきところ:実装は*値*です。コンパイラが一度だけ組み立て、あなたの代わりに引き回してくれる、関数のレコード。上の `Show Regex where ...` ブロックは、その値を構築しているのです。
- シグネチャに現れる `Show a =>` のような**制約(constraint)** は、その値の*リクエスト*です。`shouldBe "..." actual expected` を `Regex` 型で呼ぶと、コンパイラは黙って `Show Regex` と `Eq Regex` の実装を探し出し、追加の引数として手渡します。レジストリも実行時の検索もなし — すべてコンパイル時に解決されます。

Haskell を知っているなら:インターフェース = 型クラス、実装 = インスタンス。Rust を知っているなら:trait と impl。考え方は同じです。Idris が付け加えるものは、この章の最後に登場します。

## 最小の役に立つ契約:Semigroup

プレリュードには、冗談かと思うほど小さな契約が入っています:

```idris
interface Semigroup ty where
  (<+>) : ty -> ty -> ty

interface Semigroup ty => Monoid ty where
  neutral : ty
```

(doc コメントは省いています。形としてはこれで全部です。)**半群(semigroup)** とは、二項演算 `<+>` をひとつ持つ型のことで、この演算は*結合的*でなければなりません:`a <+> (b <+> c)` は `(a <+> b) <+> c` に等しい。**モノイド(monoid)** は、半群に*単位元(neutral element)* — どちら側から結合しても何も変えない値 — を加えたものです。

モノイドなら、あなたはすでにいくつも知っています。文字列は、連結を演算に、`""` を単位元にしてモノイドです:

```
Main> "fun" <+> "ctional"
"functional"
Main> the String neutral
""
```

そして数 — こちらは*二重に*です。加算は結合的で `0` は何も変えない。乗算も結合的で `1` は何も変えない。同じ型の上に、どちらも申し分のないモノイドがふたつあります。

そして*そこ*が厄介の種なのです。インターフェースの実装は、型ごとにひとつしか持てません — だからこそコンパイラは黙って選べるのでした。では、整数の上で「これぞ `Monoid`」の座に着くのはどちらでしょう:和?それとも積? Haskell の答えは回避策です:数を `newtype`(`Sum` か `Product`)で包み、ラッパー型ごとに別のインスタンスを持たせて、あとで取り出す。Idris のプレリュードは、選ぶこと自体を拒みます — 数値の `Monoid` はそもそも存在しません。なぜなら Idris にはもっと良い道具があるからです:実装には**名前を付ける**ことができ、ひとつの型は名前付き実装を好きなだけ持てるのです。

## 正規表現は二重のモノイド

私たちの `Regex` 型も、まったく同じ「モノイドふたつ問題」を抱えています。しかもこれは珍品ではありません — 本書でずっと使ってきた、あの代数そのものです:

| 演算 | 結合 | 単位元 | なぜ単位元か |
|-----------|---------|---------|-------------|
| 連接 | `cat` | `Eps` | `r` の前後に空文字列を置いても `r` のまま |
| 選択 | `alt` | `Fail` | 不可能な分岐はいつでも捨てられる |

このふたつの事実は、[スマートコンストラクタ](./smart-constructors.md) の章でスマートコンストラクタに組み込み済みです:`cat Eps r = r` と `alt Fail r = r` は、単位元の法則をコードとして書き下したものでした。この代数を公式のものにするときが来ました — まずはスペックとして書くところからです。

## Red: ふたつのモノイドを一度に求める

スペックは [`regex/tests/src/Spec/Pretty.idr`](https://github.com/ubugeeei-prod/lets-start-functional/blob/main/regex/tests/src/Spec/Pretty.idr) の末尾に、コミット [114a177](https://github.com/ubugeeei-prod/lets-start-functional/commit/114a1772565ccf9bdabe3c24099150ed6052f252) で入ります:

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

新しい構文がふたつ。どちらも見た目どおりの働きをします:

- `@{SeqSemigroup}` は、実装を*名前で明示的に*渡します。制約はふつう黙って埋められますが、`@{...}` は「これを使ってください」と言います。
- `the Regex (...)` はプレリュードの型指定(type ascription)関数です — 裸の `neutral` はどの型のどのモノイドのものでもありえるので、ここで釘を刺しておきます。

スイートは走り出す前から red です。このスペックモジュールが、まだ存在しないモジュールを import しているからです:

```
Error: Module Regex.Pretty not found
```

(そして、そのモジュールが用意できたとしても、`SeqSemigroup` とその仲間たちは未定義の名前です — `Regex.Core` にはまだ何も提供されていません。)

## Green: 名前付き実装

コミット [bd405ed](https://github.com/ubugeeei-prod/lets-start-functional/commit/bd405eda8e87a78a1716c306df0286a221d3ccd2) の [`regex/src/Regex/Core.idr`](https://github.com/ubugeeei-prod/lets-start-functional/blob/main/regex/src/Regex/Core.idr) から:

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

構文を読み解きましょう:

- `[SeqSemigroup] Semigroup Regex where ...` は、頭に名前が付いただけの、ごくふつうの実装です。名前が付いているのでデフォルトにはならず、同じ型の上で `AltSemigroup` と平和に共存します。
- `Monoid` は `Semigroup` を*親*の制約として持ちます。親の候補がスコープにふたつあると、コンパイラには推測できません。`using SeqSemigroup` が、このモノイドがどちらの親を拡張するのかを告げます。`SeqMonoid` の `<+>` は `cat`、`AltMonoid` のそれは `alt` です。
- 名前なしの実装は、意図的に存在しません。`@{...}` なしで `lit 'a' <+> lit 'b'` と書くとコンパイルエラーです — 一度にふたつのモノイドである型にとって、「とにかく結合して」は指示ではなく質問であり、Idris はあなたに答えさせるのです。

`anyOf` は選択モノイドの実戦投入です:選択肢のリストを `alt` で畳み込み、種としてその単位元を置く。`anyOf []` が `Fail` を返すのは、私たちが処理したエッジケースではありません — 代数からひとりでに転がり出てきたものです。選択肢をひとつも与えられなければ、どれにもマッチできない、というわけです。

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
> このコミットのペアが届けるのはモノイドだけではありません:同じスペックファイルは、`Regex` をパターン構文へ印字し直すプリティプリンタ `toPattern` のテストで始まっていて、green のコミットはその実装も含んでいます。これはこれでひとつの物語なので — [次章](./pretty-printing.md) をまるごともらいます。

## コンパイラが検査しない法則

`Semigroup` と `Monoid` には法則が付いてきます — 結合法則と、左右両側の単位元性です。上のコードには、それを証明するものは何もありません。コンパイラが検査するのは、`(<+>)` と `neutral` が正しい*型*を持つことだけ。`cat` が本当に結合的かどうかは、私たちが立てる約束であって、ここで Idris が検証してくれるものではありません。

その約束はそもそも真なのでしょうか?ほぼ真、です。`cat` と `alt` は、*マッチャとして*は結合的で、単位元も持ちます — どちらの順で結合しても、受理する文字列は同じです。しかし木として額面どおりに見ると、スマートコンストラクタの簡約のせいで、隅のケースでは法則の両辺の形が食い違うことがあります。私たちのスペックは法則を例で抜き打ち検査していますが、これはあらゆる Haskell の型クラスが受け入れているのと同じ取引です。

ただ、法則がどんな種類の文なのかに注目してください:「**すべての** `a`、`b`、`c` について……」。テストにできるのは、その有限個の実例を確かめることだけです。Idris はもっとうまくやれます — for-all の文を*型*として述べ、その証明をコンパイル時に検査できるのです。これは言葉のあやではありません。[2 章先](./proofs.md) の話です。

## 言語がいま何をしてくれたか

この章のひとつの大きなアイデアをおさらいしましょう:型クラス風のインターフェースを持つたいていの言語では、「実装は型ごとにひとつ」が固い規則で、逃げ道はラッパー型の発明です。Idris では、実装はふつうの名前付きの値です — だから規則は「型ごとに*デフォルト*はひとつ、名前付きの代替はいくらでも」まで柔らかくなり、`@{name}` が呼び出し側で選びます。包むことも剥がすこともなし。型は最初から最後まで `Regex` のまま — 帽子をかぶり替えるのは代数だけです。

## まとめ

- インターフェースは契約。実装は、それを果たす、コンパイラが組み立てる値。`Show a =>` のような制約は、その値をコンパイル時に黙って要求します。
- 半群は結合的な `<+>` を持つ型。モノイドはそこに単位元を加えたもの。文字列はモノイドをひとつ、数はふたつ持ちます — それこそが厄介の種でした。
- `Regex` もまた二重のモノイドです:単位元 `Eps` の連接と、単位元 `Fail` の選択。
- Idris の名前付き実装(`[SeqMonoid] Monoid Regex using SeqSemigroup where ...`)は、両者をひとつの型の上に共存させ、`@{SeqMonoid}` で明示的に選ばせます — Haskell が newtype ラッパーに手を伸ばすところです。
- `anyOf = foldr alt Fail` は選択モノイドの実践で、`anyOf [] = Fail` はタダで付いてきます。
- モノイドの法則は、ここではコンパイラが検査しない契約です — しかし Idris には検査できます。[テストが定理になる](./proofs.md) で、実際にやります。

同じ green のコミットは、エンジンに自分のパターンを印字し直すことも教えていました — その物語は [パターンを印字し直す](./pretty-printing.md) が語ります。
