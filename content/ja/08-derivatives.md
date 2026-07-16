---
title: 微分
description: Brzozowskiの美しいアイデア「パターンに1文字を食べさせると，文字列の残りのためのパターンが返ってくる」を実装します．
---

# 微分

パターンに，空文字列にマッチするかどうかを尋ねられるようになりました（[nullable](./07-nullable.md)）．この章ではアルゴリズムのもう半分を追加します．そしてこれが，本書でいちばん美しいアイデアです．これより後の内容はすべて，このアイデアの肉付けと言ってもいいくらいです．

## パターンに投げかけるひとつの問い

いったんコードのことは忘れてください．アイデアを一文で言うとこうなります．

> このパターンが最初に文字`c`を食べなければならないとしたら，あとにはどんなパターンが残るだろうか?

これで全部です．パターンに*文字列*を食べさせるのではなく，パターンに*1文字*を食べさせて，新しいパターンを受け取ります（「この先に続くもの」がマッチすべきパターンです）．この「残りのためのパターン」を，`c`に関するパターンの**微分(derivative)**と呼びます．

この章の記法を決めておきましょう．ε は空文字列のパターン（`Eps`），∅ は何にもマッチしないパターン（`Fail`），そして「`r`の`c`による微分」という言い方をします．Idrisを書く前に，小さな例をいくつか手で微分してみましょう．

**パターン`a`に`'a'`を食べさせる．**パターンはちょうど1つの`a`を欲しがっていて，いままさにそれを受け取りました．マッチすべき残りは?何もありません．入力の残りは空でなければなりません．なので微分は ε です．

**パターン`a`に`'b'`を食べさせる．** `a`が欲しかったのに，来たのは`b`でした．これは「もう少し粘ろう」という状況ではなく，マッチは死んでいて，この先どんな入力が続いても生き返りません．微分は ∅ です．ちなみに，ここで[ASTの章](./06-regex-as-data.md)の2つの「無」がそろって働いています．ε は「残りなし」という*成功*で，∅ は「先へ進む道なし」という*失敗*です．

**パターン`ab`に`'a'`を食べさせる．**先頭の`a`が文字を消費して，残るのはその後ろのすべてです．なので微分は`b`です．連接は先頭を微分する，という感じです．

**パターン`a|b`に`'a'`を食べさせる．**選択は選びません．*両方の*枝を微分して，選択のまま残ります．左の枝`a`は ε になり，右の枝`b`は ∅ になります．なので微分は ε|∅ です．文字列の集合として見ればただの ε です（死んだ枝は何も寄与しません）が，*木*として見ると ∅ がくっついてきます．これは覚えておいてください．この章の後半で重要になります．

**パターン`a*`に`'a'`を食べさせる．**ここはゆっくり行きましょう．スターは，このアイデアの面白さがいちばん見える場所です．`a*`は0個以上の`a`という意味です．文字を1つ消費したのなら，「0回の繰り返し」という選択肢は消えました．つまりスターは*少なくとも1回の繰り返しにコミットした*ことになります．その最初の繰り返しは`a`で，いま文字を食べたばかりなので，この繰り返しに残るのは ε です．そして，どの繰り返しのあとでも，スターは続きを許されているのでした．なので残るのは「いまの繰り返しを終わらせて（ε），それから再び`a*`」です．微分は ε`a*`で，これは`a*`とまったく同じものにマッチします．それが正解です．`a`を1つ食べたあとに`a*`がなお受理する文字列は，さらに任意個の`a`だからです．

繰り返しが1回ぶん展開されて，スターはまだ走り続けています．カウンタもループも状態機械もなく，マッチの進捗はパターンそのものが運んでいます．

## red:微分を固定する

コミット[c426464](https://github.com/ubugeeei-prod/lets-start-functional/commit/c42646445a905e9474eb980c07cc0f60fae5d951)より，`regex/tests/src/Spec/Core.idr`にて．先ほどの手計算がひとつひとつそのままスペックになります．まずは葉からです．

```idris
export
derivSpecs : List Spec
derivSpecs =
  [ shouldBe "Fail stays Fail, whatever we feed it"
      (deriv 'a' Fail) Fail
  , shouldBe "Eps has nothing left to give after any character"
      (deriv 'a' Eps) Fail
  , shouldBe "consuming the right literal leaves the empty string"
      (deriv 'a' (Lit 'a')) Eps
  , shouldBe "consuming the wrong literal fails"
      (deriv 'b' (Lit 'a')) Fail
  , shouldBe "a choice derives both branches"
      (deriv 'a' (Alt (Lit 'a') (Lit 'b')))
      (Alt Eps Fail)
  , shouldBe "a star unrolls one repetition and keeps going"
      (deriv 'a' (Star (Lit 'a')))
      (Cat Eps (Star (Lit 'a')))
```

このうち2つは手計算していないもので，どちらも`Fail`になります．`Fail`の微分がどこにも行き着かないのは当然でしょう．しかし`Eps`の微分も`Fail`です．「空であること」を*要求していた*パターンは，文字が現れた瞬間に死にます．残りの文字列がどうであれ，うまくいく道はありません．

リストの締めは`Cat`についての2つのスペックで，最後の1つこそ`nullable`が存在する理由のすべてです．

```idris
  , shouldBe "a sequence derives its head first"
      (deriv 'a' (Cat (Lit 'a') (Lit 'b')))
      (Cat Eps (Lit 'b'))
  , shouldBe "a nullable head lets the character reach the tail too"
      (deriv 'b' (Cat (Star (Lit 'a')) (Lit 'b')))
      (Alt (Cat (Cat Fail (Star (Lit 'a'))) (Lit 'b')) Eps)
  ]
```

`a*b`に文字`'b'`を食べさせることを考えます．`b`を食べるのは誰でしょうか?必ずしも`a*`ではありません．`a*`は空文字列にマッチできるので，スターが*何も*出さずに，文字を後ろの`b`まで素通りさせるのは完全に合法です．先頭がnullableであるとは，文字に2通りの運命があり得るということです．先頭に消費されるか，あるいは（先頭が脇にどいて）後続に消費されるか．なので微分は`Alt`として，両方の扉を開けたままにしなければなりません．

ここで，その期待値をよく見てみてください．`Alt (Cat (Cat Fail (Star (Lit 'a'))) (Lit 'b')) Eps`です．左の枝は`Fail`で始まっています．到着した時点で死んでいる，純然たる構造上のガラクタです（スターが`'b'`を食べようとして失敗した痕跡です）．生きているのは，右側にぽつんとある`Eps`だけです．*意味*は正しいのに，*木*はガラクタだらけ，という状態です．この期待値は，ガラクタも含めて意図的にこう書いています．考えうる限り最も素朴な実装の，正直な出力だからです．この不格好な木は覚えておいてください．後の章の[スマートコンストラクタ](./10-smart-constructors.md)は，まさにこれを掃除するために存在します．

例の如く，まずはredです．

```
2/3: Building Spec.Core (src/Spec/Core.idr)
Error: While processing right hand side of derivSpecs. Undefined name deriv.

Spec.Core:76:8--76:13
 76 |       (deriv 'b' (Cat (Star (Lit 'a')) (Lit 'b')))
             ^^^^^
```

## green:11行

コミット[dd4e896](https://github.com/ubugeeei-prod/lets-start-functional/commit/dd4e89670a231de6ba16b53b1a15236fb46180ec)，`regex/src/Regex/Core.idr`にて．

```idris
||| The Brzozowski derivative: `deriv c r` is the regex matching
||| exactly the strings `s` such that `r` matches `c :: s`.
|||
||| In plain words: "if `r` had to consume the character `c` first,
||| what would be left of it?" Matching a whole string is then just
||| deriving once per character — no backtracking, ever. This is the
||| reason our engine runs in a single left-to-right pass.
|||
||| The two interesting cases:
|||
||| - `Cat l r`: the character must be consumed by `l` — unless `l`
|||   can match the empty string, in which case it may also skip `l`
|||   and be consumed by `r`. That is exactly where `nullable` earns
|||   its keep.
||| - `Star r`: a star that consumes a character has committed to at
|||   least one repetition: derive one `r`, then the star continues.
public export
deriv : Char -> Regex -> Regex
deriv _ Fail      = Fail
deriv _ Eps       = Fail
deriv c (Lit x)   = if c == x then Eps else Fail
deriv c (Cat l r) =
  if nullable l
    then Alt (Cat (deriv c l) r) (deriv c r)
    else Cat (deriv c l) r
deriv c (Alt l r) = Alt (deriv c l) (deriv c r)
deriv c (Star r)  = Cat (deriv c r) (Star r)
```

`nullable`と同じく，コンストラクタごとに1本の等式，下の下まで構造的再帰で，全域性チェッカーも文句なしに通してくれます．ケースの大半は，この章の前半で手計算した微分をそのまま書き写したものです．2つだけ，詳しく見ておきましょう．

**`Cat l r`:`nullable`が働く場所です．**基本の筋書きは単純で，先頭が文字を食べて，後続は待つ（`Cat (deriv c l) r`）だけです．しかし`l`がnullableなら，もうひとつ合法な筋書きがあります．`l`が空文字列にマッチして脇にどき，文字が`r`に届くパターンです．結果は，両方の筋書きを生かしたままにします．

```idris
Alt (Cat (deriv c l) r)   -- the head ate the character...
    (deriv c r)           -- ...or the head vanished and the tail ate it
```

これこそ，前の章が約束していた瞬間です．`nullable`なしには，連接の微分は定義できません（文字が後続まで届いてよいのかどうか，知りようがないからです）．アルゴリズムの半分は，この1行が存在できるようにするために作られたのでした．

**`Star r`:繰り返しを1回ぶん展開します．** `Cat (deriv c r) (Star r)`です．いま文字が始めた繰り返しを終わらせて，それからスターは手つかずの新品の状態で続きます．スターはその場でループしません．繰り返しを1回ぶん`Cat`に切り出して，先へ進みます．進捗はカウンタの中ではなく，返される木の中にあります．

ちなみに，`Alt`が*しない*ことにも注目してください．枝を選びません．両方の選択肢が足並みをそろえて微分され，死んだ枝は`Fail`に変わり，生きている枝は進み続けます．つまりパターンはすべての選択肢を，1文字ずつ*同時に*探索します．NFAに出会ったことがあるなら，既視感があるかもしれません．ただしここには機械も状態も帳簿もなく，あるのは木から木への関数だけです．

```sh
make test
```

```
  ok    true is true
  ...
  ok    a choice of two literals is not nullable
  ok    Fail stays Fail, whatever we feed it
  ok    Eps has nothing left to give after any character
  ok    consuming the right literal leaves the empty string
  ok    consuming the wrong literal fails
  ok    a choice derives both branches
  ok    a star unrolls one repetition and keeps going
  ok    a sequence derives its head first
  ok    a nullable head lets the character reach the tail too
27/27 passed
```

> [!NOTE]
> この構成はJanusz Brzozowskiによるものです（"Derivatives of Regular Expressions"，*Journal of the ACM*，1964年）．世界がオートマトンとバックトラッカーで正規表現エンジンを作り続ける間，この論文は何十年も半ば忘れられていました．やがて関数型プログラマたちが，「木から木への関数」こそ自分たちの言語が得意とするものだと気づいて再発見しました．*微分*という名前は，類推によって微積分から借りたものです（パターンを文字で微分する，`d r / d c`という感じです）．この類推は驚くほど深くまで通じるのですが，使うぶんには微積分の知識は一切不要です．

## 言語がいま何をしてくれたのか

一歩下がって，書いたものを眺めてみましょう．Brzozowskiの微分は，本書でいちばん難しいアルゴリズム上のアイデアです．エンジンの知性のすべてであり，バックトラックなしのマッチングを可能にするものです．それが**11行**に収まりました．しかもその中身は，パターンマッチ，コンストラクタごとの等式，構造的再帰，そして`if`と，手持ちの道具だけです．

アイデアが浅いからではなく，表現が正しいからです．正規表現が6種類の形からなる木である以上，「`c`を食べたあとに残るもの」は必然的に6通りの答えになり，それぞれの答えは部分木のちょっとした並べ替えにすぎません．素朴なパターンマッチと再帰（速習の頃から使ってきた2つの道具）だけで，本書の心臓部までたどり着いてしまいました．新しい機構は必要ありませんでしたし，この先の収穫にも必要ありません．

## まとめ

- 微分が尋ねるのは「このパターンが最初に文字`c`を食べなければならないとしたら，何が残るか?」です．木を木へ写す関数です．
- 手で微分できる事実が，そのままスペックになりました．`a`の`'a'`による微分は ε，`a`の`'b'`によるものは ∅，`ab`の`'a'`によるものは`b`，`a|b`の`'a'`によるものは ε|∅，そして`a*`の`'a'`によるものは繰り返しを1回展開した ε·`a*`です．
- 微妙なのは`Cat`です．nullableな先頭は脇にどいて，文字を後続まで通すことがあります．`nullable`を先に作る必要があったのは，このためです．
- `Star`は決してループしません．繰り返しを1回ぶん`Cat`に切り出して続行します．マッチの進捗は，返される木の中にあります．
- 生の微分は，構造的にガラクタだらけの木（`Cat Fail ...`や宙ぶらりんの`Alt`の枝）を生みます．わざとスペックにひとつ固定しておきました．[スマートコンストラクタ](./10-smart-constructors.md)が掃除してくれます．
- アイデアはBrzozowskiのもの（JACM，1964年）です．実装は，パターンマッチと構造的再帰による11行です．スイートは27/27です！

これでパターンに1文字を食べさせられるようになりました！文字列とは，文字が並んだものにすぎません．というわけで[次の章](./09-matches.md)では，`deriv`を入力全体に畳み込んで，最後に`nullable`に尋ねます．それでエンジンは完成です．
