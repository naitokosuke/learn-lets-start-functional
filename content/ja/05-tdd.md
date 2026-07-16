---
title: TDDと小さなテストハーネス
description: テストファーストが型のある言語でこそさらに効く理由と，「純粋なコア，IOの殻」という原則が初登場する70行ちょっとの完全なテストハーネス．
---

# TDDと小さなテストハーネス

イントロダクション最後の章にして，プロジェクトに残り続けるコードを書く最初の章です．本書がここから作るものはすべてテストに駆動されるので，まずテストを走らせる何かが必要になります．そして，それを自作するのがちょうど良い最初の練習問題になります．

## テストファースト，この言語で?

本書のリズムは古典的なテスト駆動開発です．失敗するテストを書いて(red)，それを通す最小のコードを書いて(green)，繰り返す．TDDの経験があればおなじみかと思います．なければ，売り文句は短いです．テストを先に書くと，どう書くかを決める前に何をすべきかを決めさせられますし，書いた後もテストは番人として残ってくれます．

もっともな疑問がひとつあります．強い型チェッカーを持つ言語に，そもそもこれは必要なのか?コンパイラが全部捕まえてくれるのでは?という疑問です．

答えは「必要」です．この2枚のセーフティネットは受け止めるものが違います．型チェッカーが検証するのは，コードが首尾一貫していることです．すべてのケースが処理され，すべての型がかみ合い，(`%default total`のおかげで)すべての再帰が停止する．しかし，`a*`の`a`に関する微分が`a*`であるべきだ，ということは型チェッカーには知りようがありません．それは正規表現についての事実であって型についての事実ではなく，そこを固定できるのはテストだけです．逆に，テストスイートはいくつかの点をつまみ食いするだけですが，型チェッカーはすべての入力について形を証明します．なので，両方のネットを常に全力で張っておきたいわけです．

さらに良いことに，コンパイルされる言語ではこの2枚のネットが1つのワークフローに合流して，うれしい性質が生まれます．**コンパイラこそが最初のテストです．**新しいスペックがまだ存在しない関数を参照すると，スイートは走って失敗するのではなく，コンパイルに失敗します．

```
Error: While processing right hand side of astSpecs. Undefined name Cat.
```

これはTDDの障害物ではありません．これこそがredです．コンパイルエラーは一番正直な失敗するテストですし(プログラムが始まる前にもう失敗しています)，本書のredフェーズの大半はまさにこの形で始まります．redは「世界はまだこのスペックを満たしていない」という意味なので，「世界にはまだこの名前すら存在しない」は文句なしにredです．

というわけで，テストハーネスが必要です．ただ，インストールはしません．プロジェクトを依存ゼロに保つため([環境構築](./03-setup.md)で約束したとおり，コンパイラ以外なし)でもありますが，それ以上に，テストハーネスが自作にうってつけの題材だからです．小さくて，実用的で，こっそり関数型設計のレッスンにもなっています．今回作るものは70行ちょっとで，これを上から下までまるごと見ていきます．住所は[regex/tests/src/Harness.idr](https://github.com/ubugeeei-prod/lets-start-functional/blob/main/regex/tests/src/Harness.idr)です．ちなみに，このファイルはコミットされた日から一度も変わっていません．73行，初日に完成です．

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

(新しい記法について: `|||`で始まる行はdocコメントで，直下の宣言に付きます．`public export`は`Spec`を(コンストラクタもフィールドも含めて)他のモジュールから見えるようにします．すぐ後に出てくる素の`export`は，名前だけを公開します．)

他のすべてを形作る設計判断が，このレコードに入っています．`Spec`が持つのは`Bool`であって，後で呼ぶための関数ではない，という点です．JestやJUnitやpytestから来た人にとって，「テスト」とはフレームワークに登録するコールバックです．いつ呼ぶかはフレームワークが決め，投げられたものを捕まえ，見えない機構を通して報告してくれます．ここにはフレームワークがなく，呼び出すものもありません．`Spec`が存在する時点で，肝心の式(`1 + 1 == 2`や，ゆくゆくは`matches r "aaa"`)は，スペックを書いたその場所ですでに評価済みです．テストは管理すべき計算ではなく，報告すべき結果です．説明と判定と詳細，ただのデータが3フィールド，という感じです．

なぜそれで安全なのでしょうか?純粋な言語では，評価がそのまま実行だからです．`matches r "aaa"`のような式は，ファイルに書き込むことも，ネットワークで固まることも，隣のスペックに干渉することもできません．評価して出てくるのは値だけです．テストフレームワークが作用を囲い込むために組み上げる機構(セットアップとティアダウン，分離，実行順)には，ここでは仕事がありません．ただのデータに監督は不要です．

## Specの作り方は2通り

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

`it`は素の真偽値を包みます．`shouldBe`は2つの値を比較して，(これこそが存在理由ですが)両者を引用した便利な失敗メッセージをあらかじめ焼き込んでおきます．

`shouldBe`のシグネチャを[速習コース](./04-idris-crash-course.md)の目で見てみてください．どんな型`a`でも動きますが，無条件ではありません．定義が`==`を使うので`Eq a`が要り，失敗メッセージが`show`を使うので`Show a`が要ります．この制約はボイラープレートではなく，関数の必要物を型に書いてコンパイラに検査させたものです．`Show a =>`を消すと，値を表示する手段がなくなるので定義はコンパイルできなくなります．(`(actual : a)`という構文はシグネチャの引数に名前を付けるだけのものです．型チェッカーが正直さを保ってくれるドキュメント，という感じです．)

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

たいていの言語で身についた本能は，これを「合格の行を印字する，あるいは失敗の行を印字する」と書くことかと思います．`render`はそれを拒否します．文字列を計算して返すだけで，何も印字しません．どうでもいい違いに見えるかもしれませんが，テストハーネス自体をテストしようとしたときや，レポートをソートしたりフィルタしたりファイルに書き出したくなったときに効いてきます．`String`を返す関数はそのすべてとタダで合成できますが，印字する関数は何とも合成できません．可能な限り純粋に，作用は最後の最後に，です．

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

docコメントに書いてあるとおり，ハーネスの中で`IO`が姿を見せるのはここだけです．そして，これを呼ぶ`main`を除けば，このテストスイート全体で書く`IO`もここだけです．すべてが1つの`do`ブロックへ流れ込み，行を印字し，サマリを印字し，終了コードを設定します(この`exitFailure`のおかげで`make test`はCIビルドを落とせます．`import System`はこのためでした)．

本体は速習コースの回収ツアーです．`traverse_ (putStrLn . render) specs`は「各スペックについて，renderして印字」と読めます．`.`が2つの関数を合成し，`traverse_`がその結果のアクションをリスト全体に走らせます．`filter passed specs`は地味な見せ場です．`passed`はレコードのフィールドですが，フィールドはただの関数`Spec -> Bool`なので，そのまま`filter`にはまります．合格数は`filter`の`length`で数えます．レコードのdocコメントにあった「純粋な値は数えるのもフィルタするのも表示するのも簡単」という約束の回収です．そして例のFun factのとおり，そのカウントは`passedCount`に入っています．一番自然な名前がキーワードだからです．最後に細かい注意書きをひとつ．`runSpecs`には`covering`が付いています．`total`というゴールドスタンダードの1段下の誠実さレベルです．「あらゆる入力で停止する」という厳しい規律は純粋なコアについての約束で，この関数はその縁に立っている，という目に見える小さな旗になっています．

この形，つまり純粋なコアとIOの殻は，本書で最初の本格的に関数型な設計アイデアです．ハーネスを自作するのは，これに小さいスケールで出会ってもらうためでもあります．純粋なデータと純粋な関数のファイルの底に，薄い不純な皮が1枚だけ．正規表現エンジンも同じシルエットになりますが，皮はさらに薄くなります．ゼロ枚です．

## 配線する

ハーネスにはエントリポイントが必要です．コミットされた時点の`tests/src/Main.idr`がこちらで，サニティチェックのスペック3本とランナーです(このファイルはスペックモジュールが増えるたびに数行ずつ育ちます．ハーネス自体は二度と変わりません)．

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

スペックはデータなので，スペックのスイートは`List Spec`で，スイートの合成は`++`です．拡張モデルはこれで全部で，docコメントは常設の招待状になっています．本書の残りでは，機能のテストを足すことは，リストをもう1本エクスポートしてここで連結することを意味します．

[環境構築の章](./03-setup.md)で約束していたパッケージファイル`tests/tests.ipkg`はこちらです．

```ipkg
package regex-tests
version = 0.1.0

depends = regex

sourcedir = "src"
main = Main
executable = tests

modules = Main
        , Harness
```

`depends = regex`が(Makefileの`depends/`トリック経由で)ライブラリを指し，`main`/`executable`がこのパッケージを`tests`という名前の実行可能プログラムにします．一方，この時点の歴史では，ライブラリ本体は儀式だけのモジュール1つです．`src/Regex/Core.idr`の全文がこちらです．

```idris
||| The heart of the engine.
|||
||| This module will grow, test by test, into a complete regular
||| expression matcher based on Brzozowski derivatives.
module Regex.Core

%default total
```

docコメントと，モジュール宣言と，全域性の誓い．さて，動かしてみましょう．

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

`3/3 passed`です！ハーネスが動くことを，ハーネス自身が検証しました．本書のブートストラップ度はこれが最高値です．念のため，物事がうまくいかないときの見た目も確認しておきましょう(2本目のスペックを`3`を期待するように改造して再実行します)．

```
  ok    true is true
  FAIL  one plus one is two
        expected 3, got 2
  ok    strings concatenate
2/3 passed
make: *** [test] Error 1
```

`shouldBe`の焼き込みメッセージが仕事をして，`exitFailure`が`make`まで伝播しています．本書で`FAIL`の行を見ることはあまりありませんが，それは各失敗がすぐ次の節で直されるからにすぎません．

## リズムと，その見どころ

ここから最後まで，プロジェクトのgit履歴は厳格なビートを刻みます．1ステップにつきコミット2つです．まずスペックを足すコミット．メッセージは`(red)`で終わり，そのコミットでは`make test`が失敗します(ほぼ常にコンパイルエラーとしてです．スペックが存在しない名前を参照するので)．続いて，それを満たす最小の実装のコミット．こちらは`(green)`で終わり，そのコミットでスイートは再び通ります．履歴が壊れているのはredのコミットの位置だけで，そこはわざと壊してあります．各テストが実際に何を要求したかのドキュメントです．

最初のフルサイクルは，スキャフォールドのすぐ先で待っています．この章の内容をすべて追加した[スキャフォールドのコミット](https://github.com/ubugeeei-prod/lets-start-functional/commit/fd1795e068cc36e9d12604bea38b0bb03fa14cfb)，続いて[`test(core): specs for the Regex AST (red)`](https://github.com/ubugeeei-prod/lets-start-functional/commit/51d326b5444518b66b8b9ed0b468352ff048a63e)，そして[`feat(core): the Regex AST — six constructors, Show, Eq (green)`](https://github.com/ubugeeei-prod/lets-start-functional/commit/832542c132ce21d2b7902207cc654ca9621f02fd)です．この章の冒頭で引用した`Undefined name Cat`のエラーは，そのredコミットで`make test`が出力するものそのままです．`Cat`はスペックが要求する6つのコンストラクタのひとつで，空の`Regex.Core`はまだそれを提供していません．

これが次の章の合図です．イントロダクションは終わり，本書最初の本物の問いに答えるときが来ました．正規表現とは，データとしては，正確には何なのでしょうか?

## まとめ

- 型チェッカーとテストスイートは捕まえるものが違います．すべての入力についての首尾一貫性と，選んだ点での意味です．本書は両方を全力で使います．
- コンパイルされる言語ではコンパイラが最初のテストです．未定義の名前を参照するスペックはコンパイル時に失敗し，それは正当なredです．
- `Spec`は評価済みのデータ(説明，判定，詳細)です．純粋な評価には監督すべき作用がないので安全で，フレームワークは要りません．
- スペックを作るのは`it`と`shouldBe`です．`shouldBe`の`Show a => Eq a =>`という制約は，必要なものを過不足なく型で述べています．
- `render`は印字せずに文字列を計算します．`runSpecs`はスイート全体で唯一の`IO`関数です．エンジンでも繰り返される「純粋なコア，IOの殻」のシルエットです．
- スイートは`List Spec`で，`++`で合成します．スキャフォールドでの`make test`は`3/3 passed`を報告し，失敗時はexpectedとactualの両方を印字してビルドを落とします．
- リポジトリの履歴は`(red)`のスペックコミットと`(green)`の実装コミットの交互です．残りのすべての章がこのビートで進みます．

最初の本物のredの時間です．[正規表現はデータである](./06-regex-as-data.md)では，スペックがまだ存在しない6つのコンストラクタを要求し，コンパイラが気持ちのよい拒否で応えます．
