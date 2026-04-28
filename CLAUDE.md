# checkrocq

A CLI tool for interacting with Rocq proof scripts.

## Build & test

```
dune build
dune test
dune fmt      # format all OCaml files
```

## Structure

- `lib/lexer.ml` — sedlex lexer that splits Rocq source into commands (`(span * string) list`)
- `lib/repl.ml` — manages a `dune rocq top` subprocess (start/stop/send_command)
- `bin/main.ml` — CLI entry point
- `test/test_checkrocq.ml` — unit tests for the lexer
