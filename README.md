# Checkrocq

This is a simple helper tool that assists LLMs in writing and debugging Rocq proofs.

How it works is:
```
checkrocq path/to/Theory.v
```
will invoke `dune rocq top path/to/Theory.v`. It then feeds each Rocq
command from the file into the toplevel one by one until encountering
an Error. At that point it stops, and reports both the error and the
last goal state.

Example output (after removing the final proof step from a working file to demonstrate):
```
Last goal state:
1 goal

  n : N
  x, y : bv n
  Hsub : (x - y)%bv = (x + - y)%bv
  ============================
  add (α x) (negate (α y)) = add (α x) (negate (α y))

Command:
Qed.

Error at line 1031, character 2:
Error:  (in proof sub_abst): Attempt to save an incomplete proof
(there are remaining open goals).
```

There is also a feature to allow the LLM to search for usable lemmas
at that point in the file, using either the `--pattern` or `--search`
flags. Both of which invoke the Rocq `Search` command at that point in
the file:

* `--pattern <pat>`: Invokes `Search (<pat>).`
* `--search <pat>`: Invokes `Search "<pat>".`

## Install

Run `dune build` then `dune install`.

## Limitations

This command started as a bash script that would just pipe the file
into the REPL and grep for errors. In order to make the output parsing
more robust it now tries pass each command into the Repl one by one.
This involves Lexing the Rocq file to separate each `.` terminated
command. This lexer handles comments and strings, so strings and
comments with `.` inside them won't confuse it, but there is no
guarantee that the lexer covers all possible Rocq source.

It uses `dune rocq top`, so it assumes the Rocq sources are being
built by dune rather than with a _RocqProject file.

## Alternative approaches

A more robust approach would be a proper MCP server like
[rocq-mcp](https://github.com/LLM4Rocq/rocq-mcp). However this
approach does have the benefit of being quite simple and having zero
runtime dependencies other than dune and Rocq itself.
