---
title: テストが定理になる
description: 依存型は「rがsにマッチする」をデータ型に変えます．そしてnullableの正しさが，すべての正規表現について一度に成り立つコンパイル時の事実になります．
---

# テストが定理になる

本書のスペックはここまで，こちらで選んだ有限個の例を検査するものでした．この章では*すべての*入力を一度に検査します．しかもテストランナーは型チェッカです．

## 例の限界

`nullable`のスペックは，`nullable Eps`が`True`であること，`nullable (lit 'a')`が`False`であること，という具合にひと握りのケースを表明します．良いテストです．しかし`Regex`は無限の型です．どのスペックも出会ったことのない正規表現が，必ず存在し続けます．「`nullable r`が`True`になるのは，ちょうど`r`が空文字列にマッチするとき」と言うとき，これは**すべての**正規表現についての主張，つまりfor-allの文になっています．そして，有限個の例のリストでfor-allの文を釘付けにすることはできません．

ここが，Idrisが「気の利いた関数型言語」であることをやめて本来の姿を現す場所です．依存型のある言語では，for-allの文を*型*として書くことができ，その証明は，その型を持つふつうの*プログラム*です．プログラムが型検査を通れば，文は真です．すべての入力について，永遠に，です．テストデータもカバレッジの穴もありません．

## Red:本書でいちばん奇妙な失敗するテスト

コミット[f4ee977](https://github.com/ubugeeei-prod/lets-start-functional/commit/f4ee977db100cd755430936586eba1ffb4988166)が[`regex/tests/src/Spec/Verified.idr`](https://github.com/ubugeeei-prod/lets-start-functional/blob/main/regex/tests/src/Spec/Verified.idr)を追加します．丸ごと引用できる短さです．

```idris
||| Specs for `Regex.Verified` — where the tests become theorems.
|||
||| Everything else in this suite checks examples: finitely many
||| inputs, chosen by us. The proofs in `Regex.Verified` check *all*
||| inputs at once, and their test runner is the type checker: if
||| this module's import compiles, the theorems hold.
|||
||| The one runtime spec below is a marker so the suite output
||| mentions the chapter; the real assertions are compile-time.
module Spec.Verified

import Harness
import Regex.Verified

export
verifiedSpecs : List Spec
verifiedSpecs =
  [ it "nullable is provably sound and complete (checked at compile time)"
      True
  ]
```

そうです，実行時のスペックはただひとつ，`True`を表明します．これはマーカーで，スイートの出力にこの章が現れるようにするためだけのものです．本当のテストはモジュールの2行目，`import Regex.Verified`にあります．このimportがコンパイルできれば，定理は成り立ちます．そしていまはコンパイルできません．それがこの章のredです．

```
Error: Module Regex.Verified not found
```

コンパイルの失敗は，[TDDと小さなテストハーネス](./05-tdd.md)以来ずっと立派なredでした．今回はそれが主役です．

## 「マッチする」の意味を，型として

コミット[74617c0](https://github.com/ubugeeei-prod/lets-start-functional/commit/74617c0af8ca625b65dfa2e275110fb030af27e3)が[`regex/src/Regex/Verified.idr`](https://github.com/ubugeeei-prod/lets-start-functional/blob/main/regex/src/Regex/Verified.idr)を追加します．`nullable`の正しさを証明するには，その前に，`nullable`に言及しない「正しさ」の定義が要ります．つまり「`r`が`cs`にマッチする」とは何を*意味する*のか，という独立した記述です．

```idris
||| Evidence that the regex `r` matches the character list `cs`.
|||
||| Read each constructor as a rule of inference. There is no code
||| here — a value of this type is a *derivation*, like the ones you
||| would draw on paper in a theory course.
public export
data Matches : Regex -> List Char -> Type where
  ||| ε matches the empty string.
  MEps   : Matches Eps []
  ||| A set matches any single member. The `member c s = True`
  ||| argument is itself evidence — a proof obligation, not a Bool
  ||| we promise to have checked.
  MSym   : (c : Char) -> member c s = True -> Matches (Sym s) [c]
  ||| If `l` matches `xs` and `r` matches `ys`, the concatenation
  ||| matches `xs ++ ys`. (The lists are bound explicitly so that
  ||| proofs may inspect them — see the erasure aside in the book.)
  MCat   : {xs, ys : List Char} ->
           Matches l xs -> Matches r ys -> Matches (Cat l r) (xs ++ ys)
  ||| A choice matches whatever its left branch matches...
  MAltL  : Matches l xs -> Matches (Alt l r) xs
  ||| ...or whatever its right branch matches. (`l` kept relevant,
  ||| again for the proofs.)
  MAltR  : {l : Regex} -> Matches r xs -> Matches (Alt l r) xs
  ||| A star matches the empty string (zero repetitions)...
  MStarZ : Matches (Star r) []
  ||| ...or one non-empty repetition followed by more star. The
  ||| non-emptiness (`c ::`) is what keeps derivations finite.
  MStarS : Matches r (c :: xs) -> Matches (Star r) ys ->
           Matches (Star r) (c :: (xs ++ ys))

-- Note what is NOT here: no constructor mentions Fail. `Fail`
-- matches nothing precisely because there is no way to build
-- evidence for it.
```

いきなり見慣れない宣言が出てきましたが，焦らないでください！これは`Regex`自身と同じただの`data`宣言です．違うのは，その型が`Regex -> List Char -> Type`だという点だけです．`Matches r cs`は，正規表現と入力の*ペアごとに異なる型*で，その型の値は，この正規表現がこの入力にマッチすることの**証拠(evidence)**です．各コンストラクタは推論規則として読めます．`MEps`は公理(「εは`[]`にマッチする．前提なし」)です．`MCat`は「`l`が`xs`にマッチする証拠と，`r`が`ys`にマッチする証拠から，`Cat l r`が`xs ++ ys`にマッチすると結論せよ」です．`MCat (MSym 'a' _) (MSym 'b' _)`のような値は導出木(derivation tree)，つまり理論の講義でホワイトボードに描くあれです．ただし，コンパイラが検査してくれます．

立ち止まる価値のある細部がふたつあります．

- **どのコンストラクタも`Fail`に言及しません．**証拠の言葉で「何にもマッチしない」はどう言うのでしょう?何も言わないのです．どんな`cs`に対しても，型`Matches Fail cs`の値を作る方法はまったく存在しません．この型は空で，その空虚さ*こそ*が`Fail`の意味論です．
- **`MStarS`は，最初の繰り返しが空でないことを要求します．**その本体がマッチするのは`c :: xs`であって，決して`[]`ではありません．意味論的には何も失いません(空の繰り返しはスターに何も寄与しません)が，これが導出を有限に保ちます．これがなければ`Star Eps`が`[]`にマッチする導出は無限に存在してしまい，そのどれもが無用な`MStarS`をもう一段ずつ積み増していきます．そうなると，導出についての帰納法は立つべき床を失ってしまいます．

## ふたつのBoolの補題

`nullable`は`&&`と`||`で計算するので，証明にはそれらについての小さな事実がふたつ必要です．

```idris
||| Boolean fact: if `a && b` came out True, both sides are True.
andBoth : {a, b : Bool} -> a && b = True -> (a = True, b = True)
andBoth {a = True}  {b = True}  Refl = (Refl, Refl)
andBoth {a = True}  {b = False} prf  = absurd prf
andBoth {a = False}             prf  = absurd prf

||| Boolean fact: if `a || b` came out True, one side is True.
orEither : {a, b : Bool} -> a || b = True -> Either (a = True) (b = True)
orEither {a = True}  _   = Left Refl
orEither {a = False} prf = Right prf
```

証明のしかたを見てみてください．**その`Bool`が何だったのかへのパターンマッチ**です．`a`と`b`がともに`True`のとき，主張`a && b = True`は`True = True`になります．その唯一の証明は`Refl`で，結論はさらにふたつの`Refl`です．`a`が`True`で`b`が`False`のとき，前提は`False = True`と言っています．これは不合理なので，`absurd prf`がそのありえない証拠を指差してこのケースを退けます．証明専用の言語もタクティクもありません．本書でずっと書いてきたのと同じ場合分けが，命題に適用されているだけです．

## 健全性: nullableのyesは正しい

```idris
||| **Soundness**: when `nullable r` says True, there really is a
||| derivation of `r` matching the empty string.
|||
||| The proof is induction on `r` — which in Idris is just pattern
||| matching and recursion, the same tools we have used all book.
export
nullableSound : (r : Regex) -> nullable r = True -> Matches r []
nullableSound Fail      prf = absurd prf
nullableSound Eps       _   = MEps
nullableSound (Sym s)   prf = absurd prf
nullableSound (Cat l r) prf =
  let (pl, pr) = andBoth prf
  in MCat (nullableSound l pl) (nullableSound r pr)
nullableSound (Alt l r) prf =
  case orEither prf of
    Left  pl => MAltL (nullableSound l pl)
    Right pr => MAltR (nullableSound r pr)
nullableSound (Star r)  _   = MStarZ
```

この型を文として読んでみてください．*すべての正規表現`r`について，`nullable r = True`ならば，`r`が`[]`にマッチする証拠が存在する*，です．関数の本体がその証明です．そして「`r`についての帰納法」の正体は，すでに持っている技術，つまり各コンストラクタへのパターンマッチと部分項への再帰呼び出しだとわかります．`Fail`のケースでは，前提が`nullable Fail = True`すなわち`False = True`を主張しているので`absurd`です．`Cat`のケースでは`andBoth`で`&&`を割り，両半分に再帰します．ちなみに，ここの`MCat`が`[] ++ []`にマッチしていることにも注目してみてください．コンパイラがこれを`[]`へと*計算*してくれるので，補題は不要です．全域性チェッカがこの関数を受理するからこそ，この帰納法は整礎(well-founded)です．部分関数では循環論法になってしまうので，Idrisは拒否します．

## ありえないケースは，述べることすらできない

完全性には，まずリストについての事実が要ります．

```idris
||| List fact: a concatenation is empty only when both halves are.
appendNil : (xs, ys : List a) -> xs ++ ys = [] -> (xs = [], ys = [])
appendNil []        []        _    = (Refl, Refl)
appendNil []        (y :: ys) Refl impossible
appendNil (x :: xs) _         Refl impossible

||| Boolean fact: anything or-ed with True is True.
orTrueRight : (a : Bool) -> a || True = True
orTrueRight True  = Refl
orTrueRight False = Refl
```

キーワード`impossible`が初登場です．新顔ですが怖がらなくて大丈夫です！これは，*述べる*ことすらできない節に印を付けます．2行目では`xs = []`かつ`ys = y :: ys`なので，前提は型`y :: ys = []`を持たねばなりません．しかしconsセルと`[]`は異なるコンストラクタなので，`Refl`がその型を持つことは決してありません．このケースを処理して何かを返しているのではなく，このケースには型の付く左辺がそもそも存在しないことをコンパイラに示し，コンパイラがその主張を検証している，という形です．網羅性検査が，論理そのものが排除するケースにまで拡張された，と言えます．

## 完全性:マッチがあるなら，nullableはyesと言う

```idris
||| **Completeness**: when there is a derivation of `r` matching
||| the empty string, `nullable r` says True.
|||
||| This time the induction is on the *derivation*. The equation
||| argument `cs = []` lets each case learn what the emptiness of
||| the input tells us about its sub-derivations.
export
nullableComplete : Matches r cs -> cs = [] -> nullable r = True
nullableComplete MEps _ = Refl
nullableComplete (MSym c p) Refl impossible
nullableComplete (MCat {xs} {ys} pl pr) prf =
  let (ex, ey) = appendNil xs ys prf
      nl = nullableComplete pl ex
      nr = nullableComplete pr ey
  in rewrite nl in rewrite nr in Refl
nullableComplete (MAltL pl) prf =
  rewrite nullableComplete pl prf in Refl
nullableComplete (MAltR {l} pr) prf =
  rewrite nullableComplete pr prf in orTrueRight (nullable l)
nullableComplete MStarZ _ = Refl
nullableComplete (MStarS p ps) Refl impossible
```

今度の帰納法は*導出*についてです．証拠そのものにパターンマッチします．主張の形にも注目してみてください．`Matches r [] -> ...`ではなく`Matches r cs -> cs = [] -> ...`です．等式を別の引数として渡すのは証明の定石で，こうすると各ケースが物事を*学べる*ようになります．`MCat`のケースでは，入力は`xs ++ ys`で，等式は`xs ++ ys = []`と言っています．`appendNil`がそれを`xs = []`と`ys = []`に変換してくれて，これはふたつの再帰呼び出しが必要とするものそのものです．`MSym`のケースでは入力は`[c]`なので，等式は`[c] = []`になるはずで，これは`impossible`です．`MStarS`も同じで，その入力はconsで始まります．あの非空条件が，ここで働いてくれているわけです．

`rewrite eq in expr`が最後の新しい道具です．等式を使ってゴールを書き換えます．`MCat`のケースのゴールは`nullable l && nullable r = True`です．`nl : nullable l = True`と`nr : nullable r = True`で書き換えると`True && True = True`になり，これは`True = True`へと計算されるので`Refl`です．`MAltR`ではゴールが`nullable l || True = True`になりますが，これは計算では消えて*くれません*(`||`が，未知の`nullable l`のところで詰まっているからです)．なので，`orTrueRight`が場合分けで締めくくります．

## 消去についての余談

`MCat`と`MAltR`はなぜ，暗黙引数(`{xs, ys : List Char}`と`{l : Regex}`)をわざわざ書き出しているのでしょう? Idrisは喜んで推論してくれるのに，です．答えは*消去(erasure)*です．いきなり用語が増えましたが，焦らないでください！Idris 2は，言及されなかったコンストラクタの暗黙引数に数量(quantity)`0`を与えます．それらは型検査のためだけに存在し，実行前に消去されるので，パターンマッチはできません．しかし`nullableComplete (MCat {xs} {ys} pl pr)`は現に`xs`と`ys`を調べます(`appendNil`に渡しています)し，`MAltR`のケースは`orTrueRight (nullable l)`のために`l`を必要とします．コンストラクタで明示的に束縛しておくことで，それらは「関係あり(relevant)」のまま，つまり証明から利用できるままになります．当のコンストラクタのdocコメントはまさにこのことを述べていて，未来の読者は，この風変わりな書き方が構造を支えていることを知れるわけです．証明はプログラムです．消去は，そのふたつの役割が目に見えて折衝する唯一の場所です．

## 手に持てる導出

証拠の型は定理のためだけのものではありません．具体的な導出を手で組むこともできます．

```idris
||| Evidence that `ab` matches "ab": a concatenation of two
||| one-character derivations. The membership proofs are `Refl`
||| because `member 'a' (single 'a')` *computes* to True.
export
exampleAB : Matches (Cat (lit 'a') (lit 'b')) ['a', 'b']
exampleAB = MCat (MSym 'a' Refl) (MSym 'b' Refl)

||| Evidence that `a*` matches "aa": two repetitions, then zero.
export
exampleStar : Matches (Star (lit 'a')) ['a', 'a']
exampleStar = MStarS (MSym 'a' Refl) (MStarS (MSym 'a' Refl) MStarZ)
```

愛おしい細部があります．`MSym`は`member c s = True`の証拠を要求しますが，その証拠はただの`Refl`です．`member 'a' (single 'a')`は閉じた式なので型チェッカが*実行*し，`True`へと計算されるからです．[文字クラス](./11-character-classes.md)で書いた，ふつうの実行可能な`member`関数が，論理の一部としても二重の勤めを果たしているわけです．プログラムと証明はここでは別々の世界ではありません．依存型の眼目は，まさにそれらがひとつの世界だということです．

```sh
make test
```

```
  ...
  ok    nullable is provably sound and complete (checked at compile time)
155/155 passed
```

無限に多くの正規表現についての定理ふたつが，`ok`の1行に収まりました!これほど多くを語りながらこれほど少なく印字したことは，このスイートには一度もありませんでした．

## 範囲について正直に

ここで証明したのは，`Matches`に対する`nullable`の健全性と完全性です．`deriv`について同じことは証明して**いません**．主張を書くのは簡単ですが(`Matches (deriv c r) cs`が成り立つのは，ちょうど`Matches r (c :: cs)`が成り立つとき)，`Star`と`Cat`のケースには素朴な構造よりも繊細な尺度に沿った帰納法が必要で，証明は本当に難しくなります．それが[この先へ](./21-whats-next.md)で待っているボス級の練習問題で，そこで紹介するOwens–Reppy–Turonの論文がその数学を案内してくれます．とはいえ，いま手にあるものはおもちゃではありません．`nullable`はエンジン全体が載っているふたつの関数の片方で，その正しさはいまやコンパイル時の事実です．

## まとめ

- for-allの主張は有限個の例では確立できません．しかしIdrisでは型として書けて，その証明は，その型を持つふつうの全域プログラムです．型チェッカがテストランナーになります．
- `Matches : Regex -> List Char -> Type`は，マッチングを証拠として定義します．各コンストラクタは推論規則で，`Fail`には規則がひとつもなく，`MStarS`の非空な繰り返しが導出を有限に保ちます．
- 証明の技法は，本書のいつもの道具が正装をまとっただけです．帰納法はパターンマッチと再帰，ケースの棄却は`absurd`と`impossible`，残りは`rewrite`と，関数が*計算する*という事実が引き受けます．
- コンストラクタの暗黙引数はデフォルトで消去されます(数量0)．`MCat`と`MAltR`が自分のそれを明示的に束縛しているのは，証明が中身を調べる必要があるからです．
- `exampleAB`と`exampleStar`は手で組んだ導出です．メンバーシップの証明が`Refl`で済むのは，`member`が計算するからです．
- スイートに出るのはマーカーの1行(`155/155 passed`)ですが，本当の表明はコンパイル時に，すべての正規表現にわたって走りました．

理論は語り終えました．次はレースです．[対決:線形時間vsバックトラック](./19-the-race.md)では，本書がずっと警告してきたライバルのエンジンをついに作ります．そして，最初のベンチマークでちょっとした事件が起きます．
