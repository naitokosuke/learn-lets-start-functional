---
title: "matches:エンジン完成"
description: 微分を入力全体に畳み込んで，最後にnullableに尋ねます．完全なマッチャーがたった1行で書けてしまいます．
---

# matches:エンジン完成

両方の半分がそろいました．[nullable](./07-nullable.md)はパターンが空の入力で満足かどうかを尋ね，[微分](./08-derivatives.md)はパターンに1文字を食べさせます．この章で2つを組み合わせれば，エンジンは完成です！

## 問い

正規表現`r`は，文字列`s`の全体にマッチするでしょうか?

作戦はもうご存じかと思います．直前の2章こそが作戦だったからです．まずパターンを取ります．`s`の最初の文字を食べさせると，微分が「残りのためのパターン」を返してくれます．*その*パターンに2文字目を食べさせます．左から右へ，1文字につき微分1回，これを繰り返します．文字列が尽きたら，手元に残ったパターンに尋ねます．ここで止まって満足か，つまり空文字列にマッチするか?それが`nullable`です．答えがyesなら，`r`は`s`にマッチしました．noなら，マッチしませんでした．

探索も，やり直しも，「別の枝を試す」もありません．すべての選択肢は，最初から最後まで木の中で一緒に進んでいました．

## red:エンドツーエンドの期待値

コミット[d1a0950](https://github.com/ubugeeei-prod/lets-start-functional/commit/d1a0950d782a395e88108ab18a3d95b4878b976e)は，これまでで最大のスペック一覧を`regex/tests/src/Spec/Core.idr`に追加します．初めて，木ではなく*文字列*に対するテストです．

```idris
||| `matches r s` — the whole engine, end to end: derive once per
||| character, then ask `nullable`. Full-string semantics.
export
matchesSpecs : List Spec
matchesSpecs =
  [ it "a literal matches itself"
      (matches (Lit 'a') "a")
  , it "a literal rejects a different character"
      (not (matches (Lit 'a') "b"))
  , it "Eps matches the empty string"
      (matches Eps "")
  , it "matching is exact: 'a' does not match \"ab\""
      (not (matches (Lit 'a') "ab"))
  , it "a sequence matches its halves in order"
      (matches (Cat (Lit 'a') (Lit 'b')) "ab")
  , it "a sequence cares about order"
      (not (matches (Cat (Lit 'a') (Lit 'b')) "ba"))
  , it "a choice accepts its left branch"
      (matches (Alt (Lit 'a') (Lit 'b')) "a")
  , it "a choice accepts its right branch"
      (matches (Alt (Lit 'a') (Lit 'b')) "b")
  , it "a choice rejects anything else"
      (not (matches (Alt (Lit 'a') (Lit 'b')) "c"))
  , it "a* matches the empty string"
      (matches (Star (Lit 'a')) "")
  , it "a* matches one repetition"
      (matches (Star (Lit 'a')) "a")
  , it "a* matches many repetitions"
      (matches (Star (Lit 'a')) "aaaaaa")
  , it "a* rejects intruders"
      (not (matches (Star (Lit 'a')) "aaba"))
  , it "(ab)* matches whole pairs only"
      (matches (Star (Cat (Lit 'a') (Lit 'b'))) "abab")
  , it "(ab)* rejects a dangling half pair"
      (not (matches (Star (Cat (Lit 'a') (Lit 'b'))) "aba"))
  , it "(a|b)*c — a taste of a real pattern"
      (matches (Cat (Star (Alt (Lit 'a') (Lit 'b'))) (Lit 'c')) "abbac")
  ]
```

実行する前に，ひとつだけ注目してほしいスペックがあります．`'a' does not match "ab"`です．この`matches`は**文字列全体マッチ(full-string semantics)**です．つまり，パターンは入力の*すべての*文字を最初から最後まで説明しきらなければなりません．PythonやJavaScriptでおなじみの正規表現関数とは違うので注意してください．あちらはデフォルトで，文字列の中のどこかにあるマッチを*検索*します．全体マッチのほうが，より綺麗なプリミティブです．検索は全体マッチの上に構築できます（[公開APIの章](./15-public-api.md)で実際にそうします）が，その逆はできません．

一覧の残りは，6つのコンストラクタの組み合わせ技です．`Cat`は順序を気にして，`Alt`はどちらの枝でもよく，`Star`は0回でも1回でも何回でも受けるけれど，闖入者や片割れだけのペアは拒みます．最後のスペックは，すべての可動部品を一度に載せた最初のパターンです．`(a|b)*c`対`"abbac"`です．

例の如く，まずはredです．

```
2/3: Building Spec.Core (src/Spec/Core.idr)
Error: While processing right hand side of matchesSpecs. Undefined name matches.

Spec.Core:116:8--116:15
 116 |       (matches (Cat (Star (Alt (Lit 'a') (Lit 'b'))) (Lit 'c')) "abbac")
              ^^^^^^^
```

## green:1行

コミット[d8e7c5c](https://github.com/ubugeeei-prod/lets-start-functional/commit/d8e7c5c6f718face87df0d6c11e42b6a54dfc339)，`regex/src/Regex/Core.idr`にて．スペック16本に対して，実装は1行です．

```idris
||| Does `r` match the whole string `s`?
|||
||| The entire matching algorithm is one line: fold `deriv` over the
||| characters, then ask `nullable` about what is left.
|||
||| ```
||| matches r "abc"
|||   = nullable (deriv 'c' (deriv 'b' (deriv 'a' r)))
||| ```
|||
||| Each character is consumed exactly once, left to right. There is
||| no backtracking to blow up on adversarial input — the number of
||| derivative steps is always exactly the length of the string.
||| That is the "linear time" in this book's title.
public export
matches : Regex -> String -> Bool
matches r s = nullable (foldl (flip deriv) r (unpack s))
```

`foldl`に会ったことがなければ，この1行は少し濃く見えるかと思います．内側から外へ，順にほどいていきましょう．

**`unpack s`**は文字列を文字のリストに変えます．`unpack "abc"`は`['a', 'b', 'c']`です．Idrisの文字列はプリミティブ型で，`unpack`はそのリストとしての見方を与えてくれます．再帰と相性のよいコードが欲しがるのは，こちらの形です．

**`foldl`**は，関数型の世界における「左から右への蓄積ループ」です．`foldl step start xs`はリスト`xs`を端から歩きながら，累積値を運びます．`start`から始めて，各要素`x`について新しい累積値`step acc x`を計算します．JavaScriptを知っているなら，これはまさに`xs.reduce(step, start)`です．

ここでの累積値は，*パターンそのもの*です．`r`から始めて，各文字がパターンをその微分へと変換していきます．アキュムレータは進化し続けるパターン，つまり「もし文字列がここから始まるとしたら，まだマッチさせる必要のある正規表現」です．

**`flip deriv`**は小さなアダプタです．`foldl`はステップ関数に引数を「(累積値,要素)」の順で渡します．パターンが先，文字が後です．ところが`deriv`は文字を先に取ります（`deriv c r`ですね）．`flip`は関数の2つの引数を入れ替えるので，`flip deriv`は「パターン，それから文字」の順で受け取ります．仕事はそれだけです．`flip f x y = f y x`，それ以上の神秘はありません．

**`nullable (...)`**が，生き残ったパターンに最後の問いを投げかけます．

`"abc"`に対して，この畳み込みはdocコメントにあるパイプラインへと正確に展開されます．

```idris
matches r "abc"
  = nullable (deriv 'c' (deriv 'b' (deriv 'a' r)))
```

`'a'`で微分して，次に`'b'`，次に`'c'`，そして`nullable`に尋ねる．これがエンジンの全貌です．さて，走らせてみましょう．

```sh
make test
```

```
  ok    true is true
  ...
  ok    a nullable head lets the character reach the tail too
  ok    a literal matches itself
  ok    a literal rejects a different character
  ok    Eps matches the empty string
  ok    matching is exact: 'a' does not match "ab"
  ok    a sequence matches its halves in order
  ok    a sequence cares about order
  ok    a choice accepts its left branch
  ok    a choice accepts its right branch
  ok    a choice rejects anything else
  ok    a* matches the empty string
  ok    a* matches one repetition
  ok    a* matches many repetitions
  ok    a* rejects intruders
  ok    (ab)* matches whole pairs only
  ok    (ab)* rejects a dangling half pair
  ok    (a|b)*c — a taste of a real pattern
43/43 passed
```

## 触って遊ぶ

スイートはgreenですが，自分の手でいろいろマッチさせてみるのがいちばんです．`regex/`ディレクトリで`make repl`（または`idris2 --repl regex.ipkg`）を実行すると，ライブラリを読み込んだ状態のREPLが開きます．

```repl
Main> :module Regex.Core
Imported module Regex.Core
Main> :let r = Cat (Star (Alt (Lit 'a') (Lit 'b'))) (Lit 'c')
Main> matches r "abbac"
True
Main> matches r "c"
True
Main> matches r "abca"
False
Main> matches r ""
False
Main> deriv 'a' (Lit 'a')
Eps
```

`r`は木で表した`(a|b)*c`です．`"abbac"`はマッチしますし，ただの`"c"`もマッチします（スターが0回の繰り返しを選んだ形です）．`"abca"`は失敗します．`c`のあと，パターンは文字列がそこで終わることを望んでいたのに，全体マッチの意味論のもとでは，ぶら下がった`a`が命取りになります．そして`deriv`を直接呼べば，エンジンの1ステップだけを切り出して観察できます．パターンが入って，パターンが出てくる．すべてが観察可能です．表示すべき隠れたマッチャーの状態は，そもそも存在しません．

## 線形時間の正直な言い方

docコメントは，これが本書のタイトルにある「線形時間」だと主張しています．その主張を，注意深く述べ直してみましょう．

長さ*n*の入力に対して，`matches`が実行する微分のステップ数は**ちょうど*n*回**です．1文字につき1回，それを超えることはありません．各文字はちょうど一度だけ消費され，入力を読み直すことはなく，バックトラックもありません．選択が現れたとき，`deriv`は「1つ試して，失敗して，巻き戻す」のではなく，木の中の*すべての*枝を同時に前進させます．バックトラック型エンジンの最悪ケースは，`(a|a)*`のようなパターンで組合せ的に爆発します（[正規表現エンジンとは](./02-regex-engines.md)の章で予告した，現実世界の障害の裏にある病理です）．このエンジンには「戻る」を表現する術がありません．ステップ数が*n*であることは，作りからして保証されています．

さて，正直なニュアンスも添えておきます．ステップの*数*は入力に対して線形ですが，*各ステップのコスト*はパターンの木のサイズに依存します．`deriv`は木を歩きますし，前の章のガラクタまみれの期待値が示したとおり，生の微分は木を*成長*させることがあります．各ステップを安く保てるようこの成長を飼いならすのは本物のエンジニアリング課題で，そこで登場するのが[スマートコンストラクタ](./10-smart-constructors.md)です．物語の全貌は（本物のバックトラッカーとの計測対決も含めて）[対決:線形時間vsバックトラック](./19-the-race.md)の章の主題です．

正直な制限があと2つありますが，どちらも一時的なものです．`matches`はBooleanです．yesかnoかを言うだけで，*どこで*・*何が*マッチしたのかは教えてくれません．そして，全体マッチ専用です．長い文字列の中からパターンを検索する機能は，[公開APIの章](./15-public-api.md)でこの上に構築します．

## この言語にループのキーワードはない

すべての仕事をこなした1行を，もう一度見てみましょう．

```idris
matches r s = nullable (foldl (flip deriv) r (unpack s))
```

エンジンのマッチングルーチンは，考えうる限りもっともループの形をしたコードです（*各文字について，状態を更新する*）．Idrisには`for`も`while`もありませんが，これを書いていて困ることは一度もありませんでした．`foldl`がループ**そのもの**だからです．「リストを歩き，値を運ぶ」というパターンを，一度だけ，正しく捕まえた普通の関数です．`flip`は，関数どうしをはめ合わせるための，ごく小さな接着剤です．どちらも*高階関数(higher-order function)*（引数がそれ自体関数であるような関数）で，この1行こそ，高階関数が速習の中の珍しい見世物であることをやめて，本物のエンジンのメインループになる瞬間です．

これが関数型の取引で，本書全体が繰り返し結んでいく取引でもあります．ものごとをデータとして表現して（`Regex`），そのデータの上に小さな全域関数を書いて（`nullable`，`deriv`），特注の機構ではなく汎用のコンビネータ（`foldl`，`flip`）で合成する，という流れです．コンストラクタが6つ，等式が6本，さらに6本，畳み込みが1つ．それで，バックトラックしたくてもできない正規表現エンジンの出来上がりです！

> [!NOTE]
> マイルストーンです！この章をもって，*完全に動作する線形時間の正規表現マッチャー*が手に入りました．データ型とその上の3つの関数（`nullable`，`deriv`，`matches`）を合わせて，Idrisのコードはおよそ30行です．ここから先（単純化，文字クラス，糖衣構文，パース，証明）はすべて，エンジンをより快適に，より表現力豊かに，より信頼できるものにしていく作業です．

## まとめ

- `matches r s`は「`r`は`s`の*全体*にマッチするか?」に答えます．文字列に沿って`deriv`を畳み込んで，最後に`nullable`に尋ねる．コードは1行です．
- `unpack`が文字を列挙し，`foldl`が進化するパターンを運び，`flip`が引数の順序を合わせ，`nullable`が判定を下します．`"abc"`に対する畳み込みは`nullable (deriv 'c' (deriv 'b' (deriv 'a' r)))`です．
- 意味論は文字列全体マッチ（`Lit 'a'`は`"ab"`にマッチしません）かつBooleanです．文字列内の検索や，より豊かな結果は[公開API](./15-public-api.md)とともにやって来ます．
- ステップ数は入力の長さと厳密に一致します．バックトラックも読み直しもありません．ステップあたりのコストはパターンのサイズに依存します（このニュアンスは[スマートコンストラクタ](./10-smart-constructors.md)と[対決:線形時間vsバックトラック](./19-the-race.md)の章が引き受けます）．
- `foldl`と`flip`（高階関数）がエンジンのメインループです．この言語にループのキーワードはありませんが，特に困りませんでした．
- スイートは43/43です．動作確認，AST，`nullable`，`deriv`，そしてエンドツーエンドのマッチ16本，すべてgreenです！

エンジンは動きます！が，微分が生むガラクタの木はまだ潜んでいます．次の章の[スマートコンストラクタ](./10-smart-constructors.md)で，組み立てながら片付けることをコンストラクタに教えていきましょう．
