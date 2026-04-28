(* Copyright (c) 2026 Alasdair Armstrong *)
(* SPDX-License-Identifier: BSD-2-Clause *)

open Checkrocq.Lexer

let commands = commands_of_string
let pp_pos p = Printf.sprintf "{%d,%d}" p.line p.col
let pp_span s = Printf.sprintf "%s-%s" (pp_pos s.start) (pp_pos s.stop)

let check_texts label expected input =
  let got = List.map snd (commands input) in
  if got <> expected then (
    Printf.printf "FAIL: %s\n  expected: [%s]\n  got:      [%s]\n" label
      (String.concat "; " (List.map (Printf.sprintf "%S") expected))
      (String.concat "; " (List.map (Printf.sprintf "%S") got));
    exit 1
  )

let check_spans label expected input =
  let got = List.map fst (commands input) in
  if got <> expected then (
    Printf.printf "FAIL: %s\n  expected: [%s]\n  got:      [%s]\n" label
      (String.concat "; " (List.map pp_span expected))
      (String.concat "; " (List.map pp_span got));
    exit 1
  )

let pos l c = { line = l; col = c }
let span sl sc el ec = { start = pos sl sc; stop = pos el ec }

let () =
  (* Text extraction *)
  check_texts "empty" [] "";
  check_texts "single command" ["Theorem foo : True."] "Theorem foo : True. ";
  check_texts "two commands" ["Definition x := 1."; "Definition y := 2."] "Definition x := 1. Definition y := 2. ";
  check_texts "command terminated by newline" ["Lemma bar : False."] "Lemma bar : False.\n";
  check_texts "trailing period without whitespace" ["Definition z := 3."] "Definition z := 3.";
  check_texts "simple comment" ["(* a comment *) Definition a := 1."] "(* a comment *) Definition a := 1.\n";
  check_texts "nested comment"
    ["(* outer (* inner *) *) Definition b := 2."]
    "(* outer (* inner *) *) Definition b := 2.\n";
  check_texts "period inside comment is not a terminator"
    ["(* ends here. not here *) Definition c := 3."]
    "(* ends here. not here *) Definition c := 3.\n";
  check_texts "string with embedded quote" ["Check \"hello \"\" world\"."] "Check \"hello \"\" world\".\n";
  check_texts "period inside string is not a terminator" ["Check \"not. a. terminator\"."]
    "Check \"not. a. terminator\".\n";
  check_texts "multiple commands with comments"
    ["Theorem t : True."; "Proof."; "trivial."; "Qed."]
    "Theorem t : True.\nProof.\ntrivial.\nQed.\n";
  check_texts "whitespace-only input" [] "   \n  ";

  (* Span tracking: lines are 1-indexed, cols are 0-indexed, stop is exclusive *)
  check_spans "single command span"
    (* "Theorem foo : True.\n" - T at col 0, . at col 18, stop = 19 *)
    [span 1 0 1 19]
    "Theorem foo : True.\n";
  check_spans "leading whitespace moves start"
    (* "  Proof.\n" - P at col 2, . at col 7, stop = 8 *)
    [span 1 2 1 8]
    "  Proof.\n";
  check_spans "two commands on separate lines"
    (* "Proof.\ntrivial.\n" *)
    [span 1 0 1 6; span 2 0 2 8]
    "Proof.\ntrivial.\n";
  check_spans "command starts after previous terminator whitespace"
    (* "Proof. trivial.\n" - second command starts at col 7 *)
    [span 1 0 1 6; span 1 7 1 15]
    "Proof. trivial.\n";

  Printf.printf "All tests passed.\n"
