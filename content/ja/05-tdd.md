---
title: TDD と小さなテストハーネス
description: テストファーストが型のある言語でこそさらに効く理由と、「純粋なコア、IO の殻」という原則がデビューする、70 行の完全なテストハーネス。
---

# TDD と小さなテストハーネス

これはイントロダクション最後の章にして、プロジェクトに残り続けるコードを書く最初の章です。本書がここから作るものはすべてテストに駆動されるので、まずはテストを走らせる何かが必要です——そしてそれを自作することが、最高の最初の練習問題になるのです。

## テストファースト、この言語で?

本書のリズムは古典的なテスト駆動開発です。失敗するテストを書き(*red*)、それを通す最小のコードを書き(*green*)、繰り返す。TDD の経験があれば、おなじみでしょう。なければ、売り文句は短めです。テストを先に書くと、コードを*どう*書くかを決める前に*何をすべきか*を決めることを強いられ、しかもその後、テストは番人として残ってくれます。

もっともな疑問が 1 つ。強い型チェッカーを持つ言語に、そもそもこれは必要でしょうか?コンパイラがすでに全部捕まえてくれるのでは?

いいえ——この 2 枚のセーフティネットは、受け止める曲芸師が違うのです。型チェッカーが検証するのは、コードが*首尾一貫している*こと。すべてのケースが処理され、すべての型がかみ合い、(`%default total` のおかげで)すべての再帰が停止する。しかし、`a*` の `a` に関する微分が `a*` であるべきだ、ということは知りようがありません。それは*正規表現についての*事実であって、型についての事実ではなく、それを釘で留められるのはテストだけです。逆に、テストスイートはいくつかの点を標本にするだけですが、型チェッカーは*すべての*入力について形を証明します。両方のネットを、常に全力で張っておきたいのです。

さらに良いことに、コンパイルされる言語ではこの 2 枚のネットが 1 つのワークフローに合流し、うれしい性質が生まれます。**コンパイラこそが最初のテストなのです。** 新しいスペックがまだ存在しない関数を参照すると、スイートは走って失敗するのではなく——*コンパイル*に失敗します。

```
Error: While processing right hand side of astSpecs. Undefined name Cat.
```

これは TDD の障害物ではありません。これ*こそ*が red です。コンパイルエラーは、この世で一番正直な失敗するテストです——プログラムが始まる前にもう失敗しているのですから——そして本書では、ほとんどの red フェーズがまさにこの形で始まります。red は「世界はまだこのスペックを満たしていない」という意味であり、「世界にはまだこれらの名前すら存在しない」は、その資格を堂々と満たしています。

というわけで、テストハーネスが必要です。インストールはしません——プロジェクトを依存ゼロに保つため([環境構築](./03-setup.md)で約束したとおり、コンパイラ以外なし)でもありますが、それ以上に、テストハーネスは自作するのにうってつけの題材だからです。小さく、有用で、こっそり関数型設計のレッスンでもある。私たちのものは 70 行と少し。それを上から下まで、まるごとお見せします。住所は [regex/tests/src/Harness.idr](https://github.com/ubugeeei-prod/lets-start-functional/blob/main/regex/tests/src/Harness.idr)——そして特筆すべきことに、このファイルはコミットされた日から一度も変わっていません。73 行、初日に完成です。

## テストはデータ

```idris
||| A tiny test harness — small enough to read in one sitting.
|||
||| There is no magic here: a test is just *data* (a `Spec` record),
||| and running the suite is just *a fold over a list*. Building the
||| harness ourselves is the first taste of a very functional idea:
||| keep the core pure, push effects (printing, exiting) to the edge.
module Harness

import System

%default total

||| The outcome of a single, already-evaluated test case.
|||
||| Note that a `Spec` holds a `Bool`, not a computation: by the time
||| you have a `Spec` in your hands, the test has already run. Pure
||| values are easy to store, count, filter, and print.
public export
record Spec where
  constructor MkSpec
  ||| Human-readable description of the expectation.
  description : String
  ||| Did the expectation hold?
  passed : Bool
  ||| Extra context, shown only when the expectation failed.
  details : String
```

(新しい記法:`|||` で始まる行は doc コメントで、直下の宣言に付属します。`public export` は `Spec` を——コンストラクタもフィールドも含めて——他のモジュールから見えるようにします。この後出てくる素の `export` は、名前だけを公開します。)

ほかのすべてを方向づける設計判断が、このレコードにあります。`Spec` が抱えているのは `Bool` であって、後で呼ぶための関数ではありません。Jest や JUnit や pytest から来た人にとって、「テスト」とはフレームワークに登録するコールバックです。いつ呼ぶかはフレームワークが決め、投げられたものを捕まえ、あなたには見えない機構を通じて報告する。ここにはフレームワークもなければ、呼び出すものもありません。`Spec` が存在する時点で、関心の的である式——`1 + 1 == 2`、やがては `matches r "aaa"`——は、スペックが書かれたまさにその場所で、*すでに評価済み*なのです。テストは、管理されるべき計算ではありません。報告されるべき結果です。説明、判定、詳細。素のデータが 3 フィールド。

なぜそれで安全なのでしょう?純粋な言語では、評価こそが実行だからです。`matches r "aaa"` のような式には、ファイルへの書き込みも、ネットワークでのハングも、隣のスペックへの干渉もできません——評価から生まれうるのは値だけです。テストフレームワークが作用を囲い込むために築き上げる機構のすべて——セットアップとティアダウン、隔離、実行順序——には、やる仕事がありません。囲い込むべき作用が存在しないからです。データにお目付け役は要らないのです。

## Spec の作り方、2 通り

```idris
||| Expect a boolean condition to hold.
|||
||| ```idris example
||| it "the empty list has length zero" (length [] == 0)
||| ```
export
it : String -> Bool -> Spec
it desc ok = MkSpec desc ok "expected the condition to hold"

||| Expect two values to be equal, reporting both sides when they differ.
|||
||| The constraints tell the whole story: we need `Eq` to compare the
||| values and `Show` to print them in the failure report.
|||
||| ```idris example
||| shouldBe "one plus one" (1 + 1) 2
||| ```
export
shouldBe : Show a => Eq a => String -> (actual : a) -> (expected : a) -> Spec
shouldBe desc actual expected =
  MkSpec desc (actual == expected)
    ("expected " ++ show expected ++ ", got " ++ show actual)
```

`it` は裸の真偽値を包みます。`shouldBe` は 2 つの値を比較し——そしてこれが存在理由のすべてですが——両辺を引用した有用な失敗メッセージを、あらかじめ焼き込んでおきます。

`shouldBe` のシグネチャを、[速習コース](./04-idris-crash-course.md)の目で見てください。任意の型 `a` に働きます——ただし無条件ではありません。定義が `==` を使うから `Eq a` が要り、失敗メッセージが `show` を使うから `Show a` が要る。制約はボイラープレートではありません。この関数が必要とするものを型の中で述べたものであり、コンパイラがそれを検査します。`Show a =>` を消すと、定義はコンパイルを通らなくなります。値を表示する手段がなくなるからです。(`(actual : a)` という構文は、シグネチャの中で引数に名前を付けているだけ——型チェッカーが正直さを保証してくれるドキュメントです。)

## レポートも純粋

```idris
||| Render one spec as a report line. Pure: no printing happens here.
export
render : Spec -> String
render spec =
  if spec.passed
    then "  ok    " ++ spec.description
    else "  FAIL  " ++ spec.description ++ "\n        " ++ spec.details
```

たいていの言語で染みついた本能は、これを「合格の行を出力する、さもなくば失敗の行を出力する」と書かせようとします。`render` は乗りません。*文字列を計算して*、手渡すだけ。何も出力しません。これは「違いのない区別」に見えますが、テストハーネスをテストしようとした瞬間、あるいはレポートをソートしたり、フィルタしたり、ファイルに書き出したくなった瞬間に効いてきます。`String` を返す関数はそのすべてとタダで組み合わせられますが、出力してしまう関数は何とも組み合わせられません。可能な限り純粋に。作用は、可能な限り最後の瞬間に。

## 唯一の不純な関数

```idris
||| Run a whole suite: print every line, then a summary, and exit
||| with a non-zero code if anything failed.
|||
||| This is the only place in the harness where `IO` shows up.
|||
||| (Fun fact: the summary variable is called `passedCount` because
||| `total` — the obvious name — is a reserved keyword in Idris!)
export
covering
runSpecs : List Spec -> IO ()
runSpecs specs = do
  traverse_ (putStrLn . render) specs
  let passedCount = length (filter passed specs)
  putStrLn $ show passedCount ++ "/" ++ show (length specs) ++ " passed"
  when (passedCount /= length specs) exitFailure
```

doc コメントが率直に言っています。ここがハーネスの中で `IO` が顔を出す唯一の場所です——そして、これを呼ぶ `main` を別にすれば、これから書くテストスイート全体でも唯一の場所です。すべてはこの 1 つの `do` ブロックへ流れ込みます。各行を出力し、サマリーを出力し、終了コードを設定する(あの `exitFailure` こそ `make test` が CI のビルドを落とせる理由で、`import System` はこのためでした)。

本体は、速習コースの学びが換金されていく展覧会です。`traverse_ (putStrLn . render) specs` は「各スペックについて:render して、出力」と読めます——`.` が 2 つの関数を合成し、`traverse_` がその結果のアクションをリスト全体に走らせます。`filter passed specs` は静かな見せ場です。`passed` はレコードのフィールドですが、フィールドはただの関数 `Spec -> Bool` なので、そのまま `filter` にはまります。合格数を数えるのは `filter` の `length`——レコードの doc コメントにあった「純粋な値は、数えるのも、フィルタするのも、表示するのも簡単」という約束の、償還です。そして例の Fun fact のとおり、そのカウントは `passedCount` に住んでいます。当たり前の名前が、キーワードだからです。最後に、細かい字の注意書きをひとつ。`runSpecs` には `covering` が付いています。`total` という金字塔のひとつ下の誠実さレベルです——「あらゆる入力で停止する」という厳格な規律は純粋なコアについての約束であり、この関数はその縁にいる、という目に見える小さな旗なのです。

この形——*純粋なコア、IO の殻(pure core, IO shell)*——は、本書で最初の正真正銘の関数型設計のアイデアです。ハーネスが存在する理由の一部は、これに小さなスケールで出会ってもらうことにあります。純粋なデータと純粋な関数のファイルの底に、薄い不純な皮が 1 枚。正規表現エンジンも同じシルエットになります。ただし皮はさらに薄く——1 枚もなし、です。

## 配線する

ハーネスにはエントリポイントが必要です。コミットされた当時のままの `tests/src/Main.idr` がこちら。サニティスペック 3 つと、ランナーです(このファイルはスペックモジュールが増えるたびに章ごとに数行ずつ育ちますが、ハーネス自体は決して変わりません)。

```idris
||| Entry point of the test suite.
|||
||| Every spec module exports a plain `List Spec`; the runner just
||| concatenates them. Adding a module to the suite is adding a list.
module Main

import Harness

||| Sanity checks for the harness itself — the very first red/green
||| cycle of this project was making these pass.
sanitySpecs : List Spec
sanitySpecs =
  [ it "true is true" True
  , shouldBe "one plus one is two" (1 + 1) 2
  , shouldBe "strings concatenate" ("fun" ++ "ctional") "functional"
  ]

main : IO ()
main = runSpecs sanitySpecs
```

スペックはデータなので、スペックの*スイート*は `List Spec` であり、スイートの合成は `++` です。拡張のモデルはこれで全部。そして doc コメントは常設の招待状です。この先の本書で、機能のテストを追加するとは、リストをもう 1 つエクスポートして、ここで連結することを指します。

パッケージファイル `tests/tests.ipkg` は、[環境構築の章](./03-setup.md)で予告したとおりです。

```
package regex-tests
version = 0.1.0

depends = regex

sourcedir = "src"
main = Main
executable = tests

modules = Main
        , Harness
```

`depends = regex` が(Makefile の `depends/` トリック経由で)ライブラリを指し、`main`/`executable` がこのパッケージを `tests` という名前の実行可能プログラムにします。一方、ライブラリ本体は、歴史のこの時点では儀式だけのモジュールが 1 個。`src/Regex/Core.idr` の全文がこちらです。

```idris
||| The heart of the engine.
|||
||| This module will grow, test by test, into a complete regular
||| expression matcher based on Brzozowski derivatives.
module Regex.Core

%default total
```

doc コメント、モジュール宣言、そして全域性の誓い。では、走らせましょう。

```
$ make test
idris2 --build regex.ipkg
1/1: Building Regex.Core (src/Regex/Core.idr)
rm -rf tests/depends/regex-0.1.0
mkdir -p tests/depends/regex-0.1.0
cp -R build/ttc/* tests/depends/regex-0.1.0/
printf 'package regex\nversion = 0.1.0\n' > tests/depends/regex-0.1.0/regex.ipkg
idris2 --build tests/tests.ipkg
1/2: Building Harness (src/Harness.idr)
2/2: Building Main (src/Main.idr)
Now compiling the executable: tests
./tests/build/exec/tests
  ok    true is true
  ok    one plus one is two
  ok    strings concatenate
3/3 passed
```

`3/3 passed`——ハーネスは動きます。しかも自分自身によって検証されて、です。本書のブートストラップ度は、ここが最高値です。念のため、うまくいかないときの姿も見ておきましょう(2 番目のスペックが `3` を期待するように仕込み直して、再実行)。

```
  ok    true is true
  FAIL  one plus one is two
        expected 3, got 2
  ok    strings concatenate
2/3 passed
make: *** [test] Error 1
```

`shouldBe` の焼き込み済みメッセージが給料分の働きをし、`exitFailure` が `make` まで伝播しています。本書で `FAIL` の行を見ることはあまりありません——ただしそれは、どの FAIL もすぐ次の節で直されるから、という理由にすぎません。

## リズムと、その見どころ

ここから最後まで、プロジェクトの git 履歴は厳格なビートを刻みます。1 ステップにつき 2 コミット。まずスペックを追加するコミット——メッセージは `(red)` で終わり、そのコミットの時点では `make test` が失敗します。ほぼ常にコンパイルエラーとして、です。スペックが、存在しないものの名前を呼ぶからです。続いて、それを満たす最小の実装のコミット——`(green)` で終わり、そのコミットの時点でスイートは再び通ります。履歴は、red コミットのちょうどその場所を*除いて*どこも壊れておらず、そしてそこでは意図的に壊されています。各テストが実際に何を要求したのかの、ドキュメントとして。

最初のフルサイクルは、scaffold のすぐ先で待っています。この章のすべてを追加した [scaffold コミット](https://github.com/ubugeeei-prod/lets-start-functional/commit/fd1795e068cc36e9d12604bea38b0bb03fa14cfb)、続いて [`test(core): specs for the Regex AST (red)`](https://github.com/ubugeeei-prod/lets-start-functional/commit/51d326b5444518b66b8b9ed0b468352ff048a63e)、そして [`feat(core): the Regex AST — six constructors, Show, Eq (green)`](https://github.com/ubugeeei-prod/lets-start-functional/commit/832542c132ce21d2b7902207cc654ca9621f02fd)。この章の冒頭で引用した、あの `Undefined name Cat` エラー?あれはまさに、その red コミットで `make test` が出力するものです——`Cat` はスペックが要求する 6 つのコンストラクタの 1 つで、空っぽの `Regex.Core` はまだそれを提供していないのです。

これが次の章への合図です。イントロダクションは終わり、本書最初の本物の問いに答えるときが来ました——正規表現とは、データとしては、正確には*何*なのか?

## まとめ

- 型チェッカーとテストスイートは捕まえるものが違います。すべての入力に対する一貫性と、選んだ点における意味——両方を全力で走らせます。
- コンパイルされる言語ではコンパイラが最初のテストです。未定義の名前を参照するスペックはコンパイル時に失敗し、それは*正当な* red です。
- `Spec` は評価済みのデータ——説明、判定、詳細——です。純粋な評価には監督すべき作用がないから安全で、だからこそフレームワークが要りません。
- `it` と `shouldBe` がスペックを作ります。`shouldBe` の `Show a => Eq a =>` という制約は、必要なものを過不足なく述べています。
- `render` は出力せずに文字列を計算し、`runSpecs` はスイート全体で唯一の `IO` 関数です——エンジンも繰り返すことになる、「純粋なコア、IO の殻」のシルエットです。
- スイートは `List Spec` で、`++` で合成します。scaffold の時点で `make test` は `3/3 passed` と報告し、失敗時には期待値と実際の値の両方を表示して、ビルドを落とします。
- リポジトリの履歴は `(red)` のスペックコミットと `(green)` の実装コミットを交互に刻みます——残りのすべての章が行進する、あのビートです。

最初の本物の red の時間です。[正規表現はデータである](./06-regex-as-data.md)では、スペックがまだ存在しない 6 つのコンストラクタを要求し、コンパイラは気持ちのいい拒絶で応えます。
