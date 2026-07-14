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

clean:
	rm -rf build tests/build
