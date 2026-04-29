(* Copyright (c) 2026 Alasdair Armstrong *)
(* SPDX-License-Identifier: BSD-2-Clause *)

type pos = { line : int; col : int }
type span = { start : pos; stop : pos }

exception Lexer_error of string

let commands_of_string source =
  let buf = Sedlexing.Utf8.from_string source in
  let current = Buffer.create 256 in
  let result = ref [] in

  let line = ref 1 in
  let col = ref 0 in
  let cmd_start : pos option ref = ref None in

  let cur_pos () = { line = !line; col = !col } in

  (* Advance line/col tracking through a UTF-8 string.
     Counts Unicode code points (not bytes) for column positions. *)
  let advance s =
    String.iter
      (fun c ->
        match c with
        | '\n' ->
            incr line;
            col := 0
        | '\r' -> ()
        | c when Char.code c land 0xC0 = 0x80 -> () (* UTF-8 continuation byte *)
        | _ -> incr col
      )
      s
  in

  let is_whitespace s = String.for_all (fun c -> c = ' ' || c = '\t' || c = '\n' || c = '\r') s in

  let set_start_if_needed s = if !cmd_start = None && not (is_whitespace s) then cmd_start := Some (cur_pos ()) in

  let add () =
    let s = Sedlexing.Utf8.lexeme buf in
    set_start_if_needed s;
    Buffer.add_string current s;
    advance s
  in

  (* Advance position without adding to the output buffer. *)
  let skip () =
    let s = Sedlexing.Utf8.lexeme buf in
    advance s
  in

  let flush stop =
    let s = String.trim (Buffer.contents current) in
    if s <> "" then (
      let start = Option.value ~default:stop !cmd_start in
      result := ({ start; stop }, s) :: !result
    );
    Buffer.clear current;
    cmd_start := None
  in

  (* Lex inside a comment; depth tracks nesting level (starts at 1). *)
  let rec comment depth =
    match%sedlex buf with
    | "(*" ->
        skip ();
        comment (depth + 1)
    | "*)" ->
        skip ();
        if depth > 1 then comment (depth - 1)
    | '"' ->
        skip ();
        string_in_comment ();
        comment depth
    | any ->
        skip ();
        comment depth
    | _ -> raise (Lexer_error "Unterminated comment")
  (* Lex a string inside a comment so that a comment terminator inside a string does not
     prematurely close the comment. *)
  and string_in_comment () =
    match%sedlex buf with
    | "\"\"" ->
        skip ();
        string_in_comment ()
    | '"' -> skip ()
    | any ->
        skip ();
        string_in_comment ()
    | _ -> raise (Lexer_error "Unterminated string in comment")
  (* Lex a string. Double "" escapes a quote. *)
  and string () =
    match%sedlex buf with
    | "\"\"" ->
        add ();
        string ()
    | '"' -> add ()
    | '\n' -> raise (Lexer_error "Newline in string")
    | any ->
        add ();
        string ()
    | _ -> raise (Lexer_error "Unterminated string")
  and main () =
    match%sedlex buf with
    | "(*" ->
        let s = Sedlexing.Utf8.lexeme buf in
        set_start_if_needed s;
        advance s;
        comment 1;
        (* Replace the entire comment with a single space to avoid merging surrounding tokens. *)
        Buffer.add_char current ' ';
        main ()
    | '"' ->
        add ();
        string ();
        main ()
    | '.', white_space ->
        (* stop is exclusive: one past the period. *)
        let stop = { line = !line; col = !col + 1 } in
        Buffer.add_char current '.';
        advance (Sedlexing.Utf8.lexeme buf);
        flush stop;
        main ()
    | '.' ->
        add ();
        main ()
    | eof -> flush (cur_pos ())
    | any ->
        add ();
        main ()
    | _ -> assert false
  in

  main ();
  List.rev !result
