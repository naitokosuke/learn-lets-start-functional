---
title: 正規表現はデータである
description: 本書の中心となるアイデア——正規表現はデータの木であり、そこに行うすべての操作は、その木の上の普通の関数である。
---

# 正規表現はデータである

イントロダクションは終わりました。Idris はインストール済み、速習も済ませ、[小さなテストハーネス](./05-tdd.md)はテストすべき何かを待っています。いよいよエンジンを作るときです——そしてその出発点は、本書でいちばん大切なアイデアです。

## アイデア

これまで使ってきたどの言語でも、正規表現は*文字列*でした。`"(a|b)*c"` と書いてどこかのライブラリに渡せば、あとはブラックボックスがやってくれます。箱の中では状態機械にコンパイルされているのかもしれないし、直接解釈されているのかもしれない——いずれにせよ、中身を見ることはありません。

その箱を、私たちは捨てます。本書では、正規表現は文字列でも状態機械でもありません。**データの木**——リストやレコードと同じ、ごく普通の値です。そして正規表現に対して行うことはすべて(マッチングも含めて!)、その木を歩く普通の関数になります。

これこそが関数型プログラミングの手筋で、この先何度も登場します。他の設計なら機構の内側に隠してしまうものを、正直で観察可能なデータとして表現するのです。正規表現がデータになれば、組み立てることも、表示することも、比較することも、変換することもできます。そして数章後には——*性質を証明する*ことさえできるのです。

では、その木はどんな形をしているのでしょうか?実は、6 種類のノードがあれば古典的な正規表現をすべて表現できます。とはいえ書き下ろす前に、ハーネスに失敗するテストを差し出す義理があります。

## red:存在しない型を記述する

[TDD の章](./05-tdd.md)のリズムに従って、*こうあってほしい*と願うモジュールに向けてスペックを書くところから始めます。コミット [51d326b](https://github.com/ubugeeei-prod/lets-start-functional/commit/51d326b5444518b66b8b9ed0b468352ff048a63e) の `regex/tests/src/Spec/Core.idr` にある、最初のスペック一覧の全体がこちらです。

```idris
||| Specs for `Regex.Core` — the abstract syntax of regular expressions.
module Spec.Core

import Harness
import Regex.Core

||| The AST is just data: we can build it, print it, and compare it.
export
astSpecs : List Spec
astSpecs =
  [ shouldBe "show renders the match-nothing regex"
      (show Fail) "Fail"
  , shouldBe "show renders the empty-string regex"
      (show Eps) "Eps"
  , shouldBe "show renders a character literal"
      (show (Lit 'a')) "Lit 'a'"
  , shouldBe "show parenthesizes nested structure"
      (show (Cat (Lit 'a') (Star (Lit 'b'))))
      "Cat (Lit 'a') (Star (Lit 'b'))"
  , shouldBe "show renders alternation"
      (show (Alt Eps (Lit 'x')))
      "Alt Eps (Lit 'x')"
  , it "structurally equal regexes are equal"
      (Cat (Lit 'a') (Alt Eps (Lit 'b')) == Cat (Lit 'a') (Alt Eps (Lit 'b')))
  , it "different literals are not equal"
      (Lit 'a' /= Lit 'b')
  , it "different shapes are not equal"
      (Star (Lit 'a') /= Cat (Lit 'a') (Lit 'a'))
  ]
```

このスペックは「願い事リスト」として読んでください。`Fail`、`Eps`、`Lit`、`Cat`、`Alt`、`Star` という名前の値がほしい。`show` には、それらを組み立てるコードそのままの形で表示してほしい。`==` で比較したい。

そのどれもまだ存在しません——この時点の `Regex.Core` にはモジュールヘッダと `%default total` ディレクティブしか入っていません——ので、`make test` はテストランナーにすらたどり着きません。

```
2/3: Building Spec.Core (src/Spec/Core.idr)
Error: While processing right hand side of astSpecs. Undefined name Cat.

Spec.Core:28:26--28:29
 28 |       (Star (Lit 'a') /= Cat (Lit 'a') (Lit 'a'))
                               ^^^
Did you mean any of: Cast, or Nat?
```

ここは立ち止まる価値があります。動的型付き言語では、「red」とはテストが*実行されて失敗した*ことを意味します。Idris には、それより手前の red の色合いがあります。**コードがコンパイルできない**という red です。`Undefined name Cat` は、どの願い事がまだ叶っていないのかを型チェッカーが正確に教えてくれているのです。コンパイラは最初のテストランナーであり、コンパイルエラーは立派な失敗するテストです——本書ではこの先も、多くの red ステップがまさにこの姿で現れます。

## green:6 つのコンストラクタ

答えがこちら。コミット [832542c](https://github.com/ubugeeei-prod/lets-start-functional/commit/832542c132ce21d2b7902207cc654ca9621f02fd)、`regex/src/Regex/Core.idr` の冒頭です。

```idris
||| The abstract syntax of regular expressions.
|||
||| Six constructors are enough to express every classic regex:
|||
||| | Constructor | Regex syntax | Matches                              |
||| |-------------|--------------|--------------------------------------|
||| | `Fail`      | (none)       | nothing at all — the empty set       |
||| | `Eps`       | (empty)      | exactly the empty string             |
||| | `Lit c`     | `c`          | exactly the one-character string "c" |
||| | `Cat l r`   | `lr`         | an `l`-match followed by an `r`-match|
||| | `Alt l r`   | `l\|r`       | whatever `l` or `r` matches          |
||| | `Star r`    | `r*`         | zero or more `r`-matches in a row    |
|||
||| Everything else you know from regex — `+`, `?`, character classes,
||| `{n,m}` — is syntactic sugar that we will *compile down* to these
||| six later in the book.
public export
data Regex : Type where
  ||| Matches nothing at all: the empty *set* of strings (∅).
  ||| Do not confuse it with `Eps`, which matches the empty *string*.
  Fail : Regex
  ||| Matches exactly the empty string (ε).
  Eps : Regex
  ||| Matches exactly one specific character.
  Lit : Char -> Regex
  ||| Sequencing (concatenation): `Cat l r` matches a string that can
  ||| be split so that `l` matches the front and `r` matches the rest.
  Cat : Regex -> Regex -> Regex
  ||| Choice (alternation): matches anything either branch matches.
  Alt : Regex -> Regex -> Regex
  ||| Kleene star: zero or more repetitions, so `Star r` always
  ||| matches the empty string too.
  Star : Regex -> Regex
```

これは代数的データ型(algebraic data type)です。[Idris 速習](./04-idris-crash-course.md)で見たものとまったく同じ——ただ少し大きく、そして本書の土台を支える、大事な役目を持っています。`Regex` は 6 つのうちのどれかであり、そのうち 3 つはより小さな `Regex` を中に含みます。この再帰こそが、これを木にしているのです。

コードの多くが `|||` のドキュメントコメント(doc comment)であることに注目してください。これは意図的なもので、盗む価値のある習慣です。doc コメントはコードの*次の読者*のために書くものです——こういうプロジェクトでは、それはたいてい 3 週間後のあなた自身です。Idris は doc コメントをプログラムの一部として扱います。REPL に尋ねれば、そのまま返してくれます。

```
Main> :doc Regex
data Regex.Core.Regex : Type
  The abstract syntax of regular expressions.

  Six constructors are enough to express every classic regex:
  ...
  Constructors:
    Fail : Regex
      Matches nothing at all: the empty *set* of strings (∅).
      Do not confuse it with `Eps`, which matches the empty *string*.
    Eps : Regex
      Matches exactly the empty string (ε).
  ...
```

6 つのコンストラクタを、具体例とともに順に見ていきましょう。

- `Lit 'a'` は 1 文字の文字列 `"a"` にだけマッチし、それ以外にはマッチしません。正規表現の `a` です。
- `Cat (Lit 'a') (Lit 'b')` は `"ab"` にマッチします。`a` のマッチに `b` のマッチが続く形。正規表現の `ab` です。
- `Alt (Lit 'a') (Lit 'b')` は `"a"` または `"b"` にマッチします。正規表現の `a|b` です。
- `Star (Lit 'a')` は `""`、`"a"`、`"aa"`、... にマッチします。正規表現の `a*` です。

より大きなパターンは、単により大きな木になるだけです。正規表現 `(a|b)*c` はこうなります。

```idris
Cat (Star (Alt (Lit 'a') (Lit 'b'))) (Lit 'c')
```

たしかに `(a|b)*c` より騒がしい見た目です——今のところは。[後の章](./14-pattern-syntax.md)で、コンパクトな構文をまさにこの形の木へとパースするようになります。木のほうが不便な代替表現なのではありません。木こそが*本体*で、文字列の構文はそのフロントエンドなのです。

### Fail と Eps は同じ「無」ではない

引数を持たない 2 つの葉のコンストラクタには、それだけの時間を割く価値があります。この 2 つの混同は、計算機科学のこの界隈における古典的な初心者のつまずきどころだからです。

- `Fail` は文字列の空**集合**です。*何にも*マッチしません。空文字列にも、どんな文字列にも。パターンのどこかが `Fail` に行き着いたら、そのマッチの枝は死んでいます。伝統的な記号は ∅ です。
- `Eps` はちょうど 1 つの文字列——空**文字列** `""`——だけを含む集合です。消費すべきものが何も残っていない限り、マッチは成功します。伝統的な記号は ε です。

見慣れた型でたとえるなら、`Fail` は決して return しない関数、`Eps` は `void` を返す関数です——何も返さないのも、return することには違いありません。片方は答えの不在、もう片方は中身が空っぽの答えです。

この区別を頭の片隅で温めておいてください。続く 2 つの章は、マッチングアルゴリズム全体をこの区別の上に組み上げます。

## Regex の表示方法を Idris に教える

スペックは `show (Lit 'a')` が `"Lit 'a'"` になることを要求していますが、5 分前に発明したばかりの型の表示方法を Idris が知っているはずもありません。教えてあげる必要があります——そのための仕組みが**インターフェース(interface)**です。

Rust を知っているなら、インターフェースとはトレイトのことです。Haskell なら型クラス。Java や TypeScript のインターフェースにも近いのですが、ひとつひねりがあります。実装が型の*外側*に、独立したブロックとして置かれるため、自分が定義していない型に対してもインターフェースを実装できるのです。

`Show` は「この型は文字列として表示できる」ことを表す標準インターフェースです。まずは実働部隊となる関数から。同じコミットより。

```idris
mutual
  ||| Render a regex the way you would type its constructors in code.
  showRegex : Regex -> String
  showRegex Fail      = "Fail"
  showRegex Eps       = "Eps"
  showRegex (Lit c)   = "Lit " ++ show c
  showRegex (Cat l r) = "Cat " ++ showArg l ++ " " ++ showArg r
  showRegex (Alt l r) = "Alt " ++ showArg l ++ " " ++ showArg r
  showRegex (Star r)  = "Star " ++ showArg r

  ||| Constructor arguments need parentheses — except the ones that
  ||| have no arguments of their own.
  showArg : Regex -> String
  showArg Fail = "Fail"
  showArg Eps  = "Eps"
  showArg r    = "(" ++ showRegex r ++ ")"
```

互いを呼び合う 2 つの関数——だからこそ `mutual` ブロックに入っています。Idris は通常、使う前に定義されていることを要求しますが、`mutual` は「これらの定義はひとまとまりなので、まとめてチェックしてほしい」という宣言です。

そもそもなぜ関数が 2 つ必要なのでしょう?括弧のためです。`Cat (Lit 'a') (Star (Lit 'b'))` が `Cat Lit 'a' Star Lit 'b'` と表示されてはいけません——これは正しいコードではないうえ、曖昧です。そこで `showArg` は*引数*をすべて括弧で包みます。例外は `Fail` と `Eps` で、自分の引数を持たないので括弧も要りません。スペック `"show parenthesizes nested structure"` は、まさにこの挙動を実装前に釘付けにしていました。

表示処理ができてしまえば、インターフェースの実装は 1 行です。

```idris
||| Regexes can be printed. `Show` is an *interface* (if you know
||| Haskell: a type class; if you know Rust: a trait) and this block
||| is our implementation of it for `Regex`.
export
Show Regex where
  show = showRegex
```

「`Regex` はこのように `Show` を実装する。その `show` は `showRegex` である」と読んでください。これ以降、エコシステム中の「`Show` できるものなら何でもどうぞ」という関数すべて——私たちのハーネスの `shouldBe` も含めて——が `Regex` を受け付けるようになります。

## Regex の比較方法を Idris に教える

等価性についても同じ話です。`Eq` インターフェースが要求するのは `==` で、これを構造的に定義します——2 つの木が等しいのは、まったく同じ形をしていて、葉にまったく同じ文字が並んでいるときです。

```idris
||| Structural equality: two regexes are equal when they are built
||| from exactly the same constructors in the same shape.
|||
||| Note this is equality of *syntax*, not of *meaning*:
||| `Alt (Lit 'a') (Lit 'a')` and `Lit 'a'` match the same strings
||| but are not `==`.
export
Eq Regex where
  Fail      == Fail      = True
  Eps       == Eps       = True
  Lit c     == Lit d     = c == d
  Cat l1 r1 == Cat l2 r2 = l1 == l2 && r1 == r2
  Alt l1 r1 == Alt l2 r2 = l1 == l2 && r1 == r2
  Star r1   == Star r2   = r1 == r2
  _         == _         = False
```

形が一致するケースでは子へと再帰し、最後の包括ケース `_ == _ = False` が `Eps == Fail` のような組み合わせ違いをすべて引き受けます。

> [!WARNING]
> これは**構文**の等価性であって、**意味**の等価性ではありません。`Alt (Lit 'a') (Lit 'a')` と `Lit 'a'` はまったく同じ文字列にマッチしますが、木としては別物なので `==` ではありません。2 つの正規表現が同じ意味かどうかを判定するのは、はるかに深い問題です——構造的等価性は、テストに必要な、安上がりで正直な道具です。「この関数は、期待したとおりの木を組み立てたか?」に答えてくれます。

## green、今度こそ本当に

red のコミットの時点で、新しいスペックは `tests/src/Main.idr` に登録済みです——ランナーの `main` は `runSpecs (sanitySpecs ++ astSpecs)` になりました。そのファイルの doc コメントにあるとおり、各スペックモジュールはただの `List Spec` をエクスポートするので、スイートへのモジュール追加はリストの追加にすぎません。走らせましょう。

```sh
make test
```

```
  ok    true is true
  ok    one plus one is two
  ok    strings concatenate
  ok    show renders the match-nothing regex
  ok    show renders the empty-string regex
  ok    show renders a character literal
  ok    show parenthesizes nested structure
  ok    show renders alternation
  ok    structurally equal regexes are equal
  ok    different literals are not equal
  ok    different shapes are not equal
11/11 passed
```

ハーネスの章からの 3 つの動作確認と、新しい 8 つのスペック。すべて green です。エンジンに心臓が備わりました——まだ鼓動していないだけです。

> [!NOTE]
> 私たちが書か*なかった*ものを数えてみてください。マッチングのロジックも、状態機械も、気の利いた仕掛けも何ひとつありません。6 種類のデータの形を宣言し、その表示と比較の方法を言語に教えただけです。関数型言語において、これは本番前のウォームアップではありません——データを定義することが、プログラムの前半*そのもの*なのです。

## まとめ

- ここでの正規表現は文字列でも状態機械でもなく、素朴なデータの木です。そこに行う操作はすべて普通の関数になります。
- 6 つのコンストラクタ——`Fail`、`Eps`、`Lit`、`Cat`、`Alt`、`Star`——で古典的な正規表現はすべて表現できます。それ以外はすべて、後でこの 6 つへとコンパイルする糖衣構文です。
- `Fail` は文字列の空*集合*(何にもマッチしない)にマッチし、`Eps` は空*文字列*にマッチします。ふたつは異なる「無」です。
- 型のある言語では、`Undefined name Cat` のようなコンパイルエラーが red の最初の色合いです——型チェッカーは最初のテストランナーなのです。
- インターフェース(`Show`、`Eq`)は Idris におけるトレイト/型クラスです。実装ブロックを書くことで、既存の汎用コードが私たちの新しい型を扱えるようになります。
- `Regex` の `==` は構造的です。構文の等価性であって、意味の等価性ではありません——`Alt (Lit 'a') (Lit 'a')` と `Lit 'a'` は `==` ではありません。
- doc コメント(`|||`)はプログラムの一部です。REPL の `:doc Regex` が、それを次の読者に届けてくれます。

木は組み立てられ、表示でき、比較できるようになりました——けれど、まだ何にもマッチできません。最初に答え方を教える問いは、一風変わった響きがするはずです。[空文字列にマッチするか?](./07-nullable.md)
