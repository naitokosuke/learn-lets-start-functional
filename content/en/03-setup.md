---
title: Setting Up
description: Install Idris 2, say hello to the REPL, and take a guided tour of the repository you will be building.
---

# Setting Up

Theory time is over for a moment: in this chapter you install Idris 2, poke at its REPL, and walk through the repository this whole book lives in. By the end, `make test` runs on your machine.

## Installing Idris 2

The book uses Idris 2 version 0.8.0. Anything reasonably close will almost certainly work, but if you want a guaranteed-identical experience, that is the number to aim for.

On macOS, Homebrew has it:

```sh
brew install idris2
```

On any OS with Nix (Linux, macOS, WSL), the nixpkgs package is well maintained — this is one of the smoothest routes:

```sh
nix profile install nixpkgs#idris2
```

On Ubuntu and other Debian-flavored Linux there is no official package in the main archives; your options are a community PPA or building from source, which is a documented and honestly not-bad experience (Idris 2 bootstraps via Chez Scheme — the [install guide](https://github.com/idris-lang/Idris2/blob/main/INSTALL.md) walks through it). Also worth knowing about: [pack](https://github.com/stefan-hoeck/idris2-pack), the community package manager that many Idris developers use day to day. It can install the compiler *and* manage libraries, and if you plan to keep writing Idris after this book, it is the ecosystem tool to learn. For this book alone you will not need it — our project deliberately depends on nothing but the compiler.

On Windows, use WSL and then follow the Linux route inside it (the Nix one is the least friction). Idris 2 development happens almost entirely on Unix-likes, and WSL sidesteps every rough edge at once.

However you got it, verify:

```sh
$ idris2 --version
Idris 2, version 0.8.0
```

If that prints, you are in business.

## First contact: the REPL

Idris comes with a REPL — a read-eval-print loop — and it will be our constant companion, so let us shake hands with it now. Run `idris2` with no arguments:

```
     ____    __     _         ___
    /  _/___/ /____(_)____   |__ \
    / // __  / ___/ / ___/   __/ /     Version 0.8.0
  _/ // /_/ / /  / (__  )   / __/      https://www.idris-lang.org
 /___/\__,_/_/  /_/____/   /____/      Type :? for help

Welcome to Idris 2.  Enjoy yourself!
Main>
```

The prompt is `Main> `. It evaluates expressions:

```repl
Main> 2 + 2
4
```

Commands starting with a colon talk to the REPL itself rather than evaluating code. The one you will use constantly is `:t`, which asks for the type of an expression:

```repl
Main> :t "hello"
fromString "hello" : String
```

Type on the right of the colon: `"hello"` is a `String`. (The `fromString` on the left is Idris showing its work — string literals are overloadable, like in Haskell — and you can ignore it.)

Now a small surprise that teaches a big lesson. Try to print something:

```repl
Main> putStrLn "hello"
Error: Can't find an implementation for HasIO ?io.

(Interactive):1:1--1:17
 1 | putStrLn "hello"
     ^^^^^^^^^^^^^^^^
```

The REPL *evaluates* expressions; it does not *run* them, and `putStrLn "hello"` is not a string that got printed — it is a description of an action. (The error is the REPL failing to guess which flavor of runnable context you meant; the distinction between describing an effect and performing one is a theme we will develop properly later.) To actually perform an action, ask with `:exec`:

```repl
Main> :exec putStrLn "hello"
hello
```

And to leave:

```repl
Main> :q
Bye for now!
```

That is the entire REPL survival kit: evaluate by typing, `:t` for types, `:exec` to run actions, `:q` to quit. The [crash course](./04-idris-crash-course.md) adds a few more tricks, but these four carry you a long way.

## An editor

Any editor works — this book never requires more than "edit file, run `make test`". That said, Idris has a language server, [idris2-lsp](https://github.com/idris-community/idris2-lsp), and VS Code with the *idris2-lsp* extension gives you types on hover, errors as you type, and interactive hole inspection. If you installed pack, `pack install-app idris2-lsp` gets you the server; otherwise it builds from source against your compiler version. Nice to have, genuinely not required — everything the language server shows you, the REPL and compiler will also tell you, and the book only ever assumes the latter.

## The repository

If you have not already:

```sh
git clone https://github.com/ubugeeei-prod/lets-start-functional.git
cd lets-start-functional
```

Everything we build lives under `regex/`. Here is the shape of it — this is the *finished* state, the code as it stands at the end of the book:

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

Do not be alarmed that the finished thing has ten source modules — remember, the commit history is the book, and at the first code commit `src/` contains exactly one nearly-empty file. You will write all of this.

### The package file, field by field

Idris projects are described by `.ipkg` files. Here is [regex/regex.ipkg](https://github.com/ubugeeei-prod/lets-start-functional/blob/main/regex/regex.ipkg), in full:

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

`package regex` names the package — this is the name other packages will use to depend on it. `version`, `authors`, `license`, and `brief` are metadata, exactly what they look like. `sourcedir = "src"` says where source files live, and `modules` lists every module in the package: module `Regex.Core` corresponds to the file `src/Regex/Core.idr`, dots mapping to directory separators. When we add a module to the project — which we will do many times — the ritual is always the same: create the file, add one line here. (The list above is the finished state; it starts life as just `Regex.Core`.)

There is a second package file, [tests/tests.ipkg](https://github.com/ubugeeei-prod/lets-start-functional/blob/main/regex/tests/tests.ipkg), which describes the test suite. It has two fields the library does not: `main = Main` and `executable = tests`, which turn the package into a runnable program, and `depends = regex`, which says the tests use the library. The next chapter reads it line by line, so we will leave it until then.

### The Makefile

The [Makefile](https://github.com/ubugeeei-prod/lets-start-functional/blob/main/regex/Makefile) wires the two packages together:

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

`build` compiles the library. `test` is the one you will type hundreds of times: it rebuilds the library, refreshes the dependency, compiles the test package, and runs it. `repl` opens the REPL with our library's modules loadable — invaluable for poking at the engine interactively. `bench` belongs to [The Race](./19-the-race.md), much later.

The `install` target deserves an honest explanation, because it looks like a hack and is in fact a deliberate choice. The tests declare `depends = regex`, so Idris needs to *find* the compiled `regex` package somewhere. The standard answer is a global package directory — but that assumes you can write to wherever Idris is installed, which is false on Nix, awkward in CI, and generally a per-machine adventure. Fortunately Idris 2 also looks for packages in a `depends/` directory sitting next to the `.ipkg` being built. So `install` simply copies the library's compiled modules (the `build/ttc/` output — TTC is Idris's compiled-module format) into `tests/depends/regex-0.1.0/` along with a minimal two-line `.ipkg`, and the test build finds everything it needs relative to the project. No global state, no permissions, works identically everywhere. That is the whole trick.

### Run it

The moment of truth:

```sh
cd regex
make test
```

The first run compiles everything, so it takes a minute. It looks like this (trimmed — the suite at the end of the book has 167 specs):

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

Every line of that output is a promise this book makes to you, kept in advance. `true is true` at the top is the very first sanity check we write in the next chapter; `dropping whitespace is a List problem, not a lexer problem` at the bottom is the capstone lexer. If you see `167/167 passed`, your machine is ready for all of it.

> [!TIP]
> If you want to follow along commit by commit, `git log --oneline --reverse` shows the whole red/green history in reading order, and `git checkout <sha>` puts the working tree at any step. Just remember to come back with `git checkout main`.

## Summary

- The book targets Idris 2 version 0.8.0: `brew install idris2` on macOS, `nix profile install nixpkgs#idris2` anywhere Nix runs, source or PPA on Ubuntu, WSL on Windows — verify with `idris2 --version`.
- The REPL survival kit: type an expression to evaluate it, `:t` for its type, `:exec` to actually run an action, `:q` to leave.
- VS Code with idris2-lsp is a nice upgrade, but the book never requires more than an editor and `make test`.
- The project is two Idris packages — the `regex` library and its test suite — described by `.ipkg` files whose `modules` list grows as the book proceeds.
- The Makefile's `depends/` trick copies compiled modules next to the test package, so no writable global package directory is ever needed — friendly to Nix and CI.
- `make test` at the repository's final state builds everything and reports `167/167 passed`; you will earn every one of those lines.

Next, the promised crash course: enough Idris to read every chapter that follows, in [An Idris Crash Course](./04-idris-crash-course.md).
