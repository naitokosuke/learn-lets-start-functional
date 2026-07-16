---
title: "総仕上げ:レキサ"
description: これまで作ってきたすべてを合成して，本物の道具を作ります．全ルールを1文字進めることが全ルールを1文字微分することそのものになる，最長一致のレキサです．
---

# 総仕上げ:レキサ

エンジンの章も残りひとつです．最後は，上に本物を建てることに使いましょう．あらゆるコンパイラの最初の段階であるレキサを，画面1枚ほどのコードで，本書が作ってきたすべてを動力にして作ります．

## レキサとは何か

コンパイラは`1 + 2*x`をパースする前に，テキストを**トークン**に刻みます．数の`1`，空白，プラス記号，という具合です．その裁断機がレキサ(字句解析器，トークナイザとも)で，伝統的にはルールの表，つまりトークン種別ごとに正規表現ひとつ，という形で仕様化されます．

この表を曖昧でなくする戦略は，**最長一致(maximal munch)**と呼ばれます．各位置で，どれかのルールが作れる*最長*のマッチを取ります．ふたつのルールが並んだら，*先に*書いてある方が勝ちます．どちらの半分も重要です．最長マッチだからこそ，`12foo`は数`12`と`foo`の並びではなくひとつの識別子として字句解析されます(現実の言語で`>=`がふたつではなくひとつの演算子になるのも同じ理由です)．先勝ちのルールは，あらゆる言語がキーワードを扱う方法です．`if`はキーワードのルールにも識別子のルールにも同じ長さでマッチしますが，キーワードのルールは，表の上の方に座っているというだけの理由で勝ちます．

そして，ここが本書全体の回収の瞬間です．たくさんの正規表現を入力の上で足並みを揃えて走らせることは，バックトラック型のマッチャには本当に骨が折れます．しかし微分なら，*すべてのルールを1文字進めることは，すべてのルールを1文字微分することでしかありません*．正規表現は値，ルール表は`List`，字句解析は畳み込みです．やっていきましょう．

## Red:ゲームのルール

コミット[b057007](https://github.com/ubugeeei-prod/lets-start-functional/commit/b057007416f97d6d479907844363c104ed976bf1)が[`regex/tests/src/Spec/Lex.idr`](https://github.com/ubugeeei-prod/lets-start-functional/blob/main/regex/tests/src/Spec/Lex.idr)を追加します．まず，小さな電卓言語のトークン種別です．`Eq`と`Show`は手書きですが，[正規表現はデータである](./06-regex-as-data.md)を経たいまでは完全にお決まりの作業かと思います．

```idris
||| Token kinds for a tiny calculator language.
data Tok = TNum | TIdent | TPlus | TTimes | TLParen | TRParen | TSpace

Eq Tok where
  TNum    == TNum    = True
  TIdent  == TIdent  = True
  TPlus   == TPlus   = True
  TTimes  == TTimes  = True
  TLParen == TLParen = True
  TRParen == TRParen = True
  TSpace  == TSpace  = True
  _       == _       = False

Show Tok where
  show TNum    = "TNum"
  show TIdent  = "TIdent"
  show TPlus   = "TPlus"
  show TTimes  = "TTimes"
  show TLParen = "TLParen"
  show TRParen = "TRParen"
  show TSpace  = "TSpace"
```

次にルール表です．4つの章をかけて手に入れたパターン構文で書きます．

```idris
||| Compile a pattern we wrote ourselves; a typo is a broken rule,
||| and a broken rule should match nothing.
pat : String -> Regex
pat s = fromMaybe Fail (compile s)

||| The rule table. Order matters only for ties: TNum comes before
||| TIdent so that "12" is a number even though \w+ also matches it.
rules : List (Tok, Regex)
rules =
  [ (TSpace,  pat "\\s+")
  , (TNum,    pat "\\d+")
  , (TIdent,  pat "\\w+")
  , (TPlus,   pat "\\+")
  , (TTimes,  pat "\\*")
  , (TLParen, pat "\\(")
  , (TRParen, pat "\\)")
  ]
```

そしてスペックです．最長一致，タイブレーク，失敗，それから設計についての最後のひとつ，という並びです．

```idris
||| Shorthand for expected tokens.
tok : Tok -> String -> Token Tok
tok = MkToken

export
covering
lexSpecs : List Spec
lexSpecs =
  [ shouldBe "a single number is a single token"
      (tokenize rules "42")
      (Just [tok TNum "42"])
  , shouldBe "maximal munch: the longest match wins"
      (tokenize rules "12foo")
      (Just [tok TIdent "12foo"])
  , shouldBe "ties go to the earlier rule: 12 is a number, not a word"
      (tokenize rules "12")
      (Just [tok TNum "12"])
  , shouldBe "a small expression tokenizes completely"
      (tokenize rules "1 + 2*x")
      (Just [ tok TNum "1", tok TSpace " ", tok TPlus "+", tok TSpace " "
            , tok TNum "2", tok TTimes "*", tok TIdent "x"])
  , shouldBe "parentheses too"
      (tokenize rules "(a+1)")
      (Just [ tok TLParen "(", tok TIdent "a", tok TPlus "+"
            , tok TNum "1", tok TRParen ")"])
  , shouldBe "a character no rule accepts fails the whole input"
      (tokenize rules "1 $ 2")
      Nothing
  , shouldBe "the empty input is an empty token list"
      (tokenize rules "")
      (Just [])
  , it "dropping whitespace is a List problem, not a lexer problem"
      (map (filter (\t => t.kind /= TSpace)) (tokenize rules "1 + 2")
        == Just [tok TNum "1", tok TPlus "+", tok TNum "2"])
  ]
```

最後のスペックを味わってみてください．たいていのレキサは「空白を読み飛ばす」フラグを生やしますが，このレキサには要りません．トークンがふつうの`List`として返ってくるので，`filter`はすでに存在しているからです．出力が素のデータであれば，作るかもしれなかった機能の半分は，誰かがもう書いてくれた関数というわけです．redはこちらです．

```
Error: Module Regex.Lex not found
```

## Green:レキサ本体

コミット[d551858](https://github.com/ubugeeei-prod/lets-start-functional/commit/d55185805c8cb5a4d4a7137d74cee33b91785bbb)が[`regex/src/Regex/Lex.idr`](https://github.com/ubugeeei-prod/lets-start-functional/blob/main/regex/src/Regex/Lex.idr)を追加します．(あわせて，スペック自身に足りなかった`import Data.Maybe`もひとつ足しています．`fromMaybe`はプレリュードではなくそこに住んでいます．スペックだって直されるものです．)トークン型はレコードで，種別については総称的です．

```idris
||| A token: which rule fired, and the exact text it consumed.
public export
record Token k where
  constructor MkToken
  kind : k
  text : String

||| Tokens print and compare whenever their kinds do — interface
||| implementations can have interface *constraints*.
export
Show k => Show (Token k) where
  show t = show t.kind ++ " " ++ show t.text

export
Eq k => Eq (Token k) where
  t1 == t2 = t1.kind == t2.kind && t1.text == t2.text
```

実装のヘッダを見てみてください．`Show k => Show (Token k)`です．実装は，*他の実装を要求*できます．`Token k`が印字できるのは，ちょうどその種別が印字できるときです．小さいですが，素敵な仕組みです．あらゆる関数シグネチャにあったのと同じ制約の矢印が，今度は実装の上に現れています．そしてこれこそ，リストやペアや`Maybe`の`Show`が足元でずっと動いてきた仕組みでもあります．

続いて機械部分です．短い関数が3つあります．

```idris
||| The first rule whose regex accepts right now, if any.
firstAccepting : List (k, Regex) -> Maybe k
firstAccepting []              = Nothing
firstAccepting ((k, r) :: rest) =
  if nullable r then Just k else firstAccepting rest

||| Advance every rule by one character. Dead rules collapse to
||| `Fail` on their own — the smart constructors see to that.
step : Char -> List (k, Regex) -> List (k, Regex)
step c = map (\(k, r) => (k, deriv c r))
```

`step`は，正規表現が値であることの見返りをまるごと1行に収めたものです．ルール表全体を1文字進めることは，`deriv`の`map`です．そして`firstAccepting`がタイブレークです．表を上から下へ走査するので，*先の*ルールが構造からして勝ちます．最長マッチの歩みはこんな感じです．

```idris
||| Find the longest match at the head of the input.
|||
||| Walk forward, deriving all rules in lockstep; every time some
||| rule accepts, remember how far we got (`best`). When the input
||| ends — or every rule is dead — the last remembered accept is
||| the answer. Structural recursion on the input: total.
longest : List (k, Regex) -> List Char ->
          (sofar : Nat) -> (best : Maybe (k, Nat)) -> Maybe (k, Nat)
longest rules cs sofar best =
  let best' = case firstAccepting rules of
                Just k  => Just (k, sofar)
                Nothing => best
  in case cs of
       []          => best'
       (c :: rest) =>
         if all (\(_, r) => r == Fail) rules
           then best'
           else longest (step c rules) rest (S sofar) best'
```

最長一致を，文字どおりに実装しています．微分し続け，どれかのルールの正規表現が`nullable`になる(いままさに受理している)たびに，`best`を現在位置で上書きします．入力が尽きるか，すべてのルールが死んだら，最後に覚えた受理が最長マッチです．早期脱出にも注目です．もう何にもマッチできなくなったルールは，たまたま充足不能なだけのだだっ広い木にではなく，*文字どおりの*`Fail`に微分されています．[スマートコンストラクタ](./10-smart-constructors.md)のスマートコンストラクタが，死んだ枝をその場でつぶしてくれるからです．だからこそ，素朴な`== Fail`検査だけで，表全体が死んだことに気づけるわけです．

最後に，ドライバです．

```idris
||| Tokenize a whole string, or fail on the first stretch of input
||| that no rule can start a match on.
|||
||| A zero-length best match is treated as failure too: a rule that
||| matches the empty string would otherwise produce an infinite
||| stream of nothing.
|||
||| `assert_smaller` tells the totality checker what it cannot see
||| on its own: `rest` is a strict suffix of `cs`, because we only
||| recurse when the match consumed at least one character.
public export
tokenize : Eq k => List (k, Regex) -> String -> Maybe (List (Token k))
tokenize rules s = loop (unpack s)
  where
    loop : List Char -> Maybe (List (Token k))
    loop [] = Just []
    loop cs =
      case longest rules cs 0 Nothing of
        Nothing         => Nothing
        Just (_, Z)     => Nothing
        Just (k, S len) =>
          let (consumed, rest) = splitAt (S len) cs in
          map (MkToken k (pack consumed) ::) (loop (assert_smaller cs rest))
```

二度読む価値のあるガードがふたつあります．`Just (_, Z) => Nothing`は長さゼロのマッチを拒みます．`pat "a*"`のようなルールはあらゆる位置で空文字列を受理しますし，空のトークンを無限に吐き出すレキサはレキサではありません．そして`assert_smaller`は，新しい「正直さの注釈」です．このモジュールは`%default total`ですが，全域性チェッカには，`splitAt`が作る`rest`が`cs`の真の接尾辞であることが見えません．こちらには見えています．`S len`というパターンが，少なくとも1文字は消費されたことを保証しています．`assert_smaller cs rest`は，まさにその主張にプログラマが署名する脱出ハッチです．一度だけ，コメント付きで，言葉にできる理由とともに使います．先輩の`covering`と同じく，この注釈はコードを弱めるというより，信頼がどこから入り込むのかを正確に文書化してくれる，という感じです．

```sh
make test
```

```
  ...
  ok    a single number is a single token
  ok    maximal munch: the longest match wins
  ok    ties go to the earlier rule: 12 is a number, not a word
  ok    a small expression tokenizes completely
  ok    parentheses too
  ok    a character no rule accepts fails the whole input
  ok    the empty input is an empty token list
  ok    dropping whitespace is a List problem, not a lexer problem
163/163 passed
```

> [!NOTE]
> 167ではなく163です．リポジトリの履歴ではレキサはベンチマークのコミットより*前*に着地するため，この時点のスイートには[対決:線形時間vsバックトラック](./19-the-race.md)の回帰スペック4本はまだ入っていません．コミットを順に再生すれば，同じ数字が出ます．

## 合成されるプロパティ

締めにひとつ．このレキサは決してバックトラックしません．注意深く書いたからではなく，*できない*からです．エンジンの操作は`deriv`と`nullable`だけ，各ルールは入力1文字につきちょうど1回進み，`tokenize`は消費済みのテキストを二度と訪れません．長さnの文字列をm本のルールで字句解析するコストは，ルール1本あたりn回の微分ステップです．それだけです．ルールが何であっても，です．エンジンに作り込んだ線形時間の性質は，その上に建てられても生き延びた，どころではありません．*合成*されたのです．それが本書全体の静かなテーゼです．芯を正しく作り，すべてをデータと関数にすれば，良い性質はタダで上へと旅をします．

## まとめ

- レキサは，ルール表(トークン種別ごとに正規表現ひとつ)を使い，最長一致のもとでテキストをトークンにします．最長マッチが勝ち，引き分けは先のルールへ(これがキーワードが識別子に勝つ仕組みです)．
- 正規表現が値なら，ルール表は`List (k, Regex)`で，全ルールを進めるのは`map (deriv c)`の1行です．
- `longest`は最後の受理を覚えながら前進します．死んだルールはスマートコンストラクタのおかげで文字どおりの`Fail`につぶれるので，`== Fail`が早期脱出をくれます．
- `tokenize`は長さゼロのマッチを拒み，`assert_smaller`(一度だけ使われ，コメントで正当化された正直さの注釈)で，消費された入力が縮むことを全域性チェッカに伝えます．
- インターフェースの実装には制約を付けられます(`Show k => Show (Token k)`)．そして空白を落とすのは`filter`です．トークンが素のデータだからです．
- レキサはエンジンから線形性を相続します．どのルールも決してバックトラックしないので，この総仕上げは，いつでも一方通行の1パスで走ります．

エンジンは完成し，競走し，証明され，仕事に就きました．残るのは，作り上げたものを眺めることと，それをどこへ持っていくかです．[この先へ](./21-whats-next.md)に進みましょう．
