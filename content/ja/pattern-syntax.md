---
title: パターン構文をパースする
description: 優先順位のレベルごとにパーサをひとつ。(colou?r|gr[ae]y) のような本物の正規表現記法を、エンジンがすでに理解している木へと変えます。
---

# パターン構文をパースする

コンビネータは作業台の上に揃いました。いよいよ、そのために手に入れたものを作るときです。この章を終えるころには、`(colou?r|gr[ae]y)` はユーザーが手渡してくれる文字列であり、私たちのエンジンが走らせられる木になっています。

## 文法

正規表現の記法には、算術と同じように優先順位があります。`ab|c` では並置(juxtaposition)が縦棒より強く結合します — 意味は `(ab)|c` であって `a(b|c)` ではありません。`ab*` ではスターがさらに強く結合します: `a(b*)`。結合のゆるい順に文法として書き下すと、こうなります — これは `regex/src/Regex/Syntax.idr` のモジュール doc コメントです:

```
alternation := sequence ('|' sequence)*
sequence    := repetition*
repetition  := atom ('*' | '+' | '?' | '{' count '}')*
atom        := '(' alternation ')' | '[' class ']'
             | '.' | '\' escape | plain character
```

この文法をコードに変える対応規則は、見事なまでに機械的です。**優先順位のレベルひとつにつきパーサひとつ**。各レベルのパーサは、ひとつ強く結合するレベルへの呼び出しから組み立てます。`alternation` が `sequenceOf` を呼び、それが `repetition` を呼び、それが `atom` を呼ぶ — そして底にいる `atom` は、括弧のグループのために `alternation` へと舞い戻ります。このループこそ文法を再帰的にしているものであり、章が終わる前に、遅延評価と正格評価について本物の学びをひとつ授けてくれることになります。

## Red: 3 つの味のスペック

`regex/tests/src/Spec/Syntax.idr` は 2 つのヘルパで始まります。「このパターンをコンパイルして、この入力にマッチさせる」を、これから 20 回言うことになるからです:

```idris
||| Does the pattern compile and match the input?
ok : String -> String -> Bool
ok pat input =
  case compile pat of
    Just r  => matches r input
    Nothing => False

||| Does the pattern compile and reject the input?
no : String -> String -> Bool
no pat input =
  case compile pat of
    Just r  => not (matches r input)
    Nothing => False
```

`no` が `not . ok` ではないことに注意してください — *コンパイルに失敗する*パターンは、どちらにも数えられるべきではありません。1 つ目の味のスペックは**構造**を確かめます。パーサは、優先順位も含めて、私たちの期待どおりの木を寸分違わず生み出さなければなりません:

```idris
export
syntaxSpecs : List Spec
syntaxSpecs =
  [ -- structure: the parser produces exactly the trees we expect
    shouldBe "the empty pattern is Eps"
      (compile "") (Just Eps)
  , shouldBe "a single character is a literal"
      (compile "a") (Just (lit 'a'))
  , shouldBe "juxtaposition is concatenation"
      (compile "ab") (Just (Cat (lit 'a') (lit 'b')))
  , shouldBe "the bar is alternation"
      (compile "a|b") (Just (Alt (lit 'a') (lit 'b')))
  , shouldBe "concatenation binds tighter than the bar"
      (compile "ab|c") (Just (Alt (Cat (lit 'a') (lit 'b')) (lit 'c')))
  , shouldBe "postfix operators bind tightest of all"
      (compile "ab*") (Just (Cat (lit 'a') (Star (lit 'b'))))
  , shouldBe "parentheses regroup"
      (compile "a(b|c)") (Just (Cat (lit 'a') (Alt (lit 'b') (lit 'c'))))
  , shouldBe "the wildcard is the any-character set"
      (compile ".") (Just (Sym anyChar))
```

5 番目と 6 番目のスペックは、実行できる優先順位表*そのもの*です。レベルの配線をいつか間違えれば、この 2 つが red になります。

2 つ目の味は、**不正な入力が拒否される**ことの確認です — 末尾のゴミは警告ではなく失敗です:

```idris
    -- malformed patterns are rejected, not guessed at
  , shouldBe "an unbalanced group does not compile"
      (compile "a)") Nothing
  , shouldBe "an unterminated class does not compile"
      (compile "[abc") Nothing
  , shouldBe "an unterminated count does not compile"
      (compile "a{2") Nothing
```

そして 3 つ目の味は**振る舞い**です — 定番たち、それに直近 3 章で作ったすべてが、いまやタイプするだけで手の届くところにあります:

```idris
    -- behavior: the classics
  , it "colou?r matches both spellings"
      (ok "colou?r" "color" && ok "colou?r" "colour")
  , it "gr[ae]y matches both spellings, nothing else"
      (ok "gr[ae]y" "gray" && ok "gr[ae]y" "grey" && no "gr[ae]y" "groy")
  , it "classes can be negated: [^0-9]+"
      (ok "[^0-9]+" "hello" && no "[^0-9]+" "hell0")
  , it "escaped metacharacters are plain characters"
      (ok "\\(\\)" "()" && ok "3\\.14" "3.14" && no "3\\.14" "3014")
  , it "\\d, \\w and \\s shorthands work"
      (ok "\\d+" "2026" && ok "\\w+" "snake_case" && ok "a\\sb" "a b")
  , it "negated shorthands too: \\D rejects digits"
      (ok "\\D+" "abc" && no "\\D+" "ab1")
  , it "counted repetition: a{3} and a{2,4} and a{2,}"
      (ok "a{3}" "aaa" && no "a{3}" "aa"
        && ok "a{2,4}" "aaaa" && no "a{2,4}" "aaaaa"
        && ok "a{2,}" "aaaaaa" && no "a{2,}" "a")
  , it "a real-world shape: \\w+@\\w+\\.\\w+"
      (ok "\\w+@\\w+\\.\\w+" "user@example.com"
        && no "\\w+@\\w+\\.\\w+" "not an email")
  , it "a date pattern, this time written as a pattern"
      (ok "\\d{4}-\\d{2}-\\d{2}" "2026-07-14"
        && no "\\d{4}-\\d{2}-\\d{2}" "2026-7-14")
  ]
```

(同じ形の振る舞いスペックがあと 3 つ — 範囲 `[a-c]+`、ワイルドカードの「ちょうど 1 文字」規則、そしてひとかたまりで繰り返す `(ha)+` — がコミットに入っています。全部で 23 スペックです。)[糖衣構文の章](./sugar.md) では入れ子の関数呼び出しの `where` ブロックを丸々必要とした日付パターンが、いまや 17 文字です。

```sh
make test
```

```
Error: Module Regex.Syntax not found

Spec.Syntax:11:1--11:20
 ...
 11 | import Regex.Syntax
      ^^^^^^^^^^^^^^^^^^^
```

23 スペックが一斉に red — これまでのどの red ステップよりも多い数です。これはコミット [302ad49](https://github.com/ubugeeei-prod/lets-start-functional/commit/302ad496f1e0f0ca423c9f9853ad38ac7e058756) です。

## Green: パターンパーサ

`Regex/Syntax.idr` は手持ちのすべてを import し、冒頭でひとつ白状し、そして「自分自身を意味できない文字たち」に名前を付けます:

```idris
-- A recursive grammar needs recursive parsers, and those (like
-- many/some) are honest `covering` functions rather than `total`.
%default covering

||| Characters that mean something special outside a class.
isMeta : Char -> Bool
isMeta c = elem c (unpack "()[]{}|*+?.\\")
```

### エスケープ

バックスラッシュのエスケープは、2 つの役どころで登場します。クラスの中では、`\n` は*文字*をくれるべきです。トップレベルでは、`\d` は丸ごとひとつの*正規表現のアトム*をくれるべきです。小さなパーサを 2 つ:

```idris
||| A backslash escape interpreted as a single character:
||| `\n`, `\t`, `\r`, or any escaped literal like `\.` or `\\`.
escapedChar : Parser Char
escapedChar = char '\\' *> map interp anyToken
  where
    interp : Char -> Char
    interp 'n' = '\n'
    interp 't' = '\t'
    interp 'r' = '\r'
    interp c   = c

||| A backslash escape interpreted as a regex atom. The shorthand
||| classes expand to the sets from `Regex.Set`; anything else is
||| the escaped character itself.
escapedAtom : Parser Regex
escapedAtom = char '\\' *> map interp anyToken
  where
    interp : Char -> Regex
    interp 'd' = Sym digit
    interp 'D' = Sym (complement digit)
    interp 'w' = Sym word
    interp 'W' = Sym (complement word)
    interp 's' = Sym space
    interp 'S' = Sym (complement space)
    interp 'n' = lit '\n'
    interp 't' = lit '\t'
    interp 'r' = lit '\r'
    interp c   = lit c
```

`'D'` の行を味わってください。[文字クラス](./character-classes.md) の章で、`complement` をフィールドひとつの反転にしておきました — その配当がこれです。たいていの正規表現エンジンでは一人前の機能である否定の略記 `\D` が、私たちには `complement` の呼び出しきっかり 1 回で済みます。良い表現は、それを選んだことを忘れたあとも配当を払い続けてくれるのです。

### クラス

クラスの構文 — `[a-c]`、`[^0-9]`、`[\d_-]` — はそれ自体がミニチュア言語なので、専用のパーサ群をあてがいます。クラスの*項目*ひとつひとつが範囲のリストを持ち寄り、クラス全体がそれらを連結します:

```idris
||| Inside a class, `\d` `\w` `\s` contribute their ranges.
shorthandRanges : Parser (List (Char, Char))
shorthandRanges =
  char '\\' *>
    (   (char 'd' *> pure (ranges digit))
    <|> (char 'w' *> pure (ranges word))
    <|> (char 's' *> pure (ranges space)))

||| A literal character inside a class: anything but `]`, `\` or
||| `-` — those need escaping.
classChar : Parser Char
classChar = escapedChar <|> satisfy (\c => not (elem c (unpack "]\\-")))

||| One item of a class: a shorthand, a range `a-z`, or a single
||| character. Every item contributes a list of ranges.
classItem : Parser (List (Char, Char))
classItem = shorthandRanges <|> rangeOrSingle
  where
    rangeOrSingle : Parser (List (Char, Char))
    rangeOrSingle = do
      lo <- classChar
      (do _  <- char '-'
          hi <- classChar
          pure [(lo, hi)])
        <|> pure [(lo, lo)]

||| A whole class: `[...]` or negated `[^...]`.
classAtom : Parser Regex
classAtom = do
  _     <- char '['
  neg   <- (char '^' *> pure True) <|> pure False
  items <- some classItem
  _     <- char ']'
  pure (Sym (MkSet neg (concat items)))
```

`rangeOrSingle` は Monad と Alternative の共同作業です。文字をひとつパースし、続けて `-hi` を*試みる*。だめなら、その文字は単独で立っていたということです。(`shorthandRanges` の `ranges digit` は、レコードのフィールドアクセスを関数として使っているだけ — `digit` の中にある範囲リストのことです。)そして `classAtom` は、最後に `MkSet` を直接組み立てるところまで、それ自身の文法規則のように読めます — 開き括弧、あってもなくてもいいキャレット、項目たち、閉じ括弧。パーサと、2 章前に作った表現とが、間にアダプタを挟むことなくカチッと噛み合うのです。

### 後置演算子は関数

この章でいちばん気の利いたアイデアがこれです。`ab*` の `*` とは*何者*でしょう?左隣の正規表現を受け取って、変換する何か、です。ならば、まさにそのものとして — 関数としてパースしましょう:

```idris
||| A counted repetition suffix: `{n}`, `{n,}` or `{n,m}`.
counted : Parser (Regex -> Regex)
counted = do
  _ <- char '{'
  n <- natural
  f <- (do _ <- char ','
           (do m <- natural
               pure (between n m))
             <|> pure (atLeast n))
       <|> pure (exactly n)
  _ <- char '}'
  pure f

||| A postfix operator, as a *function on regexes*. `a**?` is legal
||| and pointless, exactly like in the AST.
postfix : Parser (Regex -> Regex)
postfix =
      (char '*' *> pure star)
  <|> (char '+' *> pure plus)
  <|> (char '?' *> pure opt)
  <|> counted
```

`postfix` の型は `Parser (Regex -> Regex)` — *結果が関数である*パーサです。関数が値である言語では、これは何ら奇抜なことではありません。ただの火曜日です。`char '*' *> pure star` はこう言っています。「スター文字を見たら、スマートコンストラクタ `star` それ自体を生み出せ」。`counted` の中の三叉路は 3 つの構文をそのまま映します。`{n,m}` なら `between n m`、`{n,}` なら `atLeast n`、裸の `{n}` なら `exactly n` — どれも糖衣構文の章の関数の部分適用で、自分の正規表現が届くのを待っています。

### 文法そのもの

4 つの規則をひとつの `mutual` ブロックに。各規則は、ひとつ強く結合する規則を呼びます:

```idris
mutual
  ||| Lowest precedence: sequences separated by `|`.
  alternation : Parser Regex
  alternation = do
    first <- sequenceOf
    rest  <- many (char '|' *> sequenceOf)
    pure (foldl alt first rest)

  ||| Middle precedence: juxtaposition. Zero atoms is `Eps`,
  ||| which is why the empty pattern compiles.
  sequenceOf : Parser Regex
  sequenceOf = map (foldr cat Eps) (many repetition)

  ||| Highest precedence: an atom with its postfix operators,
  ||| applied left to right.
  repetition : Parser Regex
  repetition = do
    a     <- atom
    posts <- many postfix
    pure (foldl (\r, f => f r) a posts)

  ||| The atoms. `recur` delays the self-reference in `group` —
  ||| see `Regex.Parse.recur` for why.
  atom : Parser Regex
  atom = group <|> classAtom <|> wildcard <|> escapedAtom <|> plain
    where
      wildcard : Parser Regex
      wildcard = char '.' *> pure (Sym anyChar)

      plain : Parser Regex
      plain = map lit (satisfy (not . isMeta))

  group : Parser Regex
  group = char '(' *> recur alternation <* char ')'
```

ここでは、どの fold も飯代をきっちり稼いでいます。`sequenceOf` はアトムたちの上に `cat` を畳み込みます — 糖衣構文の章の `literal` と同じ `foldr cat Eps` の形です。`repetition` が畳み込むのは*関数適用そのもの*。`posts` は `Regex -> Regex` の関数のリストで、`foldl (\r, f => f r) a posts` はアトムを左から右の順にそれぞれへ通していきます。だから `a*?` は `opt (star a)` — 記法を読んだとおりの意味になります。そして `alternation` は、`|` で区切られた枝に `foldl` で `alt` を畳み込みます — 今日のところは正しく、そして記憶にとどめる価値のある 1 行です。[パターンを文字列に戻す](./pretty-printing.md) でプリティプリンタを作るとき、まさにこの fold が精査の的になり、向きを変えることになります。fold には利き手があり、それは木の形にあらわれるのです。

### 結び目 — なぜ Idris はそれを自分で結ばせたのか

上のコードには、一節を丸ごと割く価値のある行があります: `group = char '(' *> recur alternation <* char ')'`。`recur` とは何者でしょう?まさにこのコミットで `Regex/Parse.idr` に追加されたものです:

```idris
||| Tie the knot for recursive grammars.
|||
||| In a lazy language a grammar can refer to itself and nothing
||| special happens. Idris evaluates eagerly, so a self-referential
||| parser value would try to build itself forever. `recur` accepts
||| the parser *lazily* and only looks inside once input arrives.
public export
recur : Lazy (Parser a) -> Parser a
recur p = MkParser $ \cs => runParser p cs
```

私たちの文法は循環しています。`alternation` は `atom` を必要とし、`atom` は(`group` 経由で)`alternation` を必要とします。遅延評価の言語である Haskell なら、循環した定義をそのまま書けば、入力が来るまで何も起きません。結び目はひとりでに、音もなく結ばれます。Idris は先行評価(eager)です。`group` を作るには、*いますぐ* `alternation` を作る必要があり、それには `group` が要り、それには `alternation` が要り……1 文字もパースしないうちに、構築の時点で無限後退に陥ります。`recur` は引数を `Lazy (Parser a)` — Idris の「まだ評価しないで」を明示する型 — として受け取り、ラムダの中でだけ触れることで、このループを断ち切ります。ラムダが走るのは、入力が現れたときです。直しは 2 行。でも教訓はもっと大きい。遅延評価はタダの魔法ではなく、意味論上の選択なのです。Haskell はそれを全体に対して、黙って行います。Idris は局所的に、*見えるかたちで*行います。文法が自分の尻尾に噛みつくただ一箇所で、一度だけ `recur` と書かされること — それは、データの中の再帰が実際にどこに住んでいるのかを見られることへの、公正な対価です。

最後に正面玄関です — 今のところは `Maybe`。次の章でアップグレードします:

```idris
||| Compile a pattern string into a regex — or `Nothing` when the
||| pattern is malformed. The parser must consume every character;
||| trailing garbage is a failure, not a warning.
public export
compile : String -> Maybe Regex
compile = parse alternation
```

あの不正入力のスペックたち — `"a)"`、`"[abc"`、`"a{2"` — は、拒否のためのコードがどこにもないのに通ります。`parse` はもともと完全消費を要求しているので、迷い込んだ `)` のところで止まったパーサは、定義からして失敗なのです。このポリシーはひとつ前の章で書いたもの。それがいま、スペック 3 本ぶんの配当をタダで払ってくれました。

```sh
make test
```

```
  ...
  ok    the empty pattern is Eps
  ...
  ok    a real-world shape: \w+@\w+\.\w+
  ok    a date pattern, this time written as a pattern
121/121 passed
```

23 スペック全部が、green のコミットひとつで: [a7eef7c](https://github.com/ubugeeei-prod/lets-start-functional/commit/a7eef7cbef3dcb1c6a53c1dad355a7bcc1341b33)。ここは立ち止まる価値があります。正真正銘、入り組んだ 150 行のコード — 再帰的な文法、エスケープ、クラス、回数指定の繰り返し — が、red から green への一歩で着地したのです。これは強がりではありません。[前の章](./parser-combinators.md) の配当です。下敷きになったコンビネータはどれも、単体ですでに仕様化されテストされていました。だから間違えようのある工程は「組み立て」だけが残っていて — そしてそれさえも、23 のスペックが待ち構えて捕まえてくれたのです。

## まとめ

- 正規表現の記法は優先順位を持つ文法です。翻訳は機械的 — 優先順位のレベルごとにパーサをひとつ、それぞれをひとつ強く結合するレベルから組み立てます。
- スペックは 3 つの味で来ました。構造(実行できる優先順位表)、不正な入力(末尾のゴミは失敗 — `parse` が強制するので追加コードなし)、そして振る舞い(定番たち: `colou?r`、`gr[ae]y`、メールアドレスっぽい形、日付)。
- 後置演算子は `Regex -> Regex` の*関数*としてパースされ、`foldl` でアトムに適用されます — `star`、`plus`、`opt`、`between n m` がパース結果そのものです。
- `\D` は `complement` の呼び出し 1 回。クラスの項目はそれぞれ範囲を持ち寄り、そのまま `MkSet` に組み上がります。
- 文法の自己言及には `recur : Lazy (Parser a) -> Parser a` が要ります — 先行評価の Idris は、遅延評価の Haskell が黙って結ぶ結び目を見えるようにしてくれます。そして `alternation` の `foldl alt` は、未来を持つ 1 行です([パターンを文字列に戻す](./pretty-printing.md))。

`compile` はまだ、失敗に素っ気ない `Nothing` で答えます — 位置もメッセージもなし。これを出荷に値する API へ仕立てるのが [公開 API](./public-api.md) です。
