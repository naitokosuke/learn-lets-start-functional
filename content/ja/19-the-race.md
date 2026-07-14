---
title: "対決:線形時間 vs バックトラック"
description: バックトラック型のライバルを作り、微分エンジンと競走させます — そして最初のベンチマークが倒したのは、予想もしなかった側でした。
---

# 対決:線形時間 vs バックトラック

本書は 19 の章を費やして、微分はバックトラックに勝つと主張してきました。ストップウォッチで証明するときです — そして、最初に試したとき実際に何が起きたのかを、正直にお話しするときでもあります。この章は実話です。コミットが、その領収書です。

## 第 1 幕:ライバルを作る

ひとりではレースになりません。バックトラック型のマッチャ — 多くの主流な正規表現エンジンの動き方を単純化したもの — が必要で、しかもそれは*正しく*なければなりません。さもなければレースは無意味です。だから最初のスペックは、速さの話ではまったくありません:ライバルは、あらゆる入力について私たちのエンジンと同じ判定を下さなければならないのです。

コミット [98b6a61](https://github.com/ubugeeei-prod/lets-start-functional/commit/98b6a61c029070f1af24f53251b93692043bdf45) が [`regex/tests/src/Spec/Naive.idr`](https://github.com/ubugeeei-prod/lets-start-functional/blob/main/regex/tests/src/Spec/Naive.idr) を追加します:

```idris
||| Both engines, same verdict?
agree : String -> String -> Bool
agree pat input =
  case compile pat of
    Left _  => False
    Right r => naiveMatch r input == matches r input

export
naiveSpecs : List Spec
naiveSpecs =
  [ it "the backtracker agrees on literals"
      (agree "abc" "abc" && agree "abc" "abd" && agree "abc" "")
  , it "the backtracker agrees on choice"
      (agree "a|b" "a" && agree "a|b" "b" && agree "a|b" "c")
  , it "the backtracker agrees on stars"
      (agree "a*" "" && agree "a*" "aaaa" && agree "a*" "aab"
        && agree "(ab)*" "abab" && agree "(ab)*" "aba")
  , it "the backtracker agrees on classes and shorthands"
      (agree "[a-c]+" "cab" && agree "[a-c]+" "cad"
        && agree "\\d{2,4}" "123" && agree "\\d{2,4}" "12345")
  , it "the backtracker agrees on the tricky nullable-head cases"
      (agree "(a*)*b" "aaab" && agree "(a*)*b" "aaaa"
        && agree "(a|)(a|)b" "ab" && agree "(a|)(a|)b" "aab")
  , it "the backtracker agrees on a real-world shape"
      (agree "\\w+@\\w+\\.\\w+" "user@example.com"
        && agree "\\w+@\\w+\\.\\w+" "user@example")
  ]
```

「厄介な nullable 先頭のケース」に注目してください — `(a*)*b` のような、部分式が空にマッチしうるパターンこそ、素朴なマッチャが微妙に間違った答えを返したり、停止しなくなったりする場所です。red は、例によってコンパイル時にやってきます:

```
Error: Module Regex.Naive not found
```

コミット [6f62a9f](https://github.com/ubugeeei-prod/lets-start-functional/commit/6f62a9f894cb15031bf5b7a23eacd94160137c9a) が [`regex/src/Regex/Naive.idr`](https://github.com/ubugeeei-prod/lets-start-functional/blob/main/regex/src/Regex/Naive.idr) を供給します:

```idris
||| The matcher we deliberately did NOT build: a backtracker.
|||
||| This is (a simplified version of) how many mainstream regex
||| engines work. To match `Alt l r`, try `l`; if the rest of the
||| match fails, rewind and try `r`. Every choice point is a fork,
||| and on adversarial patterns the forks multiply: `(a?){n}` gives
||| 2^n ways to slice a run of a's, and a failing match visits all
||| of them. That blow-up has a name — catastrophic backtracking —
||| and it has taken real services down (Cloudflare, 2019; Stack
||| Overflow, 2016).
|||
||| Meanwhile `Regex.Core.matches` walks the input once, whatever
||| the pattern. The benchmark in the book races the two.
module Regex.Naive

import Regex.Core
import Regex.Set

-- Backtracking recursion is not structural; `covering` is honest.
%default covering

||| The worker. `k` is the *continuation*: what the rest of the
||| match still expects. `go r cs k` means "match some prefix of
||| `cs` against `r`, then hand the leftovers to `k`".
|||
||| Continuations are the functional way to say "and then". Note
||| how `Alt` becomes `||` — try the left match wholesale, or start
||| over on the right — and how `Cat l r` chains: match `l`, and
||| the continuation of `l` is "now match `r`".
|||
||| The one wrinkle: `Star`. A star whose body can match the empty
||| string (think `(a|)*`) could "repeat" forever without eating
||| anything, so we only loop when the body actually consumed input
||| — that is the `length rest < length cs` guard.
go : Regex -> List Char -> (List Char -> Bool) -> Bool
go Fail      _         _ = False
go Eps       cs        k = k cs
go (Sym s)   []        _ = False
go (Sym s)   (c :: cs) k = member c s && k cs
go (Cat l r) cs        k = go l cs (\rest => go r rest k)
go (Alt l r) cs        k = go l cs k || go r cs k
go (Star r)  cs        k =
  k cs || go r cs (\rest =>
    if length rest < length cs
      then go (Star r) rest k
      else False)

||| Whole-string matching, by backtracking. Same specification as
||| `Regex.Core.matches`; very different running time.
|||
||| The final continuation answers the final question: after the
||| whole pattern has matched, is the input fully consumed?
public export
naiveMatch : Regex -> String -> Bool
naiveMatch r s = go r (unpack s) null
```

スタイルは**継続渡し(continuation-passing)**です:`k` — 継続(continuation) — は、「マッチの残りがまだ期待していること」を意味する関数です。継続は、関数型の言葉で言う「それから」。正規表現は単独では「成功したか?」に答えられません。答えられるのは「これが食べ残しです — 続きはうまくいきますか?」だけです。だから `Cat l r` は `l` をマッチさせ、「次は `r` をマッチして、そのあと元々やるはずだったことをやる」という継続を手渡します。`Alt` は正直な `||` になります:左側の未来を丸ごと試し、その可能性の木がすべて失敗したら、巻き戻して右を試す。あの 1 行の `||` こそ*が*バックトラックです — 読んで美しく、そして静かに指数的。`Star` のガード(`length rest < length cs`)は幅ゼロの繰り返しを拒みます。`(a|)*` が停止するのはそのおかげです。そして `%default covering` は、この再帰が構造的でないことを最初から白状しています。`naiveMatch` の最後の継続は `null`:パターンが終わったなら、入力も終わっていなければならない。

```sh
make test
```

```
  ...
  ok    the backtracker agrees on the tricky nullable-head cases
  ok    the backtracker agrees on a real-world shape
154/154 passed
```

## 第 2 幕:レース場

古典的な敵対的ファミリー — Russ Cox の有名な記事に由来します — は、`(a?){n}a{n}` をちょうど `n` 個の a にマッチさせるものです。全体が成功するには各 `a?` が空にマッチしなければなりませんが、バックトラッカーには a たちの配り方が `2^n` 通りあり、失敗しながら前へ進むうちに、実質そのすべてを訪ねてしまいます。ベンチのハーネス、[`regex/bench/src/Main.idr`](https://github.com/ubugeeei-prod/lets-start-functional/blob/main/regex/bench/src/Main.idr) です:

```idris
||| `(a?){n}a{n}`, built directly with the sugar combinators.
evil : Nat -> Regex
evil n = cat (exactly n (opt (lit 'a'))) (exactly n (lit 'a'))

||| n a's.
input : Nat -> String
input n = pack (replicate n 'a')

||| A fixed, friendly pattern: (a|b)*c.
fixed : Regex
fixed = cat (star (alt (lit 'a') (lit 'b'))) (lit 'c')

||| n a's followed by a single c.
inputC : Nat -> String
inputC n = pack (replicate n 'a' ++ ['c'])

||| A duration in milliseconds.
ms : Clock Duration -> Double
ms c = cast (seconds c) * 1000 + cast (nanoseconds c) / 1000000

||| Time one boolean computation. The `Lazy` argument keeps the
||| work from happening before the clock starts.
covering
timed : String -> Lazy Bool -> IO ()
timed label act = do
  t0 <- clockTime Monotonic
  let result = force act
  t1 <- clockTime Monotonic
  putStrLn $ "  " ++ label ++ ": "
          ++ show (ms (timeDifference t1 t0)) ++ " ms"
          ++ "  (matched: " ++ show result ++ ")"

covering
race : Nat -> IO ()
race n = do
  putStrLn $ "n = " ++ show n
  timed "derivatives " (matches (evil n) (input n))
  timed "backtracking" (naiveMatch (evil n) (input n))

covering
main : IO ()
main = do
  putStrLn "(a?){n}a{n} against a^n — both engines"
  traverse_ race [10, 12, 14, 16, 18, 20]
  putStrLn ""
  putStrLn "fixed pattern (a|b)*c, growing input — derivatives only"
  traverse_ (\n => timed ("length = " ++ show (S n))
                         (matches fixed (inputC n)))
            [9999, 99999, 999999]
```

レースでは、`n` を増やしながら両エンジンを敵対的ファミリーにぶつけます。後半のセクションは「入力に対して線形」を直接に突き止めます — パターンを*固定*して、入力を千倍まで育てるのです。

唯一の機微は `Lazy Bool` です:これがないと、Idris は `timed` を呼ぶ*前に*マッチを評価してしまい、私たちは無を計測することになります。`force act` が、最初の時刻読み取りのあとで実際の仕事を始めてくれます。Makefile には `bench` ターゲットが加わります:

```
## Race the derivative engine against the backtracker.
bench: install
	rm -rf bench/depends
	cp -R tests/depends bench/depends
	idris2 --build bench/bench.ipkg
	./bench/build/exec/bench
```

> [!NOTE]
> コミットを再生している方へ:ライバルはプリティプリンタの直後に作られましたが、ベンチマーク自体が配線されたのは*最後* — 証明とレキサの章のあと — です。この章の中でスイートの数が 154 から 167 に跳ぶのはそのためです。コミット履歴は全員を正直に保ちます。私たち自身も含めて。

## 第 3 幕:どんでん返し

私たちは `make bench` と打ち込み、バックトラッカーが苦しむのを眺めようと腰を落ち着けて — これを得ました:

```sh
make bench
```

```
Killed: 9
```

結果は 1 行もなし。オペレーティングシステムがプロセスを殺しました — メモリ不足です。そしてここがどんでん返し:処理はバックトラッカーに到達すらしていませんでした。犠牲者は、**私たちの**エンジンだったのです。

そこで、こういうときにやるべきことをやりました:診断です。`evil n` を数文字ぶん手で微分して、木を観察します。文字を食べるかもしれないし食べないかもしれない各 `a?` が、微分を選択肢へと分裂させ、その選択肢は `Alt x (Alt y (Alt x ...))` という形で — *重複*込みで — 届きます。[スマートコンストラクタ](./10-smart-constructors.md) の `alt` は重複を確かに検査しますが、浅くです:`if l == r then l else Alt l r` は、直接のふたつの引数しか比べません。上の重複した `x` は背骨(spine)の 1 段下に隠れていて、あの検査はそこを決して見ません。ゴミは 1 回の微分ステップを生き延び、次のステップで殖え、以後のステップごとに複利で積み上がり — 時計が何かを印字する前に、メモリが尽きるのです。

治療法は、Brzozowski の 1964 年の原論文からすでに知られていました:**選択の正規化**です。`Alt` の背骨全体をリストに平坦化し、どこに潜んでいようと重複を取り除き、組み直す。私たちは 60 年もののレンマを `make bench` で再発見したわけで、これはどこか身のすくむ話であると同時に、まさにそう感じるのが正しい体験でもあります。

まず、この失敗をスペックとして釘付けにします — コミット [40b08d8](https://github.com/ubugeeei-prod/lets-start-functional/commit/40b08d864e98f2cbabfc6fc3202e7ee16ae1bc19)。`Spec/Core.idr` の `smartSpecs` に、新しいケースがふたつ加わります:

```idris
  , shouldBe "alternatives flatten and drop duplicates"
      (alt (Alt (lit 'a') (lit 'b')) (Alt (lit 'b') (lit 'c')))
      (Alt (lit 'a') (Alt (lit 'b') (lit 'c')))
  , shouldBe "duplicates hiding on the right are found too"
      (alt (lit 'a') (Alt (lit 'b') (lit 'a')))
      (Alt (lit 'a') (lit 'b'))
```

そして `Spec/Naive.idr` には、例のパターンファミリーと、治療の効果を直接測る回帰テストが加わります:

```idris
||| The catastrophic pattern family `(a?){n}a{n}`.
evil : Nat -> Regex
evil n = cat (exactly n (opt (lit 'a'))) (exactly n (lit 'a'))

||| Derive `r` through a run of n a's.
run : Nat -> Regex -> Regex
run n r = foldl (flip deriv) r (replicate n 'a')
```

```idris
    -- The regression that made this chapter necessary: without
    -- flattening-and-deduplication in `alt`, the derivatives of
    -- (a?){n}a{n} grow without bound and eat all memory.
  , it "derivatives of the catastrophic pattern stay small"
      (size (run 32 (evil 32)) < 5000)
  , it "and the catastrophic pattern still matches correctly"
      (matches (evil 24) (pack (replicate 24 'a'))
        && not (matches (evil 24) (pack (replicate 23 'a'))))
```

この red はコンパイルに失敗します — `size` がまだ存在しません — そして存在するようになっても、古い `alt` では平坦化と重複除去のスペックを通せません。コミット [fcdc16b](https://github.com/ubugeeei-prod/lets-start-functional/commit/fcdc16b7a02a9b4cd000ef5828ad9a55b52cb3d5) が [`regex/src/Regex/Core.idr`](https://github.com/ubugeeei-prod/lets-start-functional/blob/main/regex/src/Regex/Core.idr) に修正を届けます:

```idris
||| Flatten an Alt-spine into the list of its alternatives.
||| `Fail` contributes nothing — it is the identity of choice.
altList : Regex -> List Regex
altList (Alt l r) = altList l ++ altList r
altList Fail      = []
altList r         = [r]

||| Rebuild a (deduplicated) list of alternatives into a regex.
rebuildAlt : List Regex -> Regex
rebuildAlt []        = Fail
rebuildAlt [r]       = r
rebuildAlt (r :: rs) = Alt r (rebuildAlt rs)

||| Choose between two regexes — but normalize while building.
|||
||| Naively, `alt` only needs to drop `Fail` branches and collapse
||| `alt r r` to `r`. That version worked — until the benchmark
||| chapter, where deriving `(a?){n}a{n}` grew choices like
||| `Alt x (Alt y (Alt x ...))`: the duplicate `x` hides deep in the
||| spine where a shallow equality check never sees it, and memory
||| runs out. So we normalize properly: flatten every choice into a
||| list, drop duplicates wherever they sit, and rebuild. Brzozowski
||| knew this in 1964; we rediscovered it with `make bench`.
public export
alt : Regex -> Regex -> Regex
alt l r = rebuildAlt (nub (altList l ++ altList r))
```

加えて、物差しも(`nub` のための `import Data.List` も):

```idris
||| The number of constructors in a regex — the measuring stick for
||| claims like "derivatives stay small".
public export
size : Regex -> Nat
size Fail      = 1
size Eps       = 1
size (Sym _)   = 1
size (Cat l r) = S (size l + size r)
size (Alt l r) = S (size l + size r)
size (Star r)  = S (size r)
```

古い `alt` の挙動は、すべて特殊ケースとして転がり出てきます:`Fail` の分岐は `altList Fail = []` なので消え、`alt r r` は `nub` が 1 部だけ残すのでつぶれます。新しい力は、背骨の*どんな深さ*にいる重複でも捕まえられることです。そして、変わって**いない**ものに注目してください:`deriv`、`matches`、`nullable` — エンジンのロジックは手つかずです。修正はまるごと、ひとつのスマートコンストラクタの中に住んでいます。これこそスマートコンストラクタが買ってくれたものです:プログラム中のすべての `Alt` が組み立てられる、たったひとつの関所。

```sh
make test
```

```
  ...
  ok    alternatives flatten and drop duplicates
  ok    duplicates hiding on the right are found too
  ...
  ok    derivatives of the catastrophic pattern stay small
  ok    and the catastrophic pattern still matches correctly
  ...
167/167 passed
```

## 第 4 幕:いざ、レース

`alt` が正規化するようになって、`make bench` はついに数字を出します。本書を書いたマシン(Apple Silicon、Idris 2 0.8.0、Chez Scheme バックエンド)での実走がこちらです:

```
(a?){n}a{n} against a^n — both engines
n = 10
  derivatives : 0.084 ms  (matched: True)
  backtracking: 0.079 ms  (matched: True)
n = 12
  derivatives : 0.272 ms  (matched: True)
  backtracking: 0.474 ms  (matched: True)
n = 14
  derivatives : 0.58 ms  (matched: True)
  backtracking: 1.306 ms  (matched: True)
n = 16
  derivatives : 0.763 ms  (matched: True)
  backtracking: 7.355 ms  (matched: True)
n = 18
  derivatives : 1.349 ms  (matched: True)
  backtracking: 23.989 ms  (matched: True)
n = 20
  derivatives : 2.416 ms  (matched: True)
  backtracking: 113.461 ms  (matched: True)
```

正確な数字はマシンに依りますが、*形*は依りません。そして、形こそが物語のすべてです。`n = 10` では両エンジンは互角。そこからバックトラッカーは、`n` が 2 増えるたびにおよそ 4 倍になっていきます — ストップウォッチを着けた `2^n` です。少し外挿してみましょう:`n = 30` なら数分、`n = 40` なら数日。(このベンチマークの以前の版は `n = 22` を試しました。CPU 時間 12 分の後、私たちの手で殺しました。)微分エンジンは、`n = 20` のケースに 2 ミリ秒で答えています。

実走の後半は、本書の売り文句にあった約束をそのまま実演します — *固定した*パターンに、千倍まで伸びる入力です:

```
fixed pattern (a|b)*c, growing input — derivatives only
  length = 10000: 0.63 ms  (matched: True)
  length = 100000: 6.993 ms  (matched: True)
  length = 1000000: 102.043 ms  (matched: True)
```

入力が 10 倍なら、時間も 10 倍:1 文字につき微分 1 回、100 万文字を 0.1 秒で。線形とは、線形のことです。

> [!NOTE]
> トロフィーを受け取る前に、正直な注意をひとつ。「入力に対して線形」は無条件の約束ですが、1 文字あたりの*定数*は、そのパターンの微分がどこまで大きくなるかに依存します。そして私たちの `nub` ベースの正規化は、その帳簿付けを素朴にやっています。敵対的な `(a?){n}a{n}` ファミリー相手では、*パターン*の方を育てると高くつきます — `evil 100` は 1 マッチに数秒かかります。ステップごとに大きな選択肢リストを歩いて重複除去するからです。産業用の微分エンジンはメモ化でここから抜け出します(次節)。私たちのエンジンは、読みやすいままでいることを選びます。

## 産業用エンジンは何をしているのか

私たちのエンジンはいまや、本気の線形時間マッチャたちと同じ*種*です — 重たい最適化を除けば。Google の RE2 は — まさにこのバックトラックの病理への応答として作られました — 正規表現をオートマトンにコンパイルし、DFA を遅延で構築します。どの状態が重要かを入力が明かしていくのに合わせて、状態をキャッシュするのです。メモ化された微分は、同じトリックに帰着します:(状態, 文字) のペアごとに一度だけ計算されてキャッシュされた `deriv` は、それ自体が遅延 DFA です。この構成は、[この先へ](./21-whats-next.md) で出会う Owens–Reppy–Turon の論文が丹念に研究しています。Rust の `regex` クレートも同じ哲学で、線形保証つきのひとつのインターフェースの背後に、エンジンの道具箱を持っています。どのエンジンもやらないのがバックトラックです — 私たちのストップウォッチが確認したとおり、平均的なケースでは速くても隅のケースで指数的なエンジンは、きっかけとなる入力を待つだけの障害だからです。

## まとめ

- ライバルは継続渡しのバックトラッカーです:`k` は「マッチの残りが期待するもの」、`Alt` は `||` になり(あの 1 行*こそ*バックトラック)、`Cat` は継続を連鎖し、`Star` は空本体のループをガードします。スペックが、微分エンジンとの全面一致に釘付けにします。
- ベンチマークは、Russ Cox の `(a?){n}a{n}` ファミリーで両者を競わせます。`Lazy` が、仕事を時計の内側に保ちます。
- どんでん返し:最初の `make bench` は、*私たちの*エンジンを OOM させました。`alt` の浅い重複検査は `Alt` の背骨の奥にいる重複を見逃し、微分のゴミは 1 文字ごとに複利で増えます。
- 修正は Brzozowski 自身の正規化 — 平坦化し、重複除去し(`nub`)、組み直す — で、まるごと `alt` スマートコンストラクタの中に実装されました。`size` が、このプロパティを以後永遠にスイートで見張ります。
- 産業用エンジン(RE2、rust/regex)は、メモ化された微分の遅延 DFA 版のいとこです:同じ種、より多くのメッキ。

エンジンは速く、肝心なところは証明済みで、自前のベンチマークに鍛えられました。今度はこれで何かを*作る*番です:[総仕上げ:レキサ](./20-lexer.md)。
