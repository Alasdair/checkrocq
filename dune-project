(lang dune 3.21)

(formatting
 (enabled_for ocaml))

(name checkrocq)

(generate_opam_files true)

(source
 (github username/reponame))

(authors "Alasdair Armstrong <alasdair.armstrong@cl.cam.ac.uk>")

(maintainers "Alasdair Armstrong <alasdair.armstrong@cl.cam.ac.uk>")

(license LICENSE)

(package
 (name checkrocq)
 (synopsis "A short synopsis")
 (description "A longer description")
 (depends ocaml sedlex)
 (depopts ocamlformat))
