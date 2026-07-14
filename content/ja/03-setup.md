---
title: 環境構築
description: Idris 2 をインストールし、REPL にあいさつし、これから組み上げていくリポジトリをガイド付きで見て回ります。
---

# 環境構築

理論の時間はいったんおしまいです。この章では Idris 2 をインストールし、REPL をつつき、本書全体が暮らしているリポジトリを歩いて回ります。章の終わりには、あなたのマシンで `make test` が走るようになっています。

## Idris 2 のインストール

本書は Idris 2 のバージョン 0.8.0 を使います。そこそこ近いバージョンならほぼ確実に動きますが、完全に同一の体験を保証したいなら、この番号を狙ってください。

macOS なら Homebrew にあります。

```sh
brew install idris2
```

Nix が動く OS(Linux、macOS、WSL)なら、nixpkgs のパッケージがよく整備されています——これは最もスムーズな経路のひとつです。

```sh
nix profile install nixpkgs#idris2
```

Ubuntu をはじめとする Debian 系の Linux には、メインのアーカイブに公式パッケージがありません。選択肢はコミュニティの PPA か、ソースからのビルドです。後者は手順が文書化されていて、正直なところ悪くない体験です(Idris 2 は Chez Scheme を介してブートストラップします——[インストールガイド](https://github.com/idris-lang/Idris2/blob/main/INSTALL.md)が案内してくれます)。あわせて知っておく価値があるのが [pack](https://github.com/stefan-hoeck/idris2-pack)。多くの Idris 開発者が日常的に使っているコミュニティ製のパッケージマネージャです。コンパイラのインストール*と*ライブラリの管理の両方をこなすので、本書のあとも Idris を書き続けるつもりなら、エコシステムのツールとして学んでおく価値があります。ただし本書のためだけなら不要です——このプロジェクトは意図的に、コンパイラ以外の何にも依存しません。

Windows では WSL を使い、その中で Linux の経路に従ってください(Nix の経路がいちばん摩擦が少ないです)。Idris 2 の開発はほぼすべて Unix 系の上で行われており、WSL はあらゆる荒れた角をまとめて回避してくれます。

どの経路で入れたにせよ、確認を。

```sh
$ idris2 --version
Idris 2, version 0.8.0
```

これが表示されれば準備完了です。

## ファーストコンタクト:REPL

Idris には REPL——read-eval-print loop——が付属していて、これからずっと私たちの相棒になるので、いま握手を交わしておきましょう。引数なしで `idris2` を実行します。

```
     ____    __     _         ___
    /  _/___/ /____(_)____   |__ \
    / // __  / ___/ / ___/   __/ /     Version 0.8.0
  _/ // /_/ / /  / (__  )   / __/      https://www.idris-lang.org
 /___/\__,_/_/  /_/____/   /____/      Type :? for help

Welcome to Idris 2.  Enjoy yourself!
Main>
```

プロンプトは `Main> ` です。式を評価してくれます。

```
Main> 2 + 2
4
```

コロンで始まるコマンドは、コードの評価ではなく REPL 自体への指示です。あなたが使い倒すことになるのが `:t`、式の型を尋ねるコマンドです。

```
Main> :t "hello"
fromString "hello" : String
```

型はコロンの右側です。`"hello"` は `String`。(左側の `fromString` は Idris が途中の仕事を見せているだけです——文字列リテラルは Haskell と同じくオーバーロード可能なのです——無視してかまいません。)

さて、大きな教訓をくれる小さなサプライズです。何かを表示させてみましょう。

```
Main> putStrLn "hello"
Error: Can't find an implementation for HasIO ?io.

(Interactive):1:1--1:17
 1 | putStrLn "hello"
     ^^^^^^^^^^^^^^^^
```

REPL は式を*評価*しますが、*実行*はしません。そして `putStrLn "hello"` は表示された文字列ではなく——アクションの記述なのです。(このエラーは、どの種類の実行可能コンテキストのつもりなのか REPL が推測しかねた、というものです。作用を記述することと実行することの区別は、のちほどきちんと掘り下げるテーマです。)実際にアクションを実行するには、`:exec` で頼みます。

```
Main> :exec putStrLn "hello"
hello
```

そして帰り道はこちら。

```
Main> :q
Bye for now!
```

これが REPL サバイバルキットの全部です。式を打てば評価、`:t` で型、`:exec` でアクションの実行、`:q` で退出。[速習コース](./04-idris-crash-course.md)で小技がいくつか増えますが、この 4 つでかなり遠くまで行けます。

## エディタ

エディタは何でもかまいません——本書が要求するのは「ファイルを編集して `make test` を実行」以上のことではありません。とはいえ Idris には言語サーバー [idris2-lsp](https://github.com/idris-community/idris2-lsp) があり、VS Code に *idris2-lsp* 拡張を入れれば、ホバーで型表示、書いたそばからエラー表示、対話的なホールの調査が手に入ります。pack を入れたなら `pack install-app idris2-lsp` でサーバーが入ります。そうでなければ、手元のコンパイラのバージョンに合わせてソースからビルドされます。あるとうれしい、でも本当に必須ではない——言語サーバーが見せてくれるものはすべて REPL とコンパイラも教えてくれますし、本書が前提にするのは後者だけです。

## リポジトリ

まだであれば、こちらを。

```sh
git clone https://github.com/ubugeeei-prod/lets-start-functional.git
cd lets-start-functional
```

私たちが作るものはすべて `regex/` の下にあります。その形がこちら——これは*完成*状態、本書の最後の時点でのコードです。

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

完成品にソースモジュールが 10 個あるからといって、ひるまないでください——思い出しましょう、コミット履歴こそが本書です。最初のコードコミットの時点では、`src/` にはほぼ空のファイルが 1 個あるだけ。この全部を、あなたが書くのです。

### パッケージファイルを、1 フィールドずつ

Idris のプロジェクトは `.ipkg` ファイルで記述されます。こちらが [regex/regex.ipkg](https://github.com/ubugeeei-prod/lets-start-functional/blob/main/regex/regex.ipkg) の全文です。

```
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

`package regex` はパッケージの名前を決めます——他のパッケージが依存するときに使う名前です。`version`、`authors`、`license`、`brief` はメタデータで、見た目どおりのもの。`sourcedir = "src"` はソースファイルの置き場所を指定し、`modules` はパッケージ内の全モジュールを列挙します。モジュール `Regex.Core` はファイル `src/Regex/Core.idr` に対応し、ドットがディレクトリの区切りに写ります。プロジェクトにモジュールを追加するとき——これから何度もやります——の儀式はいつも同じです。ファイルを作り、ここに 1 行足す。(上のリストは完成状態です。最初は `Regex.Core` だけから始まります。)

パッケージファイルはもう 1 つあります。テストスイートを記述する [tests/tests.ipkg](https://github.com/ubugeeei-prod/lets-start-functional/blob/main/regex/tests/tests.ipkg) です。こちらにはライブラリ側にないフィールドが 2 種類あります。パッケージを実行可能なプログラムに変える `main = Main` と `executable = tests`、そしてテストがライブラリを使うことを表す `depends = regex` です。次の章で 1 行ずつ読むので、それまで取っておきましょう。

### Makefile

[Makefile](https://github.com/ubugeeei-prod/lets-start-functional/blob/main/regex/Makefile) が 2 つのパッケージを配線します。

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

`build` はライブラリをコンパイルします。`test` はあなたが何百回も打つことになるコマンドです。ライブラリを再ビルドし、依存関係を更新し、テストパッケージをコンパイルして、実行します。`repl` は私たちのライブラリのモジュールを読み込める状態で REPL を開きます——エンジンを対話的につつくのに重宝します。`bench` はずっと後の[対決](./19-the-race.md)のためのものです。

`install` ターゲットには正直な説明が要るでしょう。ハックに見えて、実は意図的な選択だからです。テストは `depends = regex` を宣言しているので、Idris はコンパイル済みの `regex` パッケージをどこかで*見つける*必要があります。標準的な答えはグローバルなパッケージディレクトリですが、それは Idris のインストール先に書き込めることが前提で、Nix では成り立たず、CI では厄介で、だいたいにおいてマシンごとの冒険になります。幸い、Idris 2 はビルド対象の `.ipkg` の隣にある `depends/` ディレクトリからもパッケージを探してくれます。そこで `install` は、ライブラリのコンパイル済みモジュール(`build/ttc/` の出力——TTC は Idris のコンパイル済みモジュール形式です)を、最小限の 2 行の `.ipkg` と一緒に `tests/depends/regex-0.1.0/` へコピーするだけ。テストのビルドは、必要なものすべてをプロジェクトからの相対位置で見つけられます。グローバルな状態なし、権限も不要、どこでも同じように動く。トリックはこれで全部です。

### 動かしてみる

いよいよ運命の瞬間です。

```sh
cd regex
make test
```

初回はすべてをコンパイルするので、1 分ほどかかります。出力はこんな具合です(途中は省略しています——本書の最後の時点のスイートには 167 個のスペックがあります)。

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

この出力の 1 行 1 行が、本書があなたに交わす約束の、前払いでの履行です。先頭の `true is true` は、次の章で書く最初のサニティチェック。末尾の `dropping whitespace is a List problem, not a lexer problem` は、総仕上げのレキサです。`167/167 passed` が見えたなら、あなたのマシンはこのすべてを迎える準備ができています。

> [!TIP]
> コミットを 1 つずつたどりながら読みたい人へ。`git log --oneline --reverse` が red/green の履歴全体を読む順に表示してくれますし、`git checkout <sha>` で作業ツリーを任意のステップに合わせられます。`git checkout main` で戻ってくるのだけお忘れなく。

## まとめ

- 本書のターゲットは Idris 2 バージョン 0.8.0 です。macOS は `brew install idris2`、Nix が動く場所ならどこでも `nix profile install nixpkgs#idris2`、Ubuntu はソースか PPA、Windows は WSL——`idris2 --version` で確認します。
- REPL サバイバルキット:式を打てば評価、`:t` で型、`:exec` でアクションを実際に実行、`:q` で退出。
- VS Code + idris2-lsp はうれしいアップグレードですが、本書がエディタと `make test` 以上を求めることはありません。
- プロジェクトは 2 つの Idris パッケージ——`regex` ライブラリとそのテストスイート——で、`.ipkg` ファイルに記述され、その `modules` リストは本書が進むにつれて育ちます。
- Makefile の `depends/` トリックはコンパイル済みモジュールをテストパッケージの隣にコピーします。書き込み可能なグローバルパッケージディレクトリは一切不要——Nix にも CI にも優しい仕掛けです。
- リポジトリの最終状態で `make test` はすべてをビルドし、`167/167 passed` と報告します。その 1 行 1 行を、あなたはこれから自分の手で稼いでいきます。

次は約束していた速習コースです。この先のすべての章を読むのに十分な Idris を、[Idris 速習](./04-idris-crash-course.md)で。
