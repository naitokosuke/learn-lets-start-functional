---
title: パターンを印字し直す
description: toPatternはASTをパターン構文へ描き戻します．文脈で変わるエスケープ，Natひとつで表す優先順位，そしてパーサの方を変えることになったラウンドトリップのプロパティの話です．
---

# パターンを印字し直す

パーサはパターン文字列を木に変えます．この章ではその逆，つまり木をパターン文字列へ戻す`toPattern : Regex -> String`を作ります．ついでに，両方の関数を同時に締め上げるプロパティテストも書いてみましょう．

## なぜ正規表現を印字するのか

理由は3つあります．嬉しさの昇順でどうぞ．

第一に，デバッグです．`Show Regex`は忠実ですがやかましく，`show (cat (lit 'a') (lit 'b'))`は`Cat (Sym (MkSet False [('a', 'a')])) (Sym (MkSet False [('b', 'b')]))`を出力します．これを読みやすいと思う人はいません．`"ab"`なら読めます．

第二に，エラーメッセージです．正規表現を操作するツール(簡約したり，組み合わせたり，微分したり)は，ユーザーが実際に書く構文で仕事の中身を見せたいものです．

第三に，これが美味しいところなのですが，パーサの本物の逆関数になっているプリンタは，プロパティテストをくれます．木を取り，印字し，パースし直すと，同じ木が戻ってこなければなりません．スペック1行で，両方の関数の隅々を互いに突き合わせて検査できるわけです．

難しい問題は**優先順位(precedence)**です．木`Cat (Alt a b) c`は`(a|b)c`と印字されなければなりません．素朴に`a|bc`と印字したら，それは別の木を記述したことになってしまいます．括弧は，子が周囲より緩く結合するちょうどその場所に現れる必要があります．多すぎればノイズですし，少なすぎれば誤りです．

## Red:プリンタを仕様にする

コミット[114a177](https://github.com/ubugeeei-prod/lets-start-functional/commit/114a1772565ccf9bdabe3c24099150ed6052f252)が[`regex/tests/src/Spec/Pretty.idr`](https://github.com/ubugeeei-prod/lets-start-functional/blob/main/regex/tests/src/Spec/Pretty.idr)を追加します．ラウンドトリップ(roundtrip)のプロパティはヘルパー関数です．

```idris
||| Compile, print, re-compile: the same tree should come back.
roundtrips : String -> Bool
roundtrips p =
  case compile p of
    Right r => compile (toPattern r) == Right r
    Left _  => False
```

続いてスペックです．エスケープ，優先順位，文字集合，それからプロパティという並びになっています．

```idris
export
prettySpecs : List Spec
prettySpecs =
  [ shouldBe "a literal prints as itself"
      (toPattern (lit 'a')) "a"
  , shouldBe "metacharacters come back escaped"
      (toPattern (lit '.')) "\\."
  , shouldBe "control characters come back by name"
      (toPattern (lit '\n')) "\\n"
  , shouldBe "star binds directly to an atom"
      (toPattern (Star (lit 'a'))) "a*"
  , shouldBe "star parenthesizes a compound"
      (toPattern (Star (Cat (lit 'a') (lit 'b')))) "(ab)*"
  , shouldBe "alternation parenthesizes under concatenation"
      (toPattern (Cat (lit 'a') (Alt (lit 'b') (lit 'c')))) "a(b|c)"
  , shouldBe "shorthand sets print as their escapes"
      (toPattern (Sym digit)) "\\d"
  , shouldBe "negated shorthands too"
      (toPattern (Sym (complement word))) "\\W"
  , shouldBe "the any-character set prints as the wildcard"
      (toPattern (Sym anyChar)) "."
  , shouldBe "classes print their ranges"
      (toPattern (Sym (MkSet False [('a', 'z'), ('0', '9')]))) "[a-z0-9]"
  , shouldBe "negated classes get their caret"
      (toPattern (Sym (complement (range 'a' 'z')))) "[^a-z]"
  , it "compiled patterns survive print-and-reparse"
      (all roundtrips
        ["gr[ae]y", "(a|b)*c", "colou?r", "a.c", "[^x]+", "\\d{2,4}"])
```

(リストはこの先，[前章](./16-interfaces.md)のモノイドのスペックへと続きます．ひとつのコミットにふたつの章，というわけです．)スイートはコンパイル時にredです．

```
Error: Module Regex.Pretty not found
```

## Green:エスケープは立ち位置しだい

コミット[bd405ed](https://github.com/ubugeeei-prod/lets-start-functional/commit/bd405eda8e87a78a1716c306df0286a221d3ccd2)が[`regex/src/Regex/Pretty.idr`](https://github.com/ubugeeei-prod/lets-start-functional/blob/main/regex/src/Regex/Pretty.idr)を追加します．冒頭から，プリンタを書いてみるまでほとんどの人が気づかない機微が顔を出します．どの文字をエスケープすべきかは，いま自分がどこに立っているかで変わるのです．

```idris
||| Escape one character for use outside a class.
escapeOutside : Char -> String
escapeOutside '\n' = "\\n"
escapeOutside '\t' = "\\t"
escapeOutside '\r' = "\\r"
escapeOutside c    = if isMeta c then "\\" ++ pack [c] else pack [c]

||| Escape one character for use inside a class.
escapeInside : Char -> String
escapeInside '\n' = "\\n"
escapeInside '\t' = "\\t"
escapeInside '\r' = "\\r"
escapeInside c    =
  if elem c (unpack "]\\-^") then "\\" ++ pack [c] else pack [c]
```

クラスの外では`(`や`*`や`|`とその仲間たちが特別です．`[...]`の中ではそれらはただの文字になり，代わりに`]`，`-`，`^`が急に意味を持ち始めます．述語`isMeta`はパーサにすでに存在していたので，このコミットはそれを`public export`にしただけです．何が特別かについてプリンタとパーサが食い違えないように，定義はひとつ，消費者はふたつ，という形にしています．

## Green:集合は短い綴りを好む

`CharSet`はいつでも`[...]`構文で印字できますが，`\d`と書いたのに`[0-9]`を読まされたい人はいません．なので，レンダラはまず短い綴りから試します．

```idris
||| One class item: `a` or `a-z`.
rangeItem : (Char, Char) -> String
rangeItem (lo, hi) =
  if lo == hi
    then escapeInside lo
    else escapeInside lo ++ "-" ++ escapeInside hi

||| Render a character set, preferring the short spellings:
||| shorthands like `\d` and the wildcard `.` where they apply,
||| class syntax otherwise.
renderSet : CharSet -> String
renderSet s =
  if      s == anyChar          then "."
  else if s == digit            then "\\d"
  else if s == complement digit then "\\D"
  else if s == word             then "\\w"
  else if s == complement word  then "\\W"
  else if s == space            then "\\s"
  else if s == complement space then "\\S"
  else case s of
    MkSet False [(lo, hi)] =>
      if lo == hi
        then escapeOutside lo
        else "[" ++ rangeItem (lo, hi) ++ "]"
    MkSet neg rs =>
      "[" ++ (if neg then "^" else "")
          ++ concat (map rangeItem rs) ++ "]"
```

この等値テストの連鎖が機能するのは，`CharSet`が構造的な`Eq`を持つ素朴なデータだからです(そして，パーサがこれらの集合をそれぞれ厳密にひとつの形でしか作らないからでもあります)．パターン中の`\d`は`range '0' '9'`になるので，`range '0' '9'`は`\d`として印字し戻されます．正規形のデータは，`==`で見分けられるデータというわけです．

## Green:優先順位はNatひとつ

さて，本番です．入れ子構文のレンダラはみな括弧の問題に直面しますが，定番の答えは美しく小さいです．周囲がどれほど強く結合しているかを表す数をひとつ下へ渡し，いまのノードがそれより緩く結合するとき，ちょうどそのときだけ括弧で包みます．

```idris
wrap : Bool -> String -> String
wrap True  body = "(" ++ body ++ ")"
wrap False body = body

||| Render at a given surrounding precedence.
render : (prec : Nat) -> Regex -> String
render _ Fail      = "∅"   -- Fail has no pattern syntax; see the book
render _ Eps       = ""
render _ (Sym s)   = renderSet s
render p (Cat l r) = wrap (p > 1) (render 2 l ++ render 1 r)
render p (Alt l r) = wrap (p > 0) (render 1 l ++ "|" ++ render 0 r)
render p (Star r)  = wrap (p > 2) (render 3 r ++ "*")

||| Render a regex as pattern syntax.
public export
toPattern : Regex -> String
toPattern = render 0
```

レベルは，0 = 選択，1 = 連接，2 = 後置，3 = アトムです．`Alt`はレベル0のものを作るので，文脈がそれより強い結合を要求するとき(`p > 0`)はいつでも包みます．これが`a(b|c)`のスペックです．`Star`はレベル2のものを作り，子にはレベル3のアトムを求めるので，`Star (Cat ...)`は本体を包んで`(ab)*`になります．

## 非対称性と，それが強いた対話

`Cat`の行をよく見てみてください．対称ではありません．

```idris
render p (Cat l r) = wrap (p > 1) (render 2 l ++ render 1 r)
```

左の子はレベル2で，右の子はレベル1でレンダリングされます．なぜでしょう?この木では`Cat`が*右結合*だからです．パーサは`abc`を`Cat a (Cat b c)`に畳み込みます．右の子がそれ自身`Cat`であることは形からの逸脱ではなく，むしろそれこそが形なので，連接レベルで括弧なしにレンダリングして問題ないです．一方，`Cat`である*左*の子はパーサが決して作らない形なので，レベル2でのレンダリングがきっちり柵で囲います．同じ非対称性は，1段下の`Alt`の行にも現れます．つまりレンダラは，文法の優先順位だけでなくパーサの*結合性*まで知っているわけです．

そして，その知識があるものを捕まえました．ラウンドトリップのスペックを通そうとするなかで，どうしても揃わない形がひとつあったのです．連接は右へ畳まれる([パターン構文をパースする](./14-pattern-syntax.md)の`foldr cat Eps`です)のに，選択は*左*へ畳まれていました．誰も気づいていませんでした．マッチングは`a|b|c`がどちらに傾いていても気にしないからです．しかしプリンタは痛烈に気にします．なので，greenのコミットは[`regex/src/Regex/Syntax.idr`](https://github.com/ubugeeei-prod/lets-start-functional/blob/main/regex/src/Regex/Syntax.idr)のパーサの方を変更しました．

```idris
  ||| Lowest precedence: sequences separated by `|`.
  ||| Folded to the right, like concatenation — a consistent shape
  ||| keeps the pretty-printer's roundtrip exact. (`alt x Fail` is
  ||| `x`, so the trailing `Fail` seed leaves no junk behind.)
  alternation : Parser Regex
  alternation = do
    first <- sequenceOf
    rest  <- many (char '|' *> sequenceOf)
    pure (foldr alt Fail (first :: rest))
```

最後の行は，以前は`pure (foldl alt first rest)`でした．互いに逆関数だと主張するふたつの関数は，意味だけでなく木の形についても合意しなければなりません．そしてその対話を強いたのは，両者を正面からぶつけて走らせるテストでした．これがプロパティスペックの静かな見返りです．プリンタを検査するだけでなく，パーサがこれまでに下した構造上の決定のすべてを監査してくれます．

> [!WARNING]
> ひとつ正直な注意です．`Fail`は`∅`として印字されますが，`∅`はパースし直せません．「何にもマッチしない」を表すパターン構文は存在しないのです(スターの直下のスターのような形にも，ありません)．なので，ラウンドトリップのプロパティは*コンパイルされた*パターンについて述べられています．`compile`は`Fail`も，その他の構文を持たない形も決して作りません．だからこそ`compile (toPattern r) == Right r`が，`compile`から生まれたすべての木について例外なく成り立つわけです．手組みの木に与えられるのは，ベストエフォートのレンダリングまでです．

```sh
make test
```

```
  ...
  ok    a literal prints as itself
  ok    metacharacters come back escaped
  ok    control characters come back by name
  ok    star binds directly to an atom
  ok    star parenthesizes a compound
  ok    alternation parenthesizes under concatenation
  ok    shorthand sets print as their escapes
  ...
  ok    compiled patterns survive print-and-reparse
  ...
148/148 passed
```

## 言語がいま何をしてくれたか

この章では，新しい仕掛けは何ひとつ要りませんでした．そこが噛みしめどころです．プリンタは他のすべてと同じ6つのコンストラクタの上の畳み込みですし，優先順位はふつうの`Nat`の引数，ラウンドトリップのプロパティは`Bool`を返すただの関数です．正規表現がデータであれば，「印字し直す」はもうひとつの木歩きにすぎず，「プリンタはパーサの逆」はテストが言えるもうひとつの文にすぎない，という感じです．

## まとめ

- `toPattern : Regex -> String`はASTをパターン構文へ描き戻します．デバッグのため，エラーメッセージのため，そしてラウンドトリップのプロパティ`compile (toPattern r) == Right r`のためです．
- エスケープは文脈依存です．`escapeOutside`と`escapeInside`は，どの文字が特別かで意見が分かれますが，どちらもパーサ自身の`isMeta`に従います．
- `renderSet`は構造的な等値性で短い綴り(`\d`，`.`)を優先します．正規形のデータは見分けられるデータです．
- 優先順位は，`render`に通す`Nat`ひとつです．`wrap`は，ノードが文脈より緩く結合するちょうどそのときに括弧を差し込みます．
- `Cat`の子がそれぞれ違うレベルでレンダリングされるのは，木が右結合だからです．そしてラウンドトリップを正確にするために，パーサの選択は`foldl`から`foldr`へ切り替わりました．逆関数どうしは形について合意しなければならず，それを実現させたのはプロパティテストでした．
- `Fail`は`∅`と印字され，これには構文がありません．ラウンドトリップは自分の適用範囲に正直で，対象はコンパイルされたパターンだけです．

これまでのスペックは(今日のプロパティも含めて)思いついて書き出した例を検査するものでした．[テストが定理になる](./18-proofs.md)では，すべての入力を一度に検査します．しかもテストランナーは型チェッカです．
