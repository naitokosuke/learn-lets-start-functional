---
title: 環境構築
description: Idris 2をインストールして，REPLにあいさつして，これから組み上げていくリポジトリをひと通り見て回ります．
---

# 環境構築

理論の時間はいったんおしまいです．この章ではIdris 2をインストールして，REPLをつついて，本書全体が住んでいるリポジトリを見て回ります．章の終わりには，手元のマシンで`make test`が走るようになっているはずです．

## Idris 2のインストール

本書はIdris 2のバージョン0.8.0を使います．そこそこ近いバージョンならほぼ確実に動きますが，完全に同じ体験をしたい場合はこの番号を狙ってください．

macOSならHomebrewにあります．

```sh
brew install idris2
```

Nixが使えるOS(Linux，macOS，WSL)なら，nixpkgsのパッケージがよくメンテナンスされています．これが一番スムーズなルートのひとつです．

```sh
nix profile install nixpkgs#idris2
```

UbuntuなどDebian系のLinuxには，メインのアーカイブに公式パッケージがありません．選択肢はコミュニティのPPAか，ソースからのビルドです．ソースビルドはドキュメントも揃っていて，正直そこまで悪くない体験です(Idris 2はChez Scheme経由でブートストラップします．[インストールガイド](https://github.com/idris-lang/Idris2/blob/main/INSTALL.md)に手順があります)．ちなみに，あわせて知っておくと良いのが[pack](https://github.com/stefan-hoeck/idris2-pack)です．多くのIdris開発者が日常的に使っているコミュニティのパッケージマネージャで，コンパイラのインストールもライブラリの管理もできます．本書の後もIdrisを書き続けるつもりなら，エコシステムのツールとして学んでおく価値があります．ただ，本書だけなら必要ありません．このプロジェクトは意図的に，コンパイラ以外の何にも依存しないようにしてあります．

WindowsではWSLを使って，その中でLinuxのルート(Nixが一番摩擦が少ないです)に従ってください．Idris 2の開発はほぼUnix系だけで行われているので，WSLならつまずきどころを一度に回避できます．

どのルートで入れたにせよ，確認しておきましょう．

```sh
$ idris2 --version
Idris 2, version 0.8.0
```

これが表示されれば準備OKです．

## ファーストコンタクト: REPL

IdrisにはREPL(read-eval-print loop)が付いてきます．本書ではずっと付き合っていく相棒なので，いまのうちにあいさつしておきましょう．引数なしで`idris2`を実行します．

```
     ____    __     _         ___
    /  _/___/ /____(_)____   |__ \
    / // __  / ___/ / ___/   __/ /     Version 0.8.0
  _/ // /_/ / /  / (__  )   / __/      https://www.idris-lang.org
 /___/\__,_/_/  /_/____/   /____/      Type :? for help

Welcome to Idris 2.  Enjoy yourself!
Main>
```

プロンプトは`Main> `です．式を評価してくれます．

```repl
Main> 2 + 2
4
```

コロンで始まるコマンドは，コードの評価ではなくREPL自体への指示です．一番よく使うのは`:t`で，式の型を尋ねるコマンドです．

```repl
Main> :t "hello"
fromString "hello" : String
```

コロンの右側が型です．`"hello"`は`String`ということですね．(左側の`fromString`はIdrisが途中経過を見せているだけです．Haskellと同じく文字列リテラルはオーバーロード可能なのですが，いまは無視してOKです．)

さて，ここで大きな教訓を含んだ小さな驚きをひとつ．何かを表示しようとしてみてください．

```repl
Main> putStrLn "hello"
Error: Can't find an implementation for HasIO ?io.

(Interactive):1:1--1:17
 1 | putStrLn "hello"
     ^^^^^^^^^^^^^^^^
```

REPLは式を評価するのであって，実行するのではありません．`putStrLn "hello"`は表示された文字列ではなく，アクションの記述です．(このエラーは，どの種類の実行コンテキストを意図したのかREPLが推測できなかった，というものです．「作用を記述すること」と「作用を実行すること」の区別は，後でちゃんと掘り下げるテーマです．)実際にアクションを実行するには`:exec`で頼みます．

```repl
Main> :exec putStrLn "hello"
hello
```

そして抜けるにはこうです．

```repl
Main> :q
Bye for now!
```

これでREPLサバイバルキットは全部です．打ち込めば評価，`:t`で型，`:exec`でアクションの実行，`:q`で終了．[速習コース](./04-idris-crash-course.md)でもう少し小技を足しますが，この4つでかなり遠くまで行けます．

## エディタ

エディタは何でも問題ないです．本書が要求するのは「ファイルを編集して`make test`を実行する」以上のことではありません．とはいえ，Idrisには言語サーバ[idris2-lsp](https://github.com/idris-community/idris2-lsp)があり，VS Codeに*idris2-lsp*拡張を入れるとホバーで型が見え，書きながらエラーが出て，ホールを対話的に調べられます．packをインストールした場合は`pack install-app idris2-lsp`でサーバが入ります．そうでなければ，手元のコンパイラのバージョンに合わせてソースからビルドされます．あると嬉しいですが，本当に必須ではありません．言語サーバが見せてくれるものはすべてREPLとコンパイラも教えてくれますし，本書が前提にするのは後者だけです．

## リポジトリ

まだの場合はクローンしておきましょう．

```sh
git clone https://github.com/ubugeeei-prod/lets-start-functional.git
cd lets-start-functional
```

作るものはすべて`regex/`の下にあります．形はこんな感じです．これは完成した状態，つまり本書の最後の時点のコードです．

```
regex/
├── regex.ipkg          the library package
├── Makefile            build / test / repl / bench targets
├── src/
│   ├── Regex.idr       the public API, the library's front door
│   └── Regex/
│       ├── Core.idr    the AST, nullable, deriv, matches
│       ├── Set.idr     character sets
│       ├── Sugar.idr   plus, opt, literal, {n,m}
│       ├── Parse.idr   parser combinators
│       ├── Syntax.idr  the pattern parser
│       ├── Pretty.idr  printing patterns back out
│       ├── Naive.idr   a backtracker, built to lose the race
│       ├── Verified.idr  the proof chapter
│       └── Lex.idr     the capstone lexer
├── tests/
│   ├── tests.ipkg      the test package
│   └── src/
│       ├── Main.idr    entry point: concatenate the spec lists
│       ├── Harness.idr the tiny test harness (next chapter!)
│       └── Spec/       one spec module per feature
└── bench/              the race from the second-to-last chapter
```

完成形にソースモジュールが10個あるからといって，身構えないでください！コミット履歴こそが本書です．最初のコードコミットの時点では，`src/`にはほぼ空のファイルが1つあるだけです．これを全部，これから自分の手で書いていきます．

### パッケージファイルを1フィールドずつ

Idrisのプロジェクトは`.ipkg`ファイルで記述します．[regex/regex.ipkg](https://github.com/ubugeeei-prod/lets-start-functional/blob/main/regex/regex.ipkg)の全文はこちらです．

```ipkg
package regex
version = 0.1.0
authors = "ubugeeei"
license = "MIT"
brief = "A linear-time regular expression engine, built test-first"

sourcedir = "src"

modules = Regex
        , Regex.Core
        , Regex.Set
        , Regex.Sugar
        , Regex.Parse
        , Regex.Syntax
        , Regex.Pretty
        , Regex.Naive
        , Regex.Verified
        , Regex.Lex
```

`package regex`はパッケージの名前です．他のパッケージが依存するときに使う名前になります．`version`，`authors`，`license`，`brief`は見た目どおりのメタデータです．`sourcedir = "src"`はソースファイルの置き場所を示し，`modules`はパッケージ内の全モジュールの一覧です．モジュール`Regex.Core`はファイル`src/Regex/Core.idr`に対応します(ドットがディレクトリ区切りに写る，という感じです)．プロジェクトにモジュールを足すとき(何度もやります)の儀式はいつも同じで，ファイルを作って，ここに1行足すだけです．(上の一覧は完成形です．最初は`Regex.Core`だけから始まります．)

パッケージファイルはもうひとつあります．テストスイートを記述する[tests/tests.ipkg](https://github.com/ubugeeei-prod/lets-start-functional/blob/main/regex/tests/tests.ipkg)です．こちらはライブラリ側にはないフィールドを持っていて，パッケージを実行可能なプログラムに変える`main = Main`と`executable = tests`，そしてテストがライブラリを使うことを示す`depends = regex`です．次の章で1行ずつ読むので，詳細はそこまで取っておきます．

### Makefile

[Makefile](https://github.com/ubugeeei-prod/lets-start-functional/blob/main/regex/Makefile)が2つのパッケージをつなぎます．

```
.PHONY: build install test repl clean

## Build the library.
build:
	idris2 --build regex.ipkg

## Make the library visible to the test package.
##
## Idris 2 looks for packages in a `depends/` directory next to the
## package being built, so we copy the compiled modules there. This
## works with any Idris installation (no writable global prefix needed).
install: build
	rm -rf tests/depends/regex-0.1.0
	mkdir -p tests/depends/regex-0.1.0
	cp -R build/ttc/* tests/depends/regex-0.1.0/
	printf 'package regex\nversion = 0.1.0\n' > tests/depends/regex-0.1.0/regex.ipkg

## Build and run the whole test suite.
test: install
	idris2 --build tests/tests.ipkg
	./tests/build/exec/tests

## Open a REPL with the library loaded.
repl:
	idris2 --repl regex.ipkg

## Race the derivative engine against the backtracker.
bench: install
	rm -rf bench/depends
	cp -R tests/depends bench/depends
	idris2 --build bench/bench.ipkg
	./bench/build/exec/bench

clean:
	rm -rf build tests/build tests/depends bench/build bench/depends
```

`build`はライブラリをコンパイルします．`test`はこれから何百回も打つことになるターゲットで，ライブラリを再ビルドし，依存を更新し，テストパッケージをコンパイルして実行します．`repl`は自作ライブラリのモジュールを読み込める状態でREPLを開きます(エンジンを対話的につつくのに重宝します)．`bench`はずっと後の[対決](./19-the-race.md)用です．

`install`ターゲットには正直な説明が必要かと思います．ハックに見えますが，実は意図的な選択です．テストは`depends = regex`を宣言しているので，Idrisはコンパイル済みの`regex`パッケージをどこかで見つける必要があります．標準的な答えはグローバルなパッケージディレクトリですが，それはIdrisのインストール先に書き込めることが前提で，Nixでは成り立ちませんし，CIでは面倒ですし，だいたいマシンごとの冒険になってしまいます．幸い，Idris 2はビルド対象の`.ipkg`の隣にある`depends/`ディレクトリからもパッケージを探してくれます．なので`install`は，ライブラリのコンパイル済みモジュール(`build/ttc/`の出力です．TTCはIdrisのコンパイル済みモジュール形式)を，最小限の2行の`.ipkg`と一緒に`tests/depends/regex-0.1.0/`へコピーするだけです．テストのビルドに必要なものはすべて，プロジェクトからの相対位置で見つかります．グローバルな状態なし，権限も不要，どこでも同じように動く．種も仕掛けもこれだけです．

### 動かしてみる

さて，いよいよ本番です．

```sh
cd regex
make test
```

初回はすべてコンパイルするので1分ほどかかります．出力はこんな感じになります(抜粋です．本書の最後の時点で，スイートには167本のスペックがあります)．

```
idris2 --build regex.ipkg
 1/10: Building Regex.Set (src/Regex/Set.idr)
 2/10: Building Regex.Core (src/Regex/Core.idr)
...
10/10: Building Regex (src/Regex.idr)
rm -rf tests/depends/regex-0.1.0
mkdir -p tests/depends/regex-0.1.0
cp -R build/ttc/* tests/depends/regex-0.1.0/
printf 'package regex\nversion = 0.1.0\n' > tests/depends/regex-0.1.0/regex.ipkg
idris2 --build tests/tests.ipkg
 1/12: Building Harness (src/Harness.idr)
...
12/12: Building Main (src/Main.idr)
Now compiling the executable: tests
./tests/build/exec/tests
  ok    true is true
  ok    one plus one is two
  ok    strings concatenate
  ok    a single-character set contains its character
...
  ok    the empty input is an empty token list
  ok    dropping whitespace is a List problem, not a lexer problem
167/167 passed
```

この出力はどの行も，これから自分で書くものです．先頭の`true is true`は次の章で書く最初のサニティチェックで，末尾の`dropping whitespace is a List problem, not a lexer problem`は総仕上げのレキサです．`167/167 passed`が見えたら，マシンの準備は万端です！

> [!TIP]
> コミットを1つずつたどりたい場合は，`git log --oneline --reverse`でred/greenの履歴全体が読む順に表示されます．`git checkout <sha>`で任意のステップに作業ツリーを移せますが，`git checkout main`で戻ってくるのだけ忘れないでください．

## まとめ

- 本書が対象とするのはIdris 2のバージョン0.8.0です．macOSは`brew install idris2`，Nixが動く環境なら`nix profile install nixpkgs#idris2`，UbuntuはPPAかソースビルド，WindowsはWSLで，`idris2 --version`で確認します．
- REPLサバイバルキットはこうです．式を打てば評価，`:t`で型，`:exec`でアクションの実行，`:q`で終了．
- VS Code + idris2-lspは良いアップグレードですが，本書に必要なのはエディタと`make test`だけです．
- プロジェクトは2つのIdrisパッケージ(`regex`ライブラリとそのテストスイート)で，それぞれ`.ipkg`ファイルで記述されます．`modules`の一覧は本書が進むにつれて育っていきます．
- Makefileの`depends/`トリックはコンパイル済みモジュールをテストパッケージの隣にコピーします．書き込み可能なグローバルパッケージディレクトリが一切不要になるので，NixやCIとも相性が良いです．
- リポジトリの最終状態で`make test`を実行するとすべてがビルドされ，`167/167 passed`と報告されます．この1行1行を，これから自分の手で獲得していきます．

次は約束していた速習コースです．この先のすべての章を読むのに十分なIdrisを，[Idris速習](./04-idris-crash-course.md)で身につけましょう．
