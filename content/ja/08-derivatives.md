---
title: 微分
description: Brzozowski の美しいアイデア——パターンに 1 文字を食べさせると、文字列の残りのためのパターンが返ってくる。
---

# 微分

パターンに、空文字列にマッチするかどうかを尋ねられるようになりました([nullable](./07-nullable.md))。この章ではアルゴリズムのもう半分を加えます——そしてそれは、本書でいちばん美しいアイデアです。これより後の内容はすべて、このアイデアの肉付けにすぎません。

## パターンに投げかける、ひとつの問い

いったんコードのことは忘れてください。アイデアを一文で言うとこうなります。

> このパターンが最初に文字 `c` を食べなければならないとしたら、あとにはどんなパターンが残るだろうか?

これで全部です。パターンに*文字列*を食べさせるのではありません。パターンに*1 文字*を食べさせて、新しいパターンを受け取るのです——「この先に続くもの」がマッチすべきパターンを。この「残りのためのパターン」を、`c` に関するパターンの**微分(derivative)**と呼びます。

この章の記法を決めておきましょう。ε は空文字列のパターン(`Eps`)、∅ は何にもマッチしないパターン(`Fail`)、そして「`r` の `c` による微分」という言い方をします。Idris を書く前に、小さな例をいくつか手で微分してみます。

**パターン `a` に `'a'` を食べさせる。** パターンはちょうど 1 つの `a` を欲しがっていて、いままさにそれを受け取りました。マッチすべき残りは?何もありません——入力の残りは空でなければなりません。微分は ε です。

**パターン `a` に `'b'` を食べさせる。** `a` が欲しかったのに、来たのは `b` でした。これは「もう少し粘ろう」という状況ではありません。マッチは死んでいて、この先どんな入力が続いても生き返りません。微分は ∅ です。[AST の章](./06-regex-as-data.md)の 2 つの「無」が、ここでそろって給料分の働きを見せたことに注目してください。ε は「残りなし」という*成功*であり、∅ は「先へ進む道なし」という*失敗*です。

**パターン `ab` に `'a'` を食べさせる。** 先頭の `a` が文字を消費し、残るのはその後ろのすべて。微分は `b` です。連接は先頭を微分するのです。

**パターン `a|b` に `'a'` を食べさせる。** 選択は選びません——*両方の*枝を微分して、選択のまま残ります。左の枝 `a` は ε になり、右の枝 `b` は ∅ になります。微分は ε|∅ です。文字列の集合としてはただの ε です——死んだ枝は何も寄与しませんから。しかし*木*としては、∅ がくっついてきます。このことは覚えておいてください。この章の後半で重要になります。

**パターン `a*` に `'a'` を食べさせる。** ここはゆっくり行きましょう。スターは、このアイデアが牙をむく場所です。`a*` は 0 個以上の `a` を意味します。文字を 1 つ消費したのなら、「0 回の繰り返し」という選択肢は消えました——スターは*少なくとも 1 回の繰り返しにコミットした*のです。その最初の繰り返しは `a` で、いま文字を食べたばかりですから、この繰り返しに残るのは ε。そして、どの繰り返しのあとでも、スターは続きを許されているのでした。したがって残るのは、「いまの繰り返しを終わらせて(ε)、それから再び `a*`」。微分は ε`a*` です——これは `a*` とまったく同じものにマッチします。それこそが正解です。`a` を 1 つ食べたあとに `a*` がなお受理する文字列は……さらに任意個の `a`、なのですから。

繰り返しが 1 回ぶん展開され、スターはまだ走り続けている。カウンタもループも状態機械もありません——マッチの進捗は、パターンそのものが運んでいるのです。

## red:微分を釘付けにする

コミット [c426464](https://github.com/ubugeeei-prod/lets-start-functional/commit/c42646445a905e9474eb980c07cc0f60fae5d951) より、`regex/tests/src/Spec/Core.idr` にて——先ほどの手計算のひとつひとつが、そのままスペックになります。まずは葉から。

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

このうち 2 つは手計算していないもので、どちらも `Fail` になります。`Fail` の微分がどこにも行き着かないのは当然でしょう。しかし `Eps` の微分も `Fail` です。「空であること」を*要求していた*パターンは、文字が現れた瞬間に死にます——残りの文字列がどうであれ、うまくいく道はないのです。

リストの締めは `Cat` についての 2 つのスペックで、最後の 1 つこそ `nullable` が存在する理由のすべてです。

```idris
  , shouldBe "a sequence derives its head first"
      (deriv 'a' (Cat (Lit 'a') (Lit 'b')))
      (Cat Eps (Lit 'b'))
  , shouldBe "a nullable head lets the character reach the tail too"
      (deriv 'b' (Cat (Star (Lit 'a')) (Lit 'b')))
      (Alt (Cat (Cat Fail (Star (Lit 'a'))) (Lit 'b')) Eps)
  ]
```

`a*b` に文字 `'b'` を食べさせることを考えます。`b` を食べるのは誰でしょう?必ずしも `a*` ではありません——`a*` は空文字列にマッチできるので、スターが*何も*出さずに、文字を後ろの `b` まで素通りさせるのは完全に合法です。先頭が nullable であるとは、文字に 2 通りの運命があり得るということです。先頭に消費されるか、あるいは——先頭が脇にどいて——後続に消費されるか。微分は `Alt` として、両方の扉を開けたままにしなければなりません。

ここで、その期待値に目を凝らしてください。`Alt (Cat (Cat Fail (Star (Lit 'a'))) (Lit 'b')) Eps`。左の枝は `Fail` で始まっています——到着した時点で死んでいる、純然たる構造上のガラクタです(スターが `'b'` を食べようとして失敗した痕跡です)。生きているのは、右側にぽつんとある `Eps` だけ。*意味*は正しいのに、*木*は瓦礫だらけです。この期待値は、ガラクタも含めて意図的にこう書いています。これが、考えうる限り最も素朴な実装の正直な出力だからです。この不格好な木を覚えておいてください——後の章、[スマートコンストラクタ](./10-smart-constructors.md)は、まさにこれを掃除するために存在します。

いつもどおり、まずは red です。

```
2/3: Building Spec.Core (src/Spec/Core.idr)
Error: While processing right hand side of derivSpecs. Undefined name deriv.

Spec.Core:76:8--76:13
 76 |       (deriv 'b' (Cat (Star (Lit 'a')) (Lit 'b')))
             ^^^^^
```

## green:11 行

コミット [dd4e896](https://github.com/ubugeeei-prod/lets-start-functional/commit/dd4e89670a231de6ba16b53b1a15236fb46180ec)、`regex/src/Regex/Core.idr` にて。

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

`nullable` と同じく、コンストラクタごとに 1 本の等式、下の下まで構造的再帰で、全域性チェッカーは一言の文句もなく承認してくれます。ケースの大半は、この章の前半で手計算した微分をそのまま書き写したものです。2 つだけ、詳しく見る価値があります。

**`Cat l r`——`nullable` が給料分の働きをする場所。** 基本の筋書きは単純です。先頭が文字を食べ、後続は待つ——`Cat (deriv c l) r`。しかし `l` が nullable なら、もうひとつ合法な筋書きがあります。`l` が空文字列にマッチして脇にどき、文字が `r` に届くのです。結果は、両方の筋書きを生かしたままにします。

```idris
Alt (Cat (deriv c l) r)   -- the head ate the character...
    (deriv c r)           -- ...or the head vanished and the tail ate it
```

これこそ、前の章が約束していた瞬間です。`nullable` なしには、連接の微分は定義できません——文字が後続まで届いてよいのかどうか、知りようがないからです。アルゴリズムの半分は、この 1 行が存在できるようにするために作られたのでした。

**`Star r`——繰り返しを 1 回ぶん展開する。** `Cat (deriv c r) (Star r)`。いま文字が始めた繰り返しを終わらせて、それからスターは続きます。手つかずの、新品の状態で。スターはその場でループしません。繰り返しを 1 回ぶん `Cat` に脱ぎ捨てて、先へ進むのです。進捗はカウンタの中ではなく、返される木の中に住んでいます。

`Alt` が*しない*ことにも注目してください。枝を選ばないのです。両方の選択肢が足並みをそろえて微分され、死んだ枝は `Fail` に変わり、生きている枝は行進を続けます。パターンはすべての選択肢を、1 文字ずつ、*同時に*探索するのです。NFA に出会ったことがあるなら、既視感を覚えるかもしれません——しかしここには機械も状態も帳簿もありません。あるのは、木から木への関数だけです。

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
> この構成は Janusz Brzozowski によるものです——"Derivatives of Regular Expressions"、*Journal of the ACM*、1964 年。世界がオートマトンとバックトラッカーで正規表現エンジンを作り続ける間、この論文は何十年も半ば忘れられていました。やがて関数型プログラマたちが再発見します。「木から木への関数」こそ、自分たちの言語が得意とするものそのものだ、と気づいたのです。*微分*という名前は、類推によって微積分から借りたもので——パターンを文字で微分する、`d r / d c`——この類推は驚くほど深くまで通じるのですが、使うぶんには微積分の知識は一切要りません。

## 言語がいま何をしてくれたのか

一歩下がって、書いたものを眺めてみましょう。Brzozowski の微分は、本書でいちばん難しいアルゴリズム上のアイデアです——エンジンの知性のすべてであり、バックトラックなしのマッチングを可能にするものです。それが **11 行**に収まりました。しかもその中身に、手持ちになかったものは何ひとつありません。パターンマッチ、コンストラクタごとの等式、構造的再帰、そして `if`。それだけです。

アイデアが浅いからではありません。表現が正しいからです。正規表現が 6 種類の形からなる木である以上、「`c` を食べたあとに残るもの」は必然的に 6 通りの答えになり、それぞれの答えは部分木のちょっとした並べ替えにすぎません。素朴なパターンマッチと再帰——速習の頃から使ってきた 2 つの道具——だけで、本書の心臓部までたどり着いてしまいました。新しい機構は要りませんでしたし、この先の収穫にも要りません。

## まとめ

- 微分が尋ねるのは「このパターンが最初に文字 `c` を食べなければならないとしたら、何が残るか?」。木を木へ写す関数です。
- 手で微分できる事実が、そのままスペックになりました。`a` の `'a'` による微分は ε、`a` の `'b'` によるものは ∅、`ab` の `'a'` によるものは `b`、`a|b` の `'a'` によるものは ε|∅、そして `a*` の `'a'` によるものは繰り返しを 1 回展開した ε·`a*` です。
- 微妙なのは `Cat` です。nullable な先頭は脇にどいて、文字を後続まで通すことがあります——`nullable` を先に作る必要があったのは、このためです。
- `Star` は決してループしません。繰り返しを 1 回ぶん `Cat` に脱ぎ捨てて続行します。マッチの進捗は、返される木の中にあります。
- 生の微分は、構造的にガラクタだらけの木(`Cat Fail ...` や宙ぶらりんの `Alt` の枝)を生みます。わざとスペックにひとつ釘付けにしておきました。[スマートコンストラクタ](./10-smart-constructors.md)が掃除してくれます。
- アイデアは Brzozowski のもの(JACM、1964 年)。実装は、パターンマッチと構造的再帰による 11 行です。スイートは 27/27。

これでパターンに 1 文字を食べさせられるようになりました。文字列とは、文字が並んだものにすぎません——というわけで[次の章](./09-matches.md)では、`deriv` を入力全体に畳み込み、最後に `nullable` に尋ねます。それでエンジンは完成です。
