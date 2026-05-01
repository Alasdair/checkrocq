---
name: check-rocq
description: Use when authoring or debugging Rocq proofs, or when a Rocq file fails to build.
---

When working on Rocq proofs, use the `checkrocq` command to understand
proof state and errors, or to find usable lemmas.

## Usage

```bash
checkrocq <path/to/file.v>
```

The command:

1. Runs `dune rocq top` to load the file into a Rocq REPL
2. Loads the file into the REPL incrementally to discover the first error
3. If there is an error it exits with exit code 1, and outputs:
   - **Last goal state** — the last proof goal (hypotheses + conclusion)
   - **Command** - the last command passed to Rocq.
   - **Error** — the `Error:` message produced by Rocq when running the last command.

If the there are no errors, the command just exits with code 0.

## Searching for useful lemmas

The command also allows searching for useful lemmas. When used to
search for lemmas the tool will not print anything other than the
search results, and will always exit with code 0.

The output of the search commands will be printed to stdout, while any
errors from them will go to stderr.

All the following flags can be passed multiple times. Each command
they generate will be run sequentially in order.

Strongly prefer using these commands over grep or other command line
tools to search for Lemmas.

### Searching for patterns

The flag `--search <pat>` uses the Rocq `Search` command to search for
a pattern, which can be just a name. For example:

```
--search "foo"
```
will invoke `Search foo`, searching for all lemmas involving foo in their type.

Wildcards and metavariables can be used, so:
```
--pattern "?x + ?x"
```
will invoke the Search command:
```
Search (?x + ?x).
```

### Searching for names

The flag `--name <name>` uses the Rocq `Search` command to search
for a lemmas or definitions whose name contains a string. For example:
```
--name mod
```
will invoke the Search command:
```
Search "mod".
```
This will find any lemma or command containing `mod`, so it would find a
name like `divmod_prop`.

## Running arbitrary Rocq commands.

The `--command <cmd>` flag allows an arbitrary Rocq command to be ran
at the point in the file where the first error has occurred. This can
be used to run more sophisticated search queries, or other commands.

For example:
```
--command "Search foo concl:(_ + _)."
```
will Search for all lemmas where the type contains foo and the
conclusion matches the pattern.

## Workflow for proof authoring

Start by runing `checkrocq` to understand the current proof state, then:

1. Write or modify tactics in the `.v` file
2. Run `checkrocq` on the file
3. Read the goal state to understand what remains to be proved
4. Read the first error to understand what went wrong
5. Adjust tactics and repeat

## Best practices for proof authoring

Don't try to complete the entire proof in one go. Start with a
high-level skeleton, including any required or useful helper lemmas.
Use `admit` (or `Admitted.` for lemmas) to skip lower-level proof
steps, then use the checkrocq command to refine the proof until all
the admitted steps are gone. You can replace the `admit` steps with
`fail` to turn them into failing steps that `checkrocq` will report
the goal state for.
