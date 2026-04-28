(lang dune 3.21)

(formatting
 (enabled_for ocaml))

(name checkrocq)

(generate_opam_files true)

(source
 (github username/reponame))

(authors "Author Name <author@example.com>")

(maintainers "Maintainer Name <maintainer@example.com>")

(license LICENSE)

(documentation https://url/to/documentation)

(package
 (name checkrocq)
 (synopsis "A short synopsis")
 (description "A longer description")
 (depends ocaml sedlex)
 (depopts ocamlformat)
 (tags
  ("add topics" "to describe" your project)))

; See the complete stanza docs at https://dune.readthedocs.io/en/stable/reference/dune-project/index.html
